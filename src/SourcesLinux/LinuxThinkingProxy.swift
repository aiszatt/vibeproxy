import Foundation
import NIO
import NIOHTTP1

/// A lightweight HTTP proxy that intercepts requests to add extended thinking parameters
/// for Claude models based on model name suffixes.
///
/// Model name pattern:
/// - `*-thinking-NUMBER` → Custom token budget (e.g., claude-sonnet-4-5-20250929-thinking-5000)
///
/// The proxy strips the suffix and adds the `thinking` parameter to the request body
/// before forwarding to CLIProxyAPI.
class LinuxThinkingProxy {
    private var channel: Channel?
    private var group: MultiThreadedEventLoopGroup?
    
    let proxyPort: UInt16
    private let targetPort: UInt16
    private let targetHost: String = "127.0.0.1"
    private let verbose: Bool
    
    private(set) var isRunning = false
    
    init(proxyPort: UInt16 = 8317, targetPort: UInt16 = 8318, verbose: Bool = false) {
        self.proxyPort = proxyPort
        self.targetPort = targetPort
        self.verbose = verbose
    }
    
    deinit {
        stop()
    }
    
    /// Starts the thinking proxy server
    func start() throws {
        guard !isRunning else {
            if verbose {
                print("[ThinkingProxy] Already running")
            }
            return
        }
        
        group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        
        let bootstrap = ServerBootstrap(group: group!)
            .serverChannelOption(.backlog, value: 256)
            .serverChannelOption(.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                channel.pipeline.addHandler(ByteToMessageHandler(HTTPRequestDecoder(leftOverBytesStrategy: .forwardBytes))).flatMap {
                    channel.pipeline.addHandler(HTTPResponseEncoder()).flatMap {
                        channel.pipeline.addHandler(
                            ThinkingProxyHandler(
                                targetHost: self.targetHost,
                                targetPort: self.targetPort,
                                verbose: self.verbose
                            )
                        )
                    }
                }
            }
            .childChannelOption(.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(.maxMessagesPerRead, value: 16)
            .childChannelOption(.recvAllocator, value: AdaptiveRecvByteBufferAllocator())
        
        do {
            channel = try bootstrap.bind(host: "0.0.0.0", port: Int(proxyPort)).wait()
            isRunning = true
            if verbose {
                print("[ThinkingProxy] Listening on port \(proxyPort)")
            }
        } catch {
            throw error
        }
    }
    
    /// Stops the thinking proxy server
    func stop() {
        guard isRunning else { return }
        
        do {
            try channel?.close().wait()
            try group?.syncShutdownGracefully()
        } catch {
            if verbose {
                print("[ThinkingProxy] Error during shutdown: \(error)")
            }
        }
        
        channel = nil
        group = nil
        isRunning = false
        
        if verbose {
            print("[ThinkingProxy] Stopped")
        }
    }
}

/// Handler that processes requests and forwards them to CLIProxyAPI
private final class ThinkingProxyHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart
    
    private let targetHost: String
    private let targetPort: UInt16
    private let verbose: Bool
    
    private var requestHead: HTTPRequestHead?
    private var requestBody: ByteBuffer?
    
    init(targetHost: String, targetPort: UInt16, verbose: Bool) {
        self.targetHost = targetHost
        self.targetPort = targetPort
        self.verbose = verbose
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let part = unwrapInboundIn(data)
        
        switch part {
        case .head(let head):
            requestHead = head
            requestBody = context.channel.allocator.buffer(capacity: 0)
            
        case .body(var body):
            requestBody?.writeBuffer(&body)
            
        case .end:
            guard let head = requestHead else {
                sendError(context: context, status: .badRequest, message: "Invalid request")
                return
            }
            
            processRequest(context: context, head: head, body: requestBody)
            requestHead = nil
            requestBody = nil
        }
    }
    
    private func processRequest(context: ChannelHandlerContext, head: HTTPRequestHead, body: ByteBuffer?) {
        var modifiedHead = head
        var modifiedBody = body
        var path = head.uri
        
        // Rewrite Amp CLI paths
        if path.hasPrefix("/auth/cli-login") {
            path = "/api" + path
            modifiedHead.uri = path
            if verbose {
                print("[ThinkingProxy] Rewriting Amp CLI login: \(head.uri) -> \(path)")
            }
        } else if path.hasPrefix("/provider/") {
            path = "/api" + path
            modifiedHead.uri = path
            if verbose {
                print("[ThinkingProxy] Rewriting Amp provider path: \(head.uri) -> \(path)")
            }
        }
        
        // Check if this is an Amp management API request (not provider routes)
        if path.hasPrefix("/api/") && !path.hasPrefix("/api/provider/") {
            let ampPath = String(path.dropFirst(4)) // Remove "/api" prefix
            if verbose {
                print("[ThinkingProxy] Amp management request detected, forwarding to ampcode.com: \(ampPath)")
            }
            forwardToAmp(context: context, head: head, body: body, ampPath: ampPath)
            return
        }
        
        // Process thinking parameter for POST requests
        if head.method == .POST, let bodyBuffer = body, bodyBuffer.readableBytes > 0 {
            if let bodyString = bodyBuffer.getString(at: bodyBuffer.readerIndex, length: bodyBuffer.readableBytes),
               let result = processThinkingParameter(jsonString: bodyString) {
                if result.1 { // transformation applied
                    var newBuffer = context.channel.allocator.buffer(capacity: result.0.utf8.count)
                    newBuffer.writeString(result.0)
                    modifiedBody = newBuffer
                }
            }
        }
        
        // Forward to CLIProxyAPI
        forwardRequest(context: context, head: modifiedHead, body: modifiedBody)
    }
    
