# Permission Overlay Development Guide

## Quick Start

### Prerequisites

**Required**:
- Node.js 20+ (for IPC server)
- Rust 1.75+ (for cross-platform core)
- Git 2.40+

**Platform-Specific**:
- **macOS**: Xcode 15+, Swift 5.9+
- **Linux**: GCC 11+, GTK4 development headers, libwebkit2gtk-4.1-dev
- **Windows**: Visual Studio 2022, Windows SDK 10.0.22621.0+

### Repository Structure

```
claude-code-overlay/
├── core/                    # Rust cross-platform core
│   ├── src/
│   │   ├── ipc/            # IPC transport layer
│   │   ├── queue/          # Queue manager
│   │   ├── rules/          # Rules engine
│   │   └── platform/       # Platform abstractions
│   ├── Cargo.toml
│   └── tests/
├── overlay-macos/          # macOS native overlay
│   ├── Sources/
│   │   ├── OverlayWindow.swift
│   │   ├── WebViewController.swift
│   │   └── KeyboardHandler.swift
│   ├── Package.swift
│   └── Resources/
│       └── ui/             # HTML/CSS/JS
├── overlay-linux/          # Linux GTK overlay
│   ├── src/
│   └── Makefile
├── overlay-windows/        # Windows overlay
│   ├── src/
│   └── Cargo.toml
├── ipc-server/             # TypeScript IPC server
│   ├── src/
│   │   ├── server.ts
│   │   ├── history.ts
│   │   └── protocol.ts
│   ├── package.json
│   └── tsconfig.json
├── ui/                     # Shared WebView UI
│   ├── index.html
│   ├── styles.css
│   └── app.ts
├── tests/
│   ├── integration/
│   ├── e2e/
│   └── performance/
├── docs/
└── examples/
```

---

## Development Setup

### 1. Clone and Install

```bash
# Clone repository
git clone https://github.com/anthropics/claude-code-overlay.git
cd claude-code-overlay

# Install TypeScript dependencies
cd ipc-server && pnpm install && cd ..

# Build Rust core
cd core && cargo build && cd ..

# macOS: Build Swift overlay
cd overlay-macos && swift build && cd ..

# Linux: Build GTK overlay
cd overlay-linux && make && cd ..
```

### 2. Run Development Overlay

**macOS**:
```bash
# Terminal 1: Start IPC server (dev mode with hot reload)
cd ipc-server
pnpm dev

# Terminal 2: Run overlay
cd overlay-macos
swift run overlay-dev
```

**Linux**:
```bash
# Terminal 1: IPC server
cd ipc-server && pnpm dev

# Terminal 2: Run overlay
cd overlay-linux && ./target/debug/overlay-linux --dev
```

**Windows**:
```bash
# Terminal 1: IPC server
cd ipc-server && pnpm dev

# Terminal 2: Run overlay
cd overlay-windows && cargo run -- --dev
```

### 3. Connect Test Client

```bash
# Send test permission request
node tests/tools/send-request.js \
  --tool "Bash" \
  --command "echo test" \
  --risk "low"

# Expected: Overlay appears with permission prompt
```

---

## Architecture Deep Dive

### Process Model

