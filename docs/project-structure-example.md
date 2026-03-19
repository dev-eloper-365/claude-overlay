# Example: Project Directory Structure

This document shows the complete recommended file structure for the Permission Overlay project after full implementation.

## Directory Tree

```
claude-code-overlay/
├── README.md                           # Project overview and quick start
├── LICENSE                             # MIT license
├── PERMISSION_OVERLAY_SPEC.md          # Main specification document
├── CHANGELOG.md                        # Version history
├── .gitignore                          # Git ignore patterns
│
├── docs/                               # Documentation
│   ├── overlay-ipc-protocol.md         # IPC protocol specification
│   ├── overlay-config-schema.md        # Configuration reference
│   ├── overlay-development-guide.md    # Developer setup guide
│   ├── overlay-quick-reference.md      # One-page cheat sheet
│   ├── architecture-diagrams.md        # Visual architecture docs
│   └── api/                            # API documentation
│       ├── ipc-server.md
│       ├── queue-manager.md
│       └── rules-engine.md
│
├── schemas/                            # JSON schemas
│   ├── overlay-config-v1.schema.json   # Config validation schema
│   ├── ipc-message.schema.json         # IPC message schema
│   └── rules-pattern.schema.json       # Rules pattern schema
│
├── core/                               # Rust cross-platform core
│   ├── Cargo.toml                      # Rust manifest
│   ├── Cargo.lock
│   ├── src/
│   │   ├── lib.rs                      # Library entry point
│   │   ├── ipc/
│   │   │   ├── mod.rs
│   │   │   ├── transport.rs            # IPC transport abstraction
│   │   │   ├── unix_socket.rs          # Unix socket implementation
│   │   │   ├── named_pipe.rs           # Windows named pipe
│   │   │   └── protocol.rs             # JSON-RPC protocol
│   │   ├── queue/
│   │   │   ├── mod.rs
│   │   │   ├── manager.rs              # Queue manager
│   │   │   ├── deduplication.rs        # Dedup logic
│   │   │   └── priority.rs             # Priority sorting
│   │   ├── rules/
│   │   │   ├── mod.rs
│   │   │   ├── engine.rs               # Rule evaluation
│   │   │   ├── pattern.rs              # Pattern matching
│   │   │   └── storage.rs              # Rule persistence
│   │   ├── history/
│   │   │   ├── mod.rs
│   │   │   ├── database.rs             # SQLite wrapper
│   │   │   └── query.rs                # Query builder
│   │   ├── platform/
│   │   │   ├── mod.rs
│   │   │   ├── macos.rs                # macOS-specific code
│   │   │   ├── linux.rs                # Linux-specific code
│   │   │   └── windows.rs              # Windows-specific code
│   │   └── utils/
│   │       ├── mod.rs
│   │       ├── crypto.rs               # HMAC auth
│   │       └── time.rs                 # Timestamp helpers
│   ├── tests/                          # Integration tests
│   │   ├── ipc_tests.rs
│   │   ├── queue_tests.rs
│   │   └── rules_tests.rs
│   └── benches/                        # Benchmarks
│       ├── ipc_bench.rs
│       └── queue_bench.rs
│
├── ipc-server/                         # TypeScript IPC server
│   ├── package.json
│   ├── pnpm-lock.yaml
│   ├── tsconfig.json
│   ├── src/
│   │   ├── index.ts                    # Entry point
│   │   ├── server.ts                   # Main server class
│   │   ├── protocol.ts                 # JSON-RPC handler
│   │   ├── queue.interface.ts          # Queue interface (to Rust)
│   │   ├── rules.interface.ts          # Rules interface
│   │   ├── history.ts                  # History service
│   │   ├── config.ts                   # Config loader
│   │   └── utils/
│   │       ├── logger.ts
│   │       ├── metrics.ts
│   │       └── validation.ts
│   ├── tests/
│   │   ├── server.test.ts
│   │   ├── protocol.test.ts
│   │   └── integration.test.ts
│   └── dist/                           # Compiled JS output
│
├── overlay-macos/                      # macOS native overlay
│   ├── Package.swift                   # Swift package manifest
│   ├── Sources/
│   │   ├── main.swift                  # Entry point
│   │   ├── OverlayApp.swift            # App delegate
│   │   ├── OverlayWindow.swift         # NSPanel implementation
│   │   ├── WebViewController.swift     # WKWebView controller
│   │   ├── KeyboardHandler.swift       # Global keyboard events
│   │   ├── MonitorManager.swift        # Multi-monitor detection
│   │   ├── IPCClient.swift             # IPC communication
│   │   └── Utils/
│   │       ├── Logger.swift
│   │       └── Config.swift
│   ├── Resources/
│   │   ├── Info.plist
│   │   ├── ui/                         # WebView assets (symlink to ../ui/)
│   │   └── sounds/                     # Alert sounds
│   │       ├── request.aiff
│   │       ├── approved.aiff
│   │       └── denied.aiff
│   ├── Tests/
│   │   ├── OverlayWindowTests.swift
│   │   └── KeyboardHandlerTests.swift
│   └── .build/                         # Build artifacts
│
├── overlay-linux/                      # Linux GTK overlay
│   ├── Cargo.toml
│   ├── src/
│   │   ├── main.rs
│   │   ├── window.rs                   # GTK window
│   │   ├── webview.rs                  # WebKitGTK integration
│   │   ├── keyboard.rs                 # Global key capture
│   │   ├── x11.rs                      # X11-specific code
│   │   ├── wayland.rs                  # Wayland layer shell
│   │   └── ipc_client.rs
│   ├── resources/
│   │   └── ui/                         # Symlink to ../../ui/
│   └── debian/                         # Debian packaging
│       ├── control
│       ├── changelog
│       └── rules
│
├── overlay-windows/                    # Windows overlay
│   ├── Cargo.toml
│   ├── src/
│   │   ├── main.rs
│   │   ├── window.rs                   # Win32 window
│   │   ├── webview.rs                  # WebView2 integration
│   │   ├── keyboard.rs                 # Windows hooks
│   │   ├── virtual_desktop.rs          # Virtual desktop API
│   │   └── ipc_client.rs
│   ├── resources/
│   │   ├── ui/                         # Symlink to ../../ui/
│   │   └── manifest.xml                # UAC manifest
│   └── installer/
│       ├── installer.wixproj           # WiX installer
│       └── bundle.wxs
│
├── ui/                                 # Shared WebView UI
│   ├── index.html                      # Main HTML
│   ├── styles.css                      # Design system CSS
│   ├── app.ts                          # Preact app entry
│   ├── components/
│   │   ├── PromptCard.tsx              # Permission prompt UI
│   │   ├── QueueIndicator.tsx          # Queue badge
│   │   ├── Countdown.tsx               # Timer component
│   │   ├── RiskBadge.tsx               # Risk level indicator
│   │   └── DetailPanel.tsx             # Expanded details
│   ├── utils/
│   │   ├── keyboard.ts                 # Keyboard handler
│   │   ├── ipc-bridge.ts               # Native bridge
│   │   └── theme.ts                    # Theme switcher
│   ├── types/
│   │   ├── permission.ts               # TypeScript types
│   │   └── native-bridge.d.ts
│   ├── package.json
│   ├── tsconfig.json
│   ├── vite.config.ts                  # Vite bundler config (dev)
│   └── dist/                           # Built assets
│       ├── index.html
│       ├── bundle.js
│       └── styles.css
│
├── tests/                              # Cross-platform tests
│   ├── integration/
│   │   ├── basic_flow.test.ts          # End-to-end flow
│   │   ├── queue.test.ts               # Queue behavior
│   │   ├── rules.test.ts               # Rule evaluation
│   │   └── history.test.ts             # History logging
│   ├── e2e/
│   │   ├── playwright.config.ts
│   │   ├── overlay_visibility.spec.ts
│   │   ├── keyboard.spec.ts
│   │   └── multi_monitor.spec.ts
│   ├── performance/
│   │   ├── latency_test.ts
│   │   ├── memory_leak_test.ts
│   │   └── load_test.ts
│   └── tools/                          # Testing utilities
│       ├── send-request.js             # CLI tool to send IPC request
│       ├── ipc-client.js               # Reusable IPC client
│       ├── load-test.sh                # Load testing script
│       └── mock-overlay.ts             # Mock overlay for testing
│
├── scripts/                            # Build and development scripts
│   ├── build-all.sh                    # Build all components
│   ├── build-macos.sh
│   ├── build-linux.sh
│   ├── build-windows.sh
│   ├── start-dev.sh                    # Start dev environment
│   ├── test-all.sh                     # Run all tests
│   ├── release.sh                      # Create release build
│   ├── package-macos.sh                # Create .pkg installer
│   ├── package-linux.sh                # Create .deb/.rpm
│   ├── package-windows.sh              # Create .msi installer
│   └── ci/                             # CI/CD scripts
│       ├── setup-macos.sh
│       ├── setup-linux.sh
│       └── setup-windows.ps1
│
├── examples/                           # Example configurations
│   ├── minimal-config.json
│   ├── power-user-config.json
│   ├── paranoid-config.json
│   ├── auto-approve-safe.json
│   └── custom-shortcuts.json
│
├── .github/                            # GitHub configuration
│   ├── workflows/
│   │   ├── ci.yml                      # CI pipeline
│   │   ├── release.yml                 # Release workflow
│   │   └── docs.yml                    # Documentation deployment
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.md
│   │   └── feature_request.md
│   └── PULL_REQUEST_TEMPLATE.md
│
├── .vscode/                            # VS Code workspace config
│   ├── settings.json
│   ├── extensions.json
│   └── launch.json                     # Debug configurations
│
└── dist/                               # Release artifacts (gitignored)
    ├── macos/
    │   ├── overlay.app
    │   └── overlay-installer.pkg
    ├── linux/
    │   ├── claude-code-overlay_1.0.0_amd64.deb
    │   └── claude-code-overlay-1.0.0-1.x86_64.rpm
    └── windows/
        ├── overlay.exe
        └── overlay-installer.msi
```