    /// Processes the JSON body to add thinking parameter if model name has a thinking suffix
    private func processThinkingParameter(jsonString: String) -> (String, Bool)? {
        guard let jsonData = jsonString.data(using: .utf8),
              var json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let model = json["model"] as? String else {
            return nil
        }
        
        // Only process Claude models with thinking suffix
        guard model.hasPrefix("claude-") else {
            return (jsonString, false)
        }
        
        // Check for thinking suffix pattern: -thinking-NUMBER
        let thinkingPrefix = "-thinking-"
        if let thinkingRange = model.range(of: thinkingPrefix, options: .backwards),
           thinkingRange.upperBound < model.endIndex {
            
            let budgetString = String(model[thinkingRange.upperBound...])
            let cleanModel = String(model[..<thinkingRange.lowerBound])
            json["model"] = cleanModel
            
            if let budget = Int(budgetString), budget > 0 {
                let hardCap = 32000
                let effectiveBudget = min(budget, hardCap - 1)
                
                if verbose && effectiveBudget != budget {
                    print("[ThinkingProxy] Adjusted thinking budget from \(budget) to \(effectiveBudget)")
                }
                
                json["thinking"] = [
                    "type": "enabled",
                    "budget_tokens": effectiveBudget
                ]
                
                // Ensure max token limits are greater than the thinking budget
                let tokenHeadroom = max(1024, effectiveBudget / 10)
                let desiredMaxTokens = effectiveBudget + tokenHeadroom
                var requiredMaxTokens = min(desiredMaxTokens, hardCap)
                if requiredMaxTokens <= effectiveBudget {
                    requiredMaxTokens = min(effectiveBudget + 1, hardCap)
                }
                
                let hasMaxOutputTokensField = json.keys.contains("max_output_tokens")
                var adjusted = false
                
                if let currentMaxTokens = json["max_tokens"] as? Int {
                    if currentMaxTokens <= effectiveBudget {
                        json["max_tokens"] = requiredMaxTokens
                    }
                    adjusted = true
                }
                
                if let currentMaxOutputTokens = json["max_output_tokens"] as? Int {
                    if currentMaxOutputTokens <= effectiveBudget {
                        json["max_output_tokens"] = requiredMaxTokens
                    }
                    adjusted = true
                }
                
                if !adjusted {
                    if hasMaxOutputTokensField {
                        json["max_output_tokens"] = requiredMaxTokens
                    } else {
                        json["max_tokens"] = requiredMaxTokens
                    }
                }
                
                if verbose {
                    print("[ThinkingProxy] Transformed model '\(model)' → '\(cleanModel)' with thinking budget \(effectiveBudget)")
                }
            } else {
                if verbose {
                    print("[ThinkingProxy] Stripped invalid thinking suffix from '\(model)' → '\(cleanModel)'")
                }
            }
            
            if let modifiedData = try? JSONSerialization.data(withJSONObject: json),
               let modifiedString = String(data: modifiedData, encoding: .utf8) {
                return (modifiedString, true)
            }
        }
        
        return (jsonString, false)
    }
    