```
┌──────────────────────────────────────────────────┐
│ Claude Code (Electron Main Process)              │
│  - Runs user's agent interactions                │
│  - Intercepts tool permission checks             │
│  - Sends IPC requests to overlay                 │
└────────────────┬─────────────────────────────────┘
                 │
                 │ Unix Socket / Named Pipe
                 │ (JSON-RPC 2.0)
                 ↓
┌──────────────────────────────────────────────────┐
│ Overlay Service (Separate Process)               │
│                                                   │
│  ┌────────────────────────────────────────────┐  │
│  │ IPC Server (Node.js/TypeScript)            │  │
│  │  - Listens on Unix socket                   │  │
│  │  - Validates incoming requests              │  │
│  │  - Manages queue state                      │  │
│  │  - Logs to history database                 │  │
│  └─────────────┬────────────────────────────────┘  │
│                │                                   │
│                ↓                                   │
│  ┌────────────────────────────────────────────┐  │
│  │ Native Window Manager (Rust/Swift)         │  │
│  │  - Creates always-on-top window             │  │
│  │  - Handles OS-specific positioning          │  │
│  │  - Manages keyboard event capture           │  │
│  └─────────────┬────────────────────────────────┘  │
│                │                                   │
│                ↓                                   │
│  ┌────────────────────────────────────────────┐  │
│  │ WebView Renderer (WKWebView/WebView2)      │  │
│  │  - Loads HTML/CSS/JS ui                     │  │
│  │  - Handles user interactions                │  │
│  │  - Sends decisions back to IPC server       │  │
│  └────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────┘
```

### Data Flow Example

```
┌─────────────────────────────────────────────────────────┐
│ 1. User triggers tool in Claude Code                     │
│    Example: Read tool for /Users/me/file.txt            │
└────────────────────┬────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────┐
│ 2. Permission hook intercepts                            │
│    if (!hasPermission(tool)) → IPC request               │
└────────────────────┬────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────┐
│ 3. IPC message sent via Unix socket                      │
│    {                                                     │
│      "method": "permission.request",                     │
│      "params": {                                         │
│        "toolName": "Read",                               │
│        "parameters": { "file_path": "/Users/me/file.txt" }│
│      }                                                   │
│    }                                                     │
└────────────────────┬────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────┐
│ 4. Overlay service receives message                      │
│    - Validates schema                                    │
│    - Checks rules engine for auto-approve match          │
│    - If no match, adds to queue                          │
└────────────────────┬────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────┐
│ 5. Queue manager processes next item                     │
│    - Pops from FIFO queue                                │
│    - Sends to window manager                             │
└────────────────────┬────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────┐
│ 6. Window manager creates/updates overlay               │
│    - Positions window on active monitor                  │
│    - Sets always-on-top level                            │
│    - Loads WebView with request data                     │
└────────────────────┬────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────┐
│ 7. WebView renders UI (target: <200ms)                  │
│    - Displays tool name, description, risk badge         │
│    - Starts countdown timer                              │
│    - Captures keyboard focus                             │
└────────────────────┬────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────┐
│ 8. User presses Enter (approve) or Esc (deny)           │
│    - Keyboard event captured by global monitor           │
│    - Decision sent back to IPC server                    │
└────────────────────┬────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────┐
│ 9. IPC server processes decision                         │
│    - Logs to history database (async)                    │
│    - Sends response back to Claude Code                  │
└────────────────────┬────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────┐
│ 10. Claude Code receives response                        │
│     - If approved: Execute tool                          │
│     - If denied: Abort tool execution                    │
└─────────────────────────────────────────────────────────┘
```

---

## Key Components

### 1. IPC Server (TypeScript)

**Location**: `ipc-server/src/server.ts`

**Responsibilities**:
- Listen on Unix socket/named pipe
- Parse JSON-RPC messages
- Route to handlers (queue, rules, history)
- Manage overlay lifecycle

**Key APIs**:
```typescript
class IpcServer {
  start(): Promise<void>;
  stop(): Promise<void>;
  on(method: string, handler: MethodHandler): void;
  emit(method: string, params: any): void;
}

interface MethodHandler {
  (params: any, ctx: RequestContext): Promise<any>;
}
```

**Development Tips**:
- Use `pnpm dev` for auto-restart on file change
- Enable debug logging: `DEBUG=ipc:* pnpm dev`
- Test with: `node tests/tools/ipc-client.js`

### 2. Queue Manager (Rust)

**Location**: `core/src/queue/manager.rs`

**Responsibilities**:
- FIFO queue implementation
- Priority sorting
- Deduplication logic
- Max depth enforcement

