# VibeProxy

<p align="center">
  <img src="icon.png" width="128" height="128" alt="VibeProxy Icon">
</p>

<p align="center">
<a href="https://automaze.io" rel="nofollow"><img alt="Automaze" src="https://img.shields.io/badge/By-automaze.io-4b3baf" style="max-width: 100%;"></a>
<a href="https://github.com/automazeio/vibeproxy/blob/main/LICENSE"><img alt="MIT License" src="https://img.shields.io/badge/License-MIT-28a745" style="max-width: 100%;"></a>
<a href="http://x.com/intent/follow?screen_name=aroussi" rel="nofollow"><img alt="Follow on 𝕏" src="https://img.shields.io/badge/Follow-%F0%9D%95%8F/@aroussi-1c9bf0" style="max-width: 100%;"></a>
<a href="https://github.com/automazeio/vibeproxy"><img alt="Star this repo" src="https://img.shields.io/github/stars/automazeio/vibeproxy.svg?style=social&amp;label=Star%20this%20repo&amp;maxAge=60" style="max-width: 100%;"></a></p>
</p>

**Stop paying twice for AI.** VibeProxy lets you use your existing Claude Code, ChatGPT, **Gemini**, **Qwen**, and **Antigravity** subscriptions with powerful AI coding tools like **[Factory Droids](https://app.factory.ai/r/FM8BJHFQ)** – no separate API keys required.

Available as a **native macOS menu bar app** or a **Linux CLI server**.

Built on [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI), it handles OAuth authentication, token management, and API routing automatically. One click to authenticate, zero friction to code.


<p align="center">
<br>
  <a href="https://www.loom.com/share/5cf54acfc55049afba725ab443dd3777"><img src="vibeproxy-factory-video.webp" width="600" height="380" alt="VibeProxy Screenshot" border="0"></a>
</p>

> [!TIP]
> 📣 **Latest models supported:**<br>Gemini 3 Pro Support (via Antigravity), GPT-5.1 / GPT-5.1 Codex, and Claude Sonnet 4.5 / Opus 4.5 with extended thinking! 🚀 
> 
> **Setup Guides:**
> - [Factory CLI Setup →](FACTORY_SETUP.md) - Use Factory Droids with your AI subscriptions
> - [Amp CLI Setup →](AMPCODE_SETUP.md) - Use Amp CLI with fallback to your subscriptions

---

## Features

### macOS Menu Bar App
- 🎯 **Native macOS Experience** - Clean, native SwiftUI interface that feels right at home on macOS
- 🚀 **One-Click Server Management** - Start/stop the proxy server from your menu bar
- 🔐 **OAuth Integration** - Authenticate with Codex, Claude Code, Gemini, Qwen, and Antigravity directly from the app
- 📊 **Real-Time Status** - Live connection status and automatic credential detection
- 🔄 **Auto-Updates** - Monitors auth files and updates UI in real-time
- 🎨 **Beautiful Icons** - Custom icons with dark mode support
- 💾 **Self-Contained** - Everything bundled inside the .app (server binary, config, static files)

### Linux CLI Server
- 🐧 **Native Linux Support** - Run as a headless server or systemd service
- 🔧 **Command Line Interface** - Easy to configure and automate
- 🚀 **Same Core Features** - Thinking proxy, API routing, authentication support
- 📦 **Lightweight** - No GUI dependencies, minimal resource usage
- 🔄 **Systemd Integration** - Easy to run as a system service


## Installation

### macOS (Apple Silicon)

**⚠️ Requirements:** macOS running on **Apple Silicon only** (M1/M2/M3/M4 Macs). Intel Macs are not supported.

#### Download Pre-built Release (Recommended)

1. Go to the [**Releases**](https://github.com/automazeio/vibeproxy/releases) page
2. Download the latest `VibeProxy.zip`
3. Extract and drag `VibeProxy.app` to `/Applications`
4. Launch VibeProxy

**Code Signed & Notarized** ✅ - No Gatekeeper warnings, installs seamlessly on macOS.

#### Build from Source

Want to build it yourself? See [**INSTALLATION.md**](INSTALLATION.md) for detailed build instructions.

### Linux

**Requirements:** Swift 5.9+ runtime, x86_64 or arm64 architecture.

#### Build from Source

```bash
# Clone the repository
git clone https://github.com/automazeio/vibeproxy.git
cd vibeproxy

# Build the Linux executable
make linux-release

# Install (optional)
sudo make linux-install
```

#### Quick Start

```bash
# Run the server
./src/.build/release/vibeproxy

# Or with options
vibeproxy --port 8317 --verbose
```

#### Systemd Service (Recommended for servers)

```bash
# Generate the systemd service file
make linux-systemd

# Install and enable
sudo cp /tmp/vibeproxy.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable vibeproxy
sudo systemctl start vibeproxy
```

#### CLI Options

```
USAGE: vibeproxy [--config <config>] [--port <port>] [--backend-port <backend-port>] [--daemon] [--verbose]

OPTIONS:
  -c, --config <config>   Path to config.yaml file
  -p, --port <port>       Port for the proxy server (default: 8317)
  --backend-port <port>   Port for the CLIProxyAPI backend (default: 8318)
  --daemon                Run in daemon mode (background)
  -v, --verbose           Enable verbose logging
  -h, --help              Show help information.
```

## Usage

### macOS - First Launch

1. Launch VibeProxy - you'll see a menu bar icon
2. Click the icon and select "Open Settings"
3. The server will start automatically
4. Click "Connect" for Claude Code, Codex, Gemini, Qwen, or Antigravity to authenticate

### Authentication

When you click "Connect":
1. Your browser opens with the OAuth page
2. Complete the authentication in the browser
3. VibeProxy automatically detects your credentials
4. Status updates to show you're connected

### Server Management (macOS)

- **Toggle Server**: Click the status (Running/Stopped) to start/stop
- **Menu Bar Icon**: Shows active/inactive state
- **Launch at Login**: Toggle to start VibeProxy automatically

### Linux Usage

```bash
# Start the proxy server
vibeproxy

# With verbose logging
vibeproxy --verbose

# Custom ports
vibeproxy --port 8080 --backend-port 8081

# With custom config
vibeproxy --config /path/to/config.yaml
```

#### Authentication on Linux

Use the cli-proxy-api binary directly to authenticate:

```bash
# Authenticate with different providers
cli-proxy-api -claude-login       # Claude Code
cli-proxy-api -codex-login        # OpenAI Codex
cli-proxy-api -login              # Gemini
cli-proxy-api -qwen-login         # Qwen
cli-proxy-api -antigravity-login  # Antigravity
```

Credentials are stored in `~/.cli-proxy-api/` and automatically detected by VibeProxy.

## Requirements

### macOS
- macOS 13.0 (Ventura) or later
- Apple Silicon (M1/M2/M3/M4)

### Linux
- Swift 5.9+ runtime
- x86_64 or arm64 architecture
- cli-proxy-api binary

## Development

### Project Structure

```
VibeProxy/
├── Sources/                    # macOS app sources
│   ├── main.swift              # App entry point
│   ├── AppDelegate.swift       # Menu bar & window management
│   ├── ServerManager.swift     # Server process control & auth
│   ├── SettingsView.swift      # Main UI
│   ├── AuthStatus.swift        # Auth file monitoring
│   └── Resources/
│       ├── AppIcon.icns        # App icon
│       ├── cli-proxy-api       # CLIProxyAPI binary
│       ├── config.yaml         # CLIProxyAPI config
│       └── icon-*.png          # Menu bar & service icons
├── SourcesLinux/               # Linux CLI sources
│   ├── main.swift              # CLI entry point
│   ├── LinuxServerManager.swift # Server process control
│   ├── LinuxThinkingProxy.swift # Thinking proxy (NIO-based)
│   └── Resources/
│       └── config.yaml         # Default config
├── Package.swift               # Swift Package Manager config
├── Info.plist                  # macOS app metadata
├── create-app-bundle.sh        # App bundle creation script
└── Makefile                    # Build automation
```

### Key Components

#### macOS
- **AppDelegate**: Manages the menu bar item and settings window lifecycle
- **ServerManager**: Controls the cli-proxy-api server process and OAuth authentication
- **SettingsView**: SwiftUI interface with native macOS design
- **AuthStatus**: Monitors `~/.cli-proxy-api/` for authentication files
- **ThinkingProxy**: Network framework-based proxy for thinking parameter injection

#### Linux
- **LinuxServerManager**: POSIX-compatible process management for cli-proxy-api
- **LinuxThinkingProxy**: Swift NIO-based HTTP proxy for thinking parameter injection
- **ArgumentParser**: Command-line interface handling

## Credits

VibeProxy is built on top of [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI), an excellent unified proxy server for AI services.

Special thanks to the CLIProxyAPI project for providing the core functionality that makes VibeProxy possible.

## License

MIT License - see LICENSE file for details

## Support

- **Report Issues**: [GitHub Issues](https://github.com/automazeio/vibeproxy/issues)
- **Website**: [automaze.io](https://automaze.io)

---

© 2025 [Automaze, Ltd.](https://automaze.io) All rights reserved.
