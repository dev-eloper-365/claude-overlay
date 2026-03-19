# Claude Code Overlay Installer Plan

## Goal
Create a one-liner curl installer:
```bash
curl -fsSL https://raw.githubusercontent.com/patel/claude-overlay/main/install.sh | bash
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  curl | bash                                                 │
│    ↓                                                         │
│  install.sh (hosted on GitHub)                               │
│    ↓                                                         │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │ 1. Check requirements (macOS, Swift, Node.js)           │ │
│  │ 2. Clone repo to ~/.claude-overlay                      │ │
│  │ 3. Build Swift overlay (release mode)                   │ │
│  │ 4. Install `claude-overlay` CLI to ~/.local/bin         │ │
│  │ 5. Configure ~/.claude/settings.json hook               │ │
│  │ 6. Add PATH if needed                                   │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Directory Structure After Install

```
~/.claude-overlay/           # Main installation
├── overlay-macos/           # Swift overlay source + binary
│   └── .build/release/overlay-macos
├── ipc-server/              # Node.js IPC server
├── hooks/                   # Claude Code hook
└── scripts/                 # Helper scripts

~/.local/bin/
└── claude-overlay           # CLI command (start/stop/status)

~/.claude/
└── settings.json            # Hook configuration
```

## CLI Commands

| Command | Action |
|---------|--------|
| `claude-overlay start` | Start IPC server + overlay |
| `claude-overlay stop` | Stop all processes |
| `claude-overlay status` | Check if running |
| `claude-overlay test` | Send test prompt |
| `claude-overlay logs` | Show logs |
| `claude-overlay uninstall` | Remove everything |

## Files to Create/Modify

1. **install.sh** - Main installer (already created, needs refinement)
2. **uninstall.sh** - Clean removal script
3. **README.md** - Update with install instructions

## Implementation Steps

1. [x] Create install.sh with all logic
2. [x] Test install.sh locally
3. [ ] Create GitHub repo
4. [ ] Update REPO_URL in install.sh
5. [ ] Test curl install

## Local Testing

```bash
# Test without cloning (use local files)
LOCAL_INSTALL=/Users/patel/Code/ClaudeCodeExtensions ./install.sh
```