**Key APIs**:
```rust
pub struct QueueManager {
    queue: VecDeque<PermissionRequest>,
    config: QueueConfig,
}

impl QueueManager {
    pub fn enqueue(&mut self, req: PermissionRequest) -> Result<()>;
    pub fn dequeue(&mut self) -> Option<PermissionRequest>;
    pub fn depth(&self) -> usize;
    pub fn clear(&mut self);
}
```

**Development Tips**:
- Run tests: `cargo test --package core queue`
- Benchmark: `cargo bench queue_performance`
- Profile: `cargo flamegraph --bench queue_bench`

### 3. Window Manager (Platform-Specific)

#### macOS (Swift)

**Location**: `overlay-macos/Sources/OverlayWindow.swift`

**Key APIs**:
```swift
class OverlayWindow: NSPanel {
    func show(request: PermissionRequest)
    func hide()
    func updatePosition(monitor: NSScreen)
}

class KeyboardHandler {
    func captureGlobalKeys()
    func releaseCapture()
    func on(key: Key, action: @escaping () -> Void)
}
```

**Development Tips**:
- Debug in Xcode for UI debugging
- Use Instruments for performance profiling
- Test on macOS 12, 13, 14, 15+

#### Linux (Rust + GTK)

**Location**: `overlay-linux/src/window.rs`

**Key APIs**:
```rust
pub struct OverlayWindow {
    window: gtk::Window,
    webview: webkit2gtk::WebView,
}

impl OverlayWindow {
    pub fn new() -> Self;
    pub fn show(&self, request: &PermissionRequest);
    pub fn hide(&self);
}
```

**Development Tips**:
- Test on X11 and Wayland separately
- Use `GTK_DEBUG=interactive` for widget inspector
- Profile with `perf record`

#### Windows (Rust + Windows API)

**Location**: `overlay-windows/src/window.rs`

**Key APIs**:
```rust
pub struct OverlayWindow {
    hwnd: HWND,
    webview: WebView2,
}

impl OverlayWindow {
    pub fn create() -> Result<Self>;
    pub fn show(&self, request: &PermissionRequest);
    pub fn set_topmost(&self);
}
```

**Development Tips**:
- Use Visual Studio debugger for Win32 debugging
- Test on Windows 10 21H2+ and Windows 11
- Profile with Windows Performance Analyzer

### 4. WebView UI (HTML/CSS/TS)

**Location**: `ui/index.html`, `ui/styles.css`, `ui/app.ts`

**Architecture**:
```
ui/
├── index.html         # Main HTML structure
├── styles.css         # Design system styles
├── app.ts             # Preact app logic
├── components/
│   ├── PromptCard.tsx      # Main prompt display
│   ├── QueueIndicator.tsx  # Queue depth badge
│   └── Countdown.tsx       # Timeout countdown
└── utils/
    ├── keyboard.ts    # Keyboard handler
    └── ipc-bridge.ts  # Bridge to native layer
```

**Key APIs**:
```typescript
// Native bridge (injected by platform)
interface NativeBridge {
  sendDecision(decision: 'approved' | 'denied'): void;
  createRule(pattern: RulePattern): void;
  openHistory(): void;
}

// Available as window.native
declare global {
  interface Window {
    native: NativeBridge;
  }
}
```

**Development Tips**:
- Use `pnpm dev:ui` for hot-reload development
- Test in Safari/Chrome (WebKit/Blink parity)
- Use browser DevTools (right-click → Inspect)

---

## Testing

### Unit Tests

**Rust Core**:
```bash
# Run all tests
cargo test --workspace

# Run specific module
cargo test --package core queue::tests

# Run with coverage
cargo tarpaulin --out Html
```

**TypeScript IPC**:
```bash
# Run all tests
pnpm test

# Run specific test file
pnpm test src/server.test.ts

# Coverage report
pnpm test:coverage
```

