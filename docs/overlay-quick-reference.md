# Permission Overlay Quick Reference

## One-Page Cheat Sheet

### Default Keyboard Shortcuts

```
┌─────────────────────────────────────────────────────┐
│ OVERLAY INTERACTION                                 │
├─────────────────────────────────────────────────────┤
│ Enter / Space       → Approve permission            │
│ Esc / Backspace     → Deny permission               │
│ Tab                 → Next in queue                 │
│ Shift+Tab           → Previous in queue             │
│ ?                   → Toggle details panel          │
│ H                   → Open history viewer           │
│ Cmd/Ctrl+D          → Approve + create rule         │
│ Cmd/Ctrl+Shift+A    → Approve all queued            │
│ Cmd/Ctrl+Shift+O    → Focus overlay (global)        │
│ Q                   → Dismiss (re-ask in 10s)       │
└─────────────────────────────────────────────────────┘
```

### Risk Levels

| Level | Color | Tools | Default Timeout |
|-------|-------|-------|-----------------|
| **Low** | Blue | Read, Grep, Glob, TodoWrite, EnterPlanMode | 15s |
| **Medium** | Orange | Edit, Write, NotebookEdit, Agent, Skill, AskUserQuestion | 30s |
| **High** | Red | Bash (non-destructive), WebFetch, EnterWorktree | 45s |
| **Critical** | Dark Red | `rm -rf`, `git push --force`, `sudo`, `DROP TABLE` | 90s |

### IPC Quick Commands

**Test Permission Request**:
```bash
echo '{"jsonrpc":"2.0","id":1,"method":"permission.request","params":{"toolName":"Read","description":"Test","parameters":{},"riskLevel":"low"}}' | nc -U /tmp/claude-overlay-$(id -u).sock
```

**Check Queue Status**:
```bash
echo '{"jsonrpc":"2.0","id":2,"method":"queue.status"}' | nc -U /tmp/claude-overlay-$(id -u).sock
```

**Ping Server**:
```bash
echo '{"jsonrpc":"2.0","id":3,"method":"ping"}' | nc -U /tmp/claude-overlay-$(id -u).sock
```

### File Locations

```
~/.claude/
├── overlay-config.json      # Main configuration
├── overlay-secret.key       # IPC auth secret (chmod 600)
├── overlay-history.db       # SQLite history database
└── overlay.log              # Debug logs (if enabled)

/tmp/
└── claude-overlay-{uid}.sock  # IPC socket (Unix/Linux)

Windows:
├── %APPDATA%\Claude\overlay-config.json
└── \\.\pipe\claude-overlay-{username}
```

### Configuration Snippets

**Auto-Approve Read Operations**:
```json
{
  "rules": {
    "autoApprovePatterns": [
      { "pattern": { "toolName": "Read" }, "action": "approve" }
    ]
  }
}
```

**Silent Mode (No Sounds/Notifications)**:
```json
{
  "notifications": {
    "system": { "enabled": false },
    "sound": { "enabled": false }
  }
}
```

**High Contrast Theme**:
```json
{
  "display": {
    "theme": "high-contrast",
    "fontSize": 16
  }
}
```

**Aggressive Timeouts**:
```json
{
  "behavior": {
    "timeout": 10000,
    "timeoutAction": "deny"
  }
}
```

### Development Commands

**Start Dev Environment**:
```bash
# Terminal 1: IPC Server
cd ipc-server && pnpm dev

# Terminal 2: Overlay (macOS)
cd overlay-macos && swift run overlay-dev

# Terminal 3: Send test request
node tests/tools/send-request.js --tool Read --risk low
```

**Run Tests**:
```bash
# All tests
./scripts/test-all.sh

# Unit tests only
cargo test --workspace  # Rust
pnpm test              # TypeScript

# Integration tests
pnpm test:integration

# Performance benchmarks
cargo bench
```

**Build Release**:
```bash
# macOS
cd overlay-macos && swift build -c release

# Linux
cd overlay-linux && cargo build --release

# Windows
cd overlay-windows && cargo build --release
```

### Debugging

**Enable Verbose Logging**:
```bash
# TypeScript IPC
DEBUG=ipc:*,queue:*,rules:* pnpm dev

# Rust Core
RUST_LOG=debug cargo run

# macOS Swift
defaults write com.anthropic.overlay EnableLogging -bool true
```

**Inspect WebView**:
```bash
# macOS: Right-click overlay → Inspect Element
# Linux: GTK_DEBUG=interactive ./overlay-linux
# Windows: Launch with --remote-debugging-port=9222
```

**Clean Stale State**:
```bash
# Remove socket file
rm /tmp/claude-overlay-$(id -u).sock

# Clear history database
rm ~/.claude/overlay-history.db

# Reset configuration
rm ~/.claude/overlay-config.json
```

### Performance Targets

| Metric | Target | Critical |
|--------|--------|----------|
| Request → Visible | <200ms | <500ms |
| Memory (Idle) | <80MB | <150MB |
| Memory (10 queued) | <120MB | <200MB |
| CPU (Idle) | <2% | <5% |
| CPU (Active) | <8% | <15% |
| IPC Latency | <50ms | <100ms |

### Common Error Codes