    /// Forward request to CLIProxyAPI
    private func forwardRequest(context: ChannelHandlerContext, head: HTTPRequestHead, body: ByteBuffer?) {
        let group = context.eventLoop
        
        let bootstrap = ClientBootstrap(group: group)
            .channelOption(.socketOption(.so_reuseaddr), value: 1)
            .channelInitializer { channel in
                channel.pipeline.addHandler(HTTPRequestEncoder()).flatMap {
                    channel.pipeline.addHandler(ByteToMessageHandler(HTTPResponseDecoder(leftOverBytesStrategy: .forwardBytes))).flatMap {
                        channel.pipeline.addHandler(
                            ProxyClientHandler(
                                originalContext: context,
                                verbose: self.verbose
                            )
                        )
                    }
                }
            }
        
        bootstrap.connect(host: targetHost, port: Int(targetPort)).whenComplete { result in
            switch result {
            case .success(let channel):
                // Build modified headers
                var headers = HTTPHeaders()
                for (name, value) in head.headers {
                    let lowercasedName = name.lowercased()
                    if lowercasedName != "host" && lowercasedName != "content-length" && lowercasedName != "transfer-encoding" {
                        headers.add(name: name, value: value)
                    }
                }
                headers.add(name: "Host", value: "\(self.targetHost):\(self.targetPort)")
                headers.add(name: "Connection", value: "close")
                
                if let body = body {
                    headers.add(name: "Content-Length", value: String(body.readableBytes))
                }
                
                let requestHead = HTTPRequestHead(
                    version: head.version,
                    method: head.method,
                    uri: head.uri,
                    headers: headers
                )
                
                channel.write(NIOAny(HTTPClientRequestPart.head(requestHead)), promise: nil)
                
                if let body = body {
                    channel.write(NIOAny(HTTPClientRequestPart.body(.byteBuffer(body))), promise: nil)
                }
                
                channel.writeAndFlush(NIOAny(HTTPClientRequestPart.end(nil)), promise: nil)
                
            case .failure(let error):
                self.sendError(context: context, status: .badGateway, message: "Connection failed: \(error)")
            }
        }
    }
    
    /// Forward request to ampcode.com
    /// 
    /// NOTE: This feature is not implemented in the Linux version because it requires
    /// HTTPS support via NIOSSL. The macOS version uses the Network framework which
    /// has built-in TLS support.
    /// 
    /// To implement this feature, add the NIOSSL package dependency and use
    /// NIOSSLClientHandler to create a TLS-wrapped connection to ampcode.com:443.
    private func forwardToAmp(context: ChannelHandlerContext, head: HTTPRequestHead, body: ByteBuffer?, ampPath: String) {
        sendError(context: context, status: .badGateway, message: "Amp API forwarding requires HTTPS (use the macOS version for Amp CLI support)")
    }
    
    private func sendError(context: ChannelHandlerContext, status: HTTPResponseStatus, message: String) {
        var headers = HTTPHeaders()
        headers.add(name: "Content-Type", value: "text/plain")
        headers.add(name: "Content-Length", value: String(message.utf8.count))
        headers.add(name: "Connection", value: "close")
        
        let head = HTTPResponseHead(version: .http1_1, status: status, headers: headers)
        context.write(wrapOutboundOut(.head(head)), promise: nil)
        
        var buffer = context.channel.allocator.buffer(capacity: message.utf8.count)
        buffer.writeString(message)
        context.write(wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
        
        context.writeAndFlush(wrapOutboundOut(.end(nil))).whenComplete { _ in
            context.close(promise: nil)
        }
    }
    
    func errorCaught(context: ChannelHandlerContext, error: Error) {
        if verbose {
            print("[ThinkingProxy] Error: \(error)")
        }
        context.close(promise: nil)
    }
}

/// Handler for proxied client connections (to CLIProxyAPI)
private final class ProxyClientHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPClientResponsePart
    typealias OutboundOut = HTTPServerResponsePart
    
    private let originalContext: ChannelHandlerContext
    private let verbose: Bool
    
    init(originalContext: ChannelHandlerContext, verbose: Bool) {
        self.originalContext = originalContext
        self.verbose = verbose
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let part = unwrapInboundIn(data)
        
        switch part {
        case .head(let head):
            let serverHead = HTTPResponseHead(version: head.version, status: head.status, headers: head.headers)
            originalContext.write(NIOAny(HTTPServerResponsePart.head(serverHead)), promise: nil)
            
        case .body(let body):
            originalContext.write(NIOAny(HTTPServerResponsePart.body(.byteBuffer(body))), promise: nil)
            
        case .end:
            originalContext.writeAndFlush(NIOAny(HTTPServerResponsePart.end(nil))).whenComplete { [weak self] _ in
                self?.originalContext.close(promise: nil)
                context.close(promise: nil)
            }
        }
    }
    
    func errorCaught(context: ChannelHandlerContext, error: Error) {
        if verbose {
            print("[ProxyClient] Error: \(error)")
        }
        
        // Send error response to original client
        var headers = HTTPHeaders()
        headers.add(name: "Content-Type", value: "text/plain")
        let message = "Upstream error: \(error)"
        headers.add(name: "Content-Length", value: String(message.utf8.count))
        headers.add(name: "Connection", value: "close")
        
        let head = HTTPResponseHead(version: .http1_1, status: .badGateway, headers: headers)
        originalContext.write(NIOAny(HTTPServerResponsePart.head(head)), promise: nil)
        
        var buffer = originalContext.channel.allocator.buffer(capacity: message.utf8.count)
        buffer.writeString(message)
        originalContext.write(NIOAny(HTTPServerResponsePart.body(.byteBuffer(buffer))), promise: nil)
        
        originalContext.writeAndFlush(NIOAny(HTTPServerResponsePart.end(nil))).whenComplete { [weak self] _ in
            self?.originalContext.close(promise: nil)
        }
        
        context.close(promise: nil)
    }
}
