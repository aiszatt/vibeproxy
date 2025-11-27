import Foundation
import ArgumentParser
import NIO
import NIOHTTP1

/// VibeProxy - Linux CLI Version
/// A proxy server that enables using AI subscriptions (Claude, Codex, Gemini, etc.) with AI coding tools.
@main
struct VibeProxyCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "vibeproxy",
        abstract: "VibeProxy - AI Subscription Proxy Server for Linux",
        discussion: """
            VibeProxy lets you use your existing Claude Code, ChatGPT, Gemini, Qwen, 
            and Antigravity subscriptions with powerful AI coding tools like Factory Droids.
            
            Built on CLIProxyAPI, it handles OAuth authentication, token management, 
            and API routing automatically.
            """,
        version: "1.4.1"
    )
    
    @Option(name: .shortAndLong, help: "Path to config.yaml file")
    var config: String?
    
    @Option(name: .shortAndLong, help: "Port for the proxy server (default: 8317)")
    var port: UInt16 = 8317
    
    @Option(name: .long, help: "Port for the CLIProxyAPI backend (default: 8318)")
    var backendPort: UInt16 = 8318
    
    @Flag(name: .long, help: "Run in daemon mode (background)")
    var daemon: Bool = false
    
    @Flag(name: .shortAndLong, help: "Enable verbose logging")
    var verbose: Bool = false
    
    mutating func run() throws {
        print("🚀 VibeProxy - Linux Server")
        print("===========================")
        
        // Determine resource paths
        let resourcePath = findResourcePath()
        let configPath = config ?? (resourcePath.map { "\($0)/config.yaml" } ?? "~/.vibeproxy/config.yaml")
        let binaryPath = resourcePath.map { "\($0)/cli-proxy-api" } ?? "/usr/local/bin/cli-proxy-api"
        
        print("📁 Config: \(configPath)")
        print("📁 Binary: \(binaryPath)")
        print("🌐 Proxy Port: \(port)")
        print("🌐 Backend Port: \(backendPort)")
        print("")
        
        // Initialize managers
        let serverManager = LinuxServerManager(
            binaryPath: binaryPath,
            configPath: configPath,
            port: Int(backendPort),
            verbose: verbose
        )
        
        let thinkingProxy = LinuxThinkingProxy(
            proxyPort: port,
            targetPort: backendPort,
            verbose: verbose
        )
        
        // Setup signal handlers for graceful shutdown
        setupSignalHandlers()
        
        // Start the thinking proxy
        print("🔄 Starting thinking proxy on port \(port)...")
        try thinkingProxy.start()
        
        // Wait for proxy to be ready
        Thread.sleep(forTimeInterval: 0.5)
        
        guard thinkingProxy.isRunning else {
            print("❌ Failed to start thinking proxy")
            throw ExitCode.failure
        }
        
        print("✅ Thinking proxy running on port \(port)")
        
        // Start the backend server
        print("🔄 Starting CLIProxyAPI backend on port \(backendPort)...")
        let startSuccess = serverManager.start()
        
        guard startSuccess else {
            print("❌ Failed to start CLIProxyAPI backend")
            thinkingProxy.stop()
            throw ExitCode.failure
        }
        
        // Wait for backend to be ready
        Thread.sleep(forTimeInterval: 1.0)
        
        guard serverManager.isRunning else {
            print("❌ CLIProxyAPI backend exited unexpectedly")
            thinkingProxy.stop()
            throw ExitCode.failure
        }
        
        print("✅ CLIProxyAPI backend running on port \(backendPort)")
        print("")
        print("🎉 VibeProxy is ready!")
        print("   Server URL: http://localhost:\(port)")
        print("")
        print("📝 Authentication:")
        print("   Use the cli-proxy-api binary directly to authenticate:")
        print("   \(binaryPath) -claude-login    # Claude Code")
        print("   \(binaryPath) -codex-login     # OpenAI Codex")
        print("   \(binaryPath) -login           # Gemini")
        print("   \(binaryPath) -qwen-login      # Qwen")
        print("   \(binaryPath) -antigravity-login # Antigravity")
        print("")
        print("Press Ctrl+C to stop...")
        print("")
        
        // Keep running using dispatchMain which handles signals properly
        dispatchMain()
    }
    
    private func findResourcePath() -> String? {
        // Check common locations for resources
        let possiblePaths = [
            // Same directory as executable
            CommandLine.arguments[0].replacingOccurrences(of: "/vibeproxy", with: ""),
            // Standard Linux installation paths
            "/usr/local/share/vibeproxy",
            "/usr/share/vibeproxy",
            "/opt/vibeproxy",
            // Home directory
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".vibeproxy").path,
            // Current directory
            FileManager.default.currentDirectoryPath
        ]
        
        for path in possiblePaths {
            let configPath = "\(path)/config.yaml"
            let binaryPath = "\(path)/cli-proxy-api"
            
            if FileManager.default.fileExists(atPath: configPath) || 
               FileManager.default.fileExists(atPath: binaryPath) {
                return path
            }
        }
        
        return nil
    }
    
    private func setupSignalHandlers() {
        // Handle SIGINT (Ctrl+C)
        signal(SIGINT) { _ in
            print("\n🛑 Shutting down...")
            Foundation.exit(0)
        }
        
        // Handle SIGTERM
        signal(SIGTERM) { _ in
            print("\n🛑 Received SIGTERM, shutting down...")
            Foundation.exit(0)
        }
    }
}