| Code | Message | Fix |
|------|---------|-----|
| -32001 | Overlay timeout | User didn't respond; auto-denied |
| -32002 | Service unavailable | Start overlay service |
| -32005 | Queue full | Wait or clear queue |
| -32006 | Duplicate request | Deduplication caught repeat |
| -32700 | Parse error | Check JSON syntax |

### Architecture Diagram (ASCII)

```
┌───────────────┐
│  Claude Code  │  (Main application)
└───────┬───────┘
        │ IPC (Unix Socket / Named Pipe)
        │ JSON-RPC 2.0
        ↓
┌────────────────────────────────────────┐
│      Overlay Service (Separate Process) │
│  ┌──────────────────────────────────┐  │
│  │ IPC Server (TypeScript/Node.js)  │  │
│  │  - Receives requests             │  │
│  │  - Manages queue                 │  │
│  │  - Logs history                  │  │
│  └────────┬─────────────────────────┘  │
│           │                            │
│           ↓                            │
│  ┌──────────────────────────────────┐  │
│  │ Window Manager (Rust/Swift)      │  │
│  │  - Creates overlay window         │  │
│  │  - Always-on-top positioning      │  │
│  │  - Keyboard capture               │  │
│  └────────┬─────────────────────────┘  │
│           │                            │
│           ↓                            │
│  ┌──────────────────────────────────┐  │
│  │ WebView Renderer                 │  │
│  │  - HTML/CSS/TS UI                 │  │
│  │  - User interactions              │  │
│  └──────────────────────────────────┘  │
└────────────────────────────────────────┘
```

### Typical Request Flow Latency Breakdown

```
User triggers tool in Claude Code
  ↓ ~10ms (hook intercept)
IPC message serialized
  ↓ ~20ms (Unix socket write + read)
Overlay service receives
  ↓ ~10ms (JSON parse + validation)
Queue manager processes
  ↓ ~5ms (queue operations)
Window manager updates overlay
  ↓ ~80ms (window create/update)
WebView renders UI
  ↓ ~50ms (HTML parse + CSS paint)
───────────────────────────────────
TOTAL: ~175ms ✓ (under 200ms target)

User makes decision
  ↓ 500ms - 30s (human response time)
Keyboard event captured
  ↓ ~5ms (event handler)
IPC response sent
  ↓ ~20ms (socket write + read)
Claude Code receives decision
  ↓ ~5ms (parse response)
Tool executes (or aborts)
```

### Useful Development Scripts

**Monitor IPC Traffic**:
```bash
# macOS/Linux
socat -v UNIX-CONNECT:/tmp/claude-overlay-$(id -u).sock -
```

**Simulate User Approval** (for automated testing):
```bash
# Auto-approve after 100ms
echo '{"autoApprove": true, "delay": 100}' > /tmp/overlay-test-config.json
```

**Check Process Status**:
```bash
# Find overlay process
ps aux | grep overlay

# Check memory usage
ps -o pid,vsz,rss,comm | grep overlay

# Monitor in real-time (Linux)
top -p $(pgrep overlay)
```

### Security Checklist

- ✅ Socket permissions: `chmod 600 /tmp/claude-overlay-*.sock`
- ✅ Config permissions: `chmod 600 ~/.claude/overlay-config.json`
- ✅ Secret file: `chmod 600 ~/.claude/overlay-secret.key`
- ✅ Never auto-approve: `rm -rf`, `--force` flags, `sudo`
- ✅ Enable history logging for audit trails
- ✅ Review auto-approve rules quarterly
- ✅ Validate IPC message signatures

### Troubleshooting Decision Tree

```
Overlay not appearing?
├─ Socket file exists? → No: Start overlay service
├─ Port available? → No: Kill stale process
├─ Window visible? → No: Check window level/z-index
└─ Keyboard working? → No: Check global event monitoring

High latency (>500ms)?
├─ IPC slow? → Profile with: DEBUG=ipc:* pnpm dev
├─ Rendering slow? → Disable animations
├─ Queue backlog? → Check queue depth
└─ Disk I/O? → Make history writes async

Crashes frequently?
├─ Memory leak? → Run with valgrind/Instruments
├─ Segfault? → Check Rust unsafe code
├─ Socket errors? → Verify socket cleanup
└─ WebView crash? → Update WebView runtime
```

### Release Versioning

```
v1.0.0 → Initial release
v1.1.0 → Minor features (backwards compatible)
v1.0.1 → Patch (bug fixes only)
v2.0.0 → Breaking changes (config schema update)
```

**Version Compatibility**:
- Overlay supports last 2 major versions
- Clients must negotiate version on connect
- Deprecation warnings for 6 months before removal

---

## Quick Links

- 📖 [Full Specification](../PERMISSION_OVERLAY_SPEC.md)
- 🔧 [Development Guide](./overlay-development-guide.md)
- 🔌 [IPC Protocol](./overlay-ipc-protocol.md)
- ⚙️ [Configuration Schema](./overlay-config-schema.md)
- 🐛 [Issue Tracker](https://github.com/anthropics/claude-code-overlay/issues)
- 💬 [Discussions](https://github.com/anthropics/claude-code-overlay/discussions)

---

**Version**: 1.0.0 | **Updated**: 2026-03-14