### Integration Tests

**End-to-End Flow**:
```bash
# Start all services
./scripts/start-dev.sh

# Run integration tests
pnpm test:integration

# Stops services automatically after tests
```

**Test Example** (`tests/integration/basic-flow.test.ts`):
```typescript
test('approve permission request', async () => {
  // Send request
  const response = await ipcClient.request('permission.request', {
    toolName: 'Read',
    description: 'Read test file',
    parameters: { file_path: '/tmp/test.txt' },
    riskLevel: 'low',
  });

  // Simulate user pressing Enter
  await simulateKeyPress('Enter');

  // Verify response
  expect(response.decision).toBe('approved');
  expect(response.latency).toBeLessThan(5000);
});
```

### Performance Tests

**Latency Benchmark**:
```bash
# Run latency benchmark
cargo bench latency

# Expected output:
# IPC round-trip:     15ms ± 3ms
# Window creation:    45ms ± 8ms
# Render to visible:  120ms ± 20ms
# Total to visible:   180ms ± 25ms ✓
```

**Load Test**:
```bash
# Send 1000 requests
./tests/tools/load-test.sh --requests 1000 --concurrent 10

# Verify:
# - All processed correctly
# - Memory stable (<150MB)
# - No crashes
```

### Manual Testing Checklist

**Cross-Platform**:
- [ ] Overlay appears on all virtual desktops/Spaces
- [ ] Keyboard shortcuts work globally
- [ ] Animations smooth (60fps)
- [ ] Multi-monitor positioning correct

**Edge Cases**:
- [ ] Rapid-fire requests (>10/sec)
- [ ] Very long description text (>500 chars)
- [ ] Timeout behavior correct
- [ ] Service crash recovery works
- [ ] Stale socket file handled

---

## Debugging

### Enable Debug Logging

**IPC Server**:
```bash
DEBUG=ipc:*,queue:*,rules:* pnpm dev
```

**Rust Core**:
```bash
RUST_LOG=debug cargo run
```

**macOS Overlay**:
```bash
# Enable Swift logging
defaults write com.anthropic.overlay EnableLogging -bool true
```

### Common Issues

#### 1. "Socket already in use"

**Cause**: Previous overlay process didn't clean up socket file

**Fix**:
```bash
rm /tmp/claude-overlay-$(id -u).sock
```

#### 2. Overlay not visible

**Debug**:
```bash
# Check window level
# macOS:
osascript -e 'tell application "System Events" to get properties of every window'

# Linux:
xprop -root | grep _NET_CLIENT_LIST
```

**Fix**: Ensure window level set to `statusWindow + 1` (macOS) or `_NET_WM_STATE_ABOVE` (Linux)

#### 3. High latency (>500ms)

**Profile**:
```bash
# macOS: Xcode Instruments (Time Profiler)
# Linux: perf record -g
# Analyze: Look for blocking operations
```

**Common Cause**: Synchronous disk I/O (history logging)

**Fix**: Make history writes async

---

## Building for Release

### macOS

```bash
cd overlay-macos
swift build -c release
codesign --sign "Developer ID Application" .build/release/overlay
productbuild --component .build/release/overlay.app /Applications overlay-installer.pkg
```

### Linux

```bash
cd overlay-linux
cargo build --release
strip target/release/overlay-linux

# Create .deb package
cargo deb

# Create .rpm package
cargo generate-rpm
```

### Windows

```bash
cd overlay-windows
cargo build --release

# Create installer with WiX
wix build installer.wixproj
```

---

## Contributing

### Code Style

**Rust**: Follow `rustfmt` defaults
```bash
cargo fmt --all
cargo clippy --all-targets -- -D warnings
```

**TypeScript**: Prettier + ESLint
```bash
pnpm format
pnpm lint
```

**Swift**: SwiftLint
```bash
swiftlint autocorrect
```

### Commit Messages

