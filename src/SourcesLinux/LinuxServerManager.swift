import Foundation

/// Manages the CLIProxyAPI server process on Linux
class LinuxServerManager {
    private var process: Process?
    private(set) var isRunning = false
    private let binaryPath: String
    private let configPath: String
    private let port: Int
    private let verbose: Bool
    
    private let processQueue = DispatchQueue(label: "io.automaze.vibeproxy.server-process", qos: .userInitiated)
    
    init(binaryPath: String, configPath: String, port: Int, verbose: Bool = false) {
        self.binaryPath = binaryPath
        self.configPath = configPath
        self.port = port
        self.verbose = verbose
    }
    
    deinit {
        stop()
        killOrphanedProcesses()
    }
    
    /// Starts the CLIProxyAPI server
    /// - Returns: true if the server started successfully
    func start() -> Bool {
        guard !isRunning else {
            return true
        }
        
        // Clean up any orphaned processes from previous runs
        killOrphanedProcesses()
        
        // Expand tilde in paths
        let expandedBinaryPath = (binaryPath as NSString).expandingTildeInPath
        let expandedConfigPath = (configPath as NSString).expandingTildeInPath
        
        // Check if binary exists
        guard FileManager.default.fileExists(atPath: expandedBinaryPath) else {
            print("❌ Error: cli-proxy-api binary not found at \(expandedBinaryPath)")
            return false
        }
        
        // Check if config exists
        guard FileManager.default.fileExists(atPath: expandedConfigPath) else {
            print("❌ Error: config.yaml not found at \(expandedConfigPath)")
            return false
        }
        
        // Ensure binary is executable
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: expandedBinaryPath)
            if let permissions = attributes[.posixPermissions] as? Int, permissions & 0o111 == 0 {
                try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: expandedBinaryPath)
            }
        } catch {
            if verbose {
                print("⚠️ Warning: Could not check/set executable permissions: \(error)")
            }
        }
        
        process = Process()
        process?.executableURL = URL(fileURLWithPath: expandedBinaryPath)
        process?.arguments = ["-config", expandedConfigPath]
        
        // Setup pipes for output
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process?.standardOutput = outputPipe
        process?.standardError = errorPipe
        
        // Handle output
        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                if self?.verbose == true {
                    print("[CLIProxyAPI] \(output)", terminator: "")
                }
            }
        }
        
        errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                if self?.verbose == true {
                    print("[CLIProxyAPI ERR] \(output)", terminator: "")
                }
            }
        }
        
        // Handle termination
        process?.terminationHandler = { [weak self] process in
            self?.isRunning = false
            if self?.verbose == true {
                print("[CLIProxyAPI] Server stopped with code: \(process.terminationStatus)")
            }
        }
        
        do {
            try process?.run()
            isRunning = true
            if verbose {
                print("[CLIProxyAPI] Server started on port \(port)")
            }
            return true
        } catch {
            print("❌ Failed to start server: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Stops the CLIProxyAPI server
    func stop() {
        guard let process = process else {
            isRunning = false
            return
        }
        
        let pid = process.processIdentifier
        if verbose {
            print("[CLIProxyAPI] Stopping server (PID: \(pid))...")
        }
        
        // First try graceful termination (SIGTERM)
        process.terminate()
        
        // Wait up to 2 seconds for graceful termination
        let deadline = Date().addingTimeInterval(2.0)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        
        // If still running, force kill (SIGKILL)
        if process.isRunning {
            if verbose {
                print("[CLIProxyAPI] Server didn't stop gracefully, force killing...")
            }
            kill(pid, SIGKILL)
        }
        
        process.waitUntilExit()
        
        self.process = nil
        isRunning = false
        
        if verbose {
            print("[CLIProxyAPI] Server stopped")
        }
    }
    
    /// Runs an authentication command
    func runAuthCommand(_ command: String, email: String? = nil) -> (success: Bool, output: String) {
        let expandedBinaryPath = (binaryPath as NSString).expandingTildeInPath
        let expandedConfigPath = (configPath as NSString).expandingTildeInPath
        
        guard FileManager.default.fileExists(atPath: expandedBinaryPath) else {
            return (false, "Binary not found at \(expandedBinaryPath)")
        }
        
        let authProcess = Process()
        authProcess.executableURL = URL(fileURLWithPath: expandedBinaryPath)
        authProcess.arguments = ["--config", expandedConfigPath, command]
        
        // Create pipes for output
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        let inputPipe = Pipe()
        authProcess.standardOutput = outputPipe
        authProcess.standardError = errorPipe
        authProcess.standardInput = inputPipe
        
        // Set environment to inherit from parent
        authProcess.environment = ProcessInfo.processInfo.environment
        
        do {
            try authProcess.run()
            
            // For Qwen login, send email after a delay
            if command == "-qwen-login", let email = email {
                DispatchQueue.global().asyncAfter(deadline: .now() + 10.0) {
                    if authProcess.isRunning {
                        if let data = "\(email)\n".data(using: .utf8) {
                            try? inputPipe.fileHandleForWriting.write(contentsOf: data)
                        }
                    }
                }
            }
            
            // For Gemini login, send newline to accept default project
            if command == "-login" {
                DispatchQueue.global().asyncAfter(deadline: .now() + 3.0) {
                    if authProcess.isRunning {
                        if let data = "\n".data(using: .utf8) {
                            try? inputPipe.fileHandleForWriting.write(contentsOf: data)
                        }
                    }
                }
            }
            
            authProcess.waitUntilExit()
            
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            
            let output = String(data: outputData, encoding: .utf8) ?? ""
            let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
            
            if authProcess.terminationStatus == 0 {
                return (true, output.isEmpty ? "Authentication completed" : output)
            } else {
                return (false, errorOutput.isEmpty ? output : errorOutput)
            }
        } catch {
            return (false, "Failed to start auth process: \(error.localizedDescription)")
        }
    }
    
    /// Kill any orphaned cli-proxy-api processes that might be running
    private func killOrphanedProcesses() {
        let checkTask = Process()
        checkTask.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        checkTask.arguments = ["-f", "cli-proxy-api"]
        
        let outputPipe = Pipe()
        checkTask.standardOutput = outputPipe
        checkTask.standardError = FileHandle.nullDevice
        
        do {
            try checkTask.run()
            checkTask.waitUntilExit()
            
            if checkTask.terminationStatus == 0 {
                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                let pids = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
                
                if !pids.isEmpty && verbose {
                    print("⚠️ Found orphaned server process(es): \(pids.joined(separator: ", "))")
                    
                    let killTask = Process()
                    killTask.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
                    killTask.arguments = ["-9", "-f", "cli-proxy-api"]
                    
                    try killTask.run()
                    killTask.waitUntilExit()
                    
                    Thread.sleep(forTimeInterval: 0.5)
                    print("✅ Cleaned up orphaned processes")
                }
            }
        } catch {
            // Silently fail - this is not critical
        }
    }
}