## File Count Summary

```
Total Files: ~150
  - Documentation: 10
  - Source Code: 85
    - Rust: 30
    - TypeScript: 25
    - Swift: 15
    - HTML/CSS/TS (UI): 15
  - Tests: 25
  - Scripts: 15
  - Configuration: 15
```

## Build Artifacts Ignored

```gitignore
# .gitignore

# Build outputs
**/target/
**/.build/
**/dist/
**/node_modules/

# IDE
.vscode/*
!.vscode/settings.json
!.vscode/extensions.json
.idea/
*.swp

# OS
.DS_Store
Thumbs.db

# Secrets
**/*-secret.key
**/*.pem

# Logs
*.log
**/*.db
**/*.db-wal
**/*.db-shm

# IPC sockets
*.sock
*.pipe

# Temporary
/tmp/
*.tmp
```

## Key Observations

1. **Monorepo Structure**: All components in one repository for easier cross-component changes
2. **Platform Separation**: Each platform has its own directory but shares UI and core logic
3. **Shared UI**: WebView UI is platform-agnostic (symlinked into platform resources)
4. **Comprehensive Testing**: Unit, integration, E2E, and performance tests
5. **Documentation First**: Extensive docs/ directory with multiple guides
6. **CI/CD Ready**: GitHub Actions workflows for automated testing and releases

## Development Workflow

```bash
# Clone and setup
git clone https://github.com/anthropics/claude-code-overlay.git
cd claude-code-overlay

# Install all dependencies
pnpm install         # Root + ipc-server + ui
cargo fetch          # Rust dependencies

# Build everything
./scripts/build-all.sh

# Run in development mode (hot-reload)
./scripts/start-dev.sh

# Run tests
./scripts/test-all.sh

# Create release
./scripts/release.sh --version 1.0.0
```

## Distribution Structure

After `./scripts/release.sh`, the `dist/` directory contains:

```
dist/
├── macos/
│   ├── overlay.app/                   # Standalone app bundle
│   ├── overlay-installer.pkg          # macOS installer
│   └── checksums.txt
├── linux/
│   ├── claude-code-overlay_1.0.0_amd64.deb
│   ├── claude-code-overlay-1.0.0-1.x86_64.rpm
│   ├── claude-code-overlay-1.0.0-linux-x64.tar.gz
│   └── checksums.txt
└── windows/
    ├── overlay.exe                    # Standalone executable
    ├── overlay-installer.msi          # Windows installer
    └── checksums.txt
```

---

**Note**: This is a **reference structure** — not all files need to be created upfront. Start minimal and grow organically during development.