Follow Conventional Commits:
```
feat(macos): add multi-monitor support
fix(ipc): handle broken pipe gracefully
docs(protocol): clarify timeout behavior
perf(queue): optimize deduplication algorithm
```

### Pull Request Process

1. Create feature branch: `git checkout -b feat/my-feature`
2. Make changes with tests
3. Run full test suite: `./scripts/test-all.sh`
4. Open PR with description
5. Address review feedback
6. Merge after approval

---

## Profiling & Optimization

### macOS Performance

**Instruments**:
```bash
# Time Profiler (CPU)
instruments -t "Time Profiler" -D trace.trace .build/debug/overlay

# Allocations (Memory)
instruments -t "Allocations" -D mem.trace .build/debug/overlay
```

**Key Metrics**:
- App launch to window visible: <100ms
- Memory footprint: <80MB (idle)
- CPU usage: <2% (idle)

### Linux Performance

**Perf**:
```bash
# CPU profiling
perf record -g ./target/release/overlay-linux
perf report

# Memory profiling
valgrind --leak-check=full --track-origins=yes ./target/release/overlay-linux
```

### Windows Performance

**Windows Performance Analyzer**:
```bash
# Record trace
wpr -start CPU -start Memory
# ... run overlay ...
wpr -stop overlay-trace.etl

# Analyze in WPA
wpa overlay-trace.etl
```

---

## Release Checklist

**Pre-Release**:
- [ ] All tests passing on macOS/Linux/Windows
- [ ] No memory leaks (valgrind/Instruments clean)
- [ ] Latency <200ms on all platforms
- [ ] Documentation up to date
- [ ] CHANGELOG.md updated
- [ ] Version bumped in all manifests

**Release**:
- [ ] Git tag created: `git tag v1.0.0`
- [ ] Binaries built for all platforms
- [ ] Code signing completed
- [ ] Installer packages created
- [ ] GitHub release created
- [ ] Release notes published

**Post-Release**:
- [ ] Monitor crash reports
- [ ] Track performance metrics
- [ ] Address critical bugs within 24h

---

## Resources

**Documentation**:
- [IPC Protocol Spec](./overlay-ipc-protocol.md)
- [Configuration Schema](./overlay-config-schema.md)
- [Main Spec](../PERMISSION_OVERLAY_SPEC.md)

**External References**:
- [JSON-RPC 2.0 Spec](https://www.jsonrpc.org/specification)
- [NSPanel Documentation](https://developer.apple.com/documentation/appkit/nspanel)
- [GTK4 Layer Shell](https://github.com/wmww/gtk4-layer-shell)
- [WebView2 Guide](https://learn.microsoft.com/en-us/microsoft-edge/webview2/)

**Community**:
- GitHub Issues: Bug reports and feature requests
- Discussions: Architecture questions
- Slack: #claude-code-overlay (development chat)

---

## FAQ

**Q: Why a separate process instead of in Claude Code?**
A: Isolation prevents overlay crashes from affecting Claude Code, and allows overlay to persist across Claude Code restarts.

**Q: Why Unix sockets instead of HTTP?**
A: Lower latency (~5ms vs ~20ms), no port conflicts, automatic cleanup on process exit.

**Q: Why WebView instead of native UI?**
A: Faster iteration, consistent styling, easier animations. Can optimize to native later if needed.

**Q: How to debug WebView?**
A: macOS: Right-click overlay → Inspect. Linux: `GTK_DEBUG=interactive`. Windows: Launch with `--remote-debugging-port=9222`.

**Q: Performance impact on Claude Code?**
A: Minimal (<1% CPU, ~10MB RAM for IPC client). Bulk of resources in separate overlay process.

---

## Document Metadata
- **Version**: 1.0.0
- **Last Updated**: 2026-03-14
- **Audience**: Developers contributing to overlay system
- **Prerequisites**: Intermediate system programming knowledge
