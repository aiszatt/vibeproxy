.PHONY: build app install clean run help linux linux-release linux-install

help: ## Show this help message
	@echo "VibeProxy - macOS Menu Bar App & Linux Server"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

build: ## Build the Swift executable (debug)
	@echo "🔨 Building Swift executable..."
	@cd src && swift build
	@echo "✅ Build complete: src/.build/debug/CLIProxyMenuBar"

release: ## Build the Swift executable (release)
	@echo "🔨 Building Swift executable (release)..."
	@./build.sh
	@echo "✅ Build complete: src/.build/release/CLIProxyMenuBar"

# Linux targets
linux: ## Build for Linux (debug)
	@echo "🔨 Building Linux executable..."
	@cd src && swift build
	@echo "✅ Build complete: src/.build/debug/vibeproxy"

linux-release: ## Build for Linux (release)
	@echo "🔨 Building Linux executable (release)..."
	@cd src && swift build -c release
	@echo "✅ Build complete: src/.build/release/vibeproxy"

linux-install: linux-release ## Build and install to /usr/local (Linux)
	@echo "📲 Installing to /usr/local..."
	@sudo mkdir -p /usr/local/bin /usr/local/share/vibeproxy
	@sudo cp src/.build/release/vibeproxy /usr/local/bin/
	@sudo chmod +x /usr/local/bin/vibeproxy
	@if [ -f src/SourcesLinux/Resources/config.yaml ]; then \
		sudo cp src/SourcesLinux/Resources/config.yaml /usr/local/share/vibeproxy/; \
	fi
	@echo "✅ Installed to /usr/local/bin/vibeproxy"
	@echo ""
	@echo "📝 Next steps:"
	@echo "   1. Copy cli-proxy-api binary to /usr/local/share/vibeproxy/"
	@echo "   2. Run: vibeproxy"

linux-run: linux ## Build and run (Linux)
	@echo "🚀 Launching server..."
	@src/.build/debug/vibeproxy --verbose

linux-systemd: ## Generate systemd service file
	@echo "📄 Generating vibeproxy.service..."
	@echo "[Unit]" > /tmp/vibeproxy.service
	@echo "Description=VibeProxy - AI Subscription Proxy Server" >> /tmp/vibeproxy.service
	@echo "After=network.target" >> /tmp/vibeproxy.service
	@echo "" >> /tmp/vibeproxy.service
	@echo "[Service]" >> /tmp/vibeproxy.service
	@echo "Type=simple" >> /tmp/vibeproxy.service
	@echo "ExecStart=/usr/local/bin/vibeproxy" >> /tmp/vibeproxy.service
	@echo "Restart=on-failure" >> /tmp/vibeproxy.service
	@echo "User=$(USER)" >> /tmp/vibeproxy.service
	@echo "WorkingDirectory=/usr/local/share/vibeproxy" >> /tmp/vibeproxy.service
	@echo "" >> /tmp/vibeproxy.service
	@echo "[Install]" >> /tmp/vibeproxy.service
	@echo "WantedBy=multi-user.target" >> /tmp/vibeproxy.service
	@echo "✅ Service file created: /tmp/vibeproxy.service"
	@echo ""
	@echo "📝 To install the service:"
	@echo "   sudo cp /tmp/vibeproxy.service /etc/systemd/system/"
	@echo "   sudo systemctl daemon-reload"
	@echo "   sudo systemctl enable vibeproxy"
	@echo "   sudo systemctl start vibeproxy"

app: ## Create the .app bundle (macOS only)
	@echo "📦 Creating .app bundle..."
	@./create-app-bundle.sh
	@echo "✅ App bundle created: VibeProxy.app"

install: app ## Build and install to /Applications
	@echo "📲 Installing to /Applications..."
	@rm -rf "/Applications/VibeProxy.app"
	@cp -r "VibeProxy.app" /Applications/
	@echo "✅ Installed to /Applications/VibeProxy.app"

run: app ## Build and run the app
	@echo "🚀 Launching app..."
	@open "VibeProxy.app"

clean: ## Clean build artifacts
	@echo "🧹 Cleaning..."
	@rm -rf src/.build
	@rm -rf "VibeProxy.app"
	@rm -rf src/Sources/Resources/cli-proxy-api
	@rm -rf src/Sources/Resources/config.yaml
	@rm -rf src/Sources/Resources/static
	@echo "✅ Clean complete"

test: ## Run a quick test build
	@echo "🧪 Testing build..."
	@cd src && swift build
	@echo "✅ Test build successful"

info: ## Show project information
	@echo "Project: VibeProxy - macOS Menu Bar App"
	@echo "Language: Swift 5.9+"
	@echo "Platform: macOS 13.0+"
	@echo ""
	@echo "Files:"
	@find src/Sources -name "*.swift" -exec wc -l {} + | tail -1 | awk '{print "  Swift code: " $$1 " lines"}'
	@echo "  Documentation: 4 files"
	@echo ""
	@echo "Structure:"
	@tree -L 3 -I ".build" || echo "  (install 'tree' for better output)"

open: ## Open app bundle to inspect contents
	@if [ -d "VibeProxy.app" ]; then \
		open "VibeProxy.app"; \
	else \
		echo "❌ App bundle not found. Run 'make app' first."; \
	fi

edit-config: ## Edit the bundled config.yaml
	@if [ -d "VibeProxy.app" ]; then \
		open -e "VibeProxy.app/Contents/Resources/config.yaml"; \
	else \
		echo "❌ App bundle not found. Run 'make app' first."; \
	fi

# Shortcuts
all: app ## Same as 'app'
