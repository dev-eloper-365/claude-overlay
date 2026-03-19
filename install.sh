#!/usr/bin/env bash
#
# Claude Code Permission Overlay Installer
#
# One-liner install:
#   curl -fsSL https://raw.githubusercontent.com/USER/claude-overlay/main/install.sh | bash
#
# Local install:
#   LOCAL_INSTALL=/path/to/repo ./install.sh
#
set -euo pipefail

VERSION="1.0.0"
INSTALL_DIR="${CLAUDE_OVERLAY_DIR:-$HOME/.claude-overlay}"
BIN_DIR="${HOME}/.local/bin"
REPO_URL="${REPO_URL:-https://github.com/dev-eloper-365/claude-overlay.git}"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${BLUE}▶${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
warn()    { echo -e "${YELLOW}!${NC} $1"; }
error()   { echo -e "${RED}✗${NC} $1"; exit 1; }

banner() {
    echo ""
    echo -e "${CYAN}${BOLD}Claude Code Permission Overlay${NC} v${VERSION}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

check_os() {
    [[ "$(uname)" == "Darwin" ]] || error "macOS required (detected: $(uname))"
    success "macOS $(sw_vers -productVersion)"
}

check_swift() {
    command -v swift &>/dev/null || error "Swift required. Run: xcode-select --install"
    success "Swift $(swift --version 2>&1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?'| head -1)"
}

check_node() {
    command -v node &>/dev/null || error "Node.js required. Run: brew install node"
    success "Node.js $(node --version)"
}

check_claude() {
    if command -v claude &>/dev/null; then
        success "Claude Code CLI found"
    else
        warn "Claude Code not in PATH (install from https://claude.ai/code)"
    fi
}

check_jq() {
    if command -v jq &>/dev/null; then
        success "jq found (will auto-merge settings)"
    else
        warn "jq not found — hook may need manual settings.json merge (brew install jq)"
    fi
}

install_source() {
    info "Installing to ${INSTALL_DIR}..."

    # Backup existing
    [[ -d "$INSTALL_DIR" ]] && rm -rf "$INSTALL_DIR.bak" && mv "$INSTALL_DIR" "$INSTALL_DIR.bak"

    if [[ -n "${LOCAL_INSTALL:-}" ]]; then
        # Local install mode
        cp -r "$LOCAL_INSTALL" "$INSTALL_DIR"
        success "Copied from $LOCAL_INSTALL"
    else
        # Clone from GitHub
        git clone --depth 1 --quiet "$REPO_URL" "$INSTALL_DIR" || error "Clone failed"
        success "Cloned from GitHub"
    fi
}

build_overlay() {
    info "Building native overlay (this may take a minute)..."

    cd "$INSTALL_DIR/overlay-macos"

    # Clean old builds
    rm -rf .build 2>/dev/null || true

    # Build release
    if swift build -c release 2>&1 | grep -q "Build complete"; then
        success "Build complete"
    else
        swift build -c release || error "Build failed"
        success "Build complete"
    fi

    [[ -f ".build/release/overlay-macos" ]] || error "Binary not found"
}

install_cli() {
    info "Installing CLI..."

    mkdir -p "$BIN_DIR"

    cat > "$BIN_DIR/claude-overlay" << 'EOFCLI'
#!/usr/bin/env bash
set -euo pipefail

DIR="${CLAUDE_OVERLAY_DIR:-$HOME/.claude-overlay}"
SOCK="/tmp/claude-overlay-$(id -u).sock"
PID_SERVER="/tmp/claude-overlay-server.pid"
PID_UI="/tmp/claude-overlay-ui.pid"
LOG_SERVER="/tmp/claude-overlay-server.log"
LOG_UI="/tmp/claude-overlay-ui.log"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

cmd_start() {
    # Check if already running
    if [[ -f "$PID_UI" ]] && kill -0 "$(cat "$PID_UI")" 2>/dev/null; then
        echo -e "${YELLOW}Already running${NC}"
        return 0
    fi

    # Cleanup
    [[ -S "$SOCK" ]] && rm -f "$SOCK"

    # Start server
    cd "$DIR/ipc-server"
    nohup node src/index.js > "$LOG_SERVER" 2>&1 &
    echo $! > "$PID_SERVER"

    sleep 0.3

    # Start overlay
    cd "$DIR/overlay-macos"
    nohup .build/release/overlay-macos > "$LOG_UI" 2>&1 &
    echo $! > "$PID_UI"

    sleep 0.5

    if kill -0 "$(cat "$PID_UI")" 2>/dev/null; then
        echo -e "${GREEN}✓ Overlay started${NC}"
        echo "  Keyboard: Enter=Allow, Esc=Deny"
    else
        echo -e "${RED}✗ Failed to start${NC}"
        cat "$LOG_UI"
        return 1
    fi
}

cmd_stop() {
    [[ -f "$PID_UI" ]] && kill "$(cat "$PID_UI")" 2>/dev/null
    [[ -f "$PID_SERVER" ]] && kill "$(cat "$PID_SERVER")" 2>/dev/null
    rm -f "$PID_UI" "$PID_SERVER" "$SOCK" 2>/dev/null
    pkill -f "overlay-macos" 2>/dev/null || true
    pkill -f "node.*ipc-server" 2>/dev/null || true
    echo -e "${GREEN}✓ Stopped${NC}"
}

cmd_restart() {
    cmd_stop
    sleep 0.5
    cmd_start
}

cmd_status() {
    if [[ -f "$PID_UI" ]] && kill -0 "$(cat "$PID_UI")" 2>/dev/null; then
        echo -e "${GREEN}● Running${NC}"
        echo "  Server PID: $(cat "$PID_SERVER" 2>/dev/null || echo 'unknown')"
        echo "  UI PID:     $(cat "$PID_UI" 2>/dev/null || echo 'unknown')"
        echo "  Socket:     $SOCK"
    else
        echo -e "${RED}○ Stopped${NC}"
        echo "  Run: claude-overlay start"
    fi
}

cmd_logs() {
    echo "=== Server ===" && tail -30 "$LOG_SERVER" 2>/dev/null || echo "(empty)"
    echo "" && echo "=== UI ===" && tail -30 "$LOG_UI" 2>/dev/null || echo "(empty)"
}

cmd_test() {
    cmd_start 2>/dev/null || true
    sleep 0.5
    echo "Sending test prompt... (press Enter or Esc in overlay)"
    cd "$DIR/scripts" && node test-all-prompts.js binary
}

cmd_uninstall() {
    echo "Uninstalling Claude Code Overlay..."
    cmd_stop 2>/dev/null || true
    rm -rf "$DIR"
    rm -f "$HOME/.local/bin/claude-overlay"
    echo -e "${GREEN}✓ Uninstalled${NC}"
    echo "Remove hook from ~/.claude/settings.json manually if needed"
}

cmd_help() {
    echo "Claude Code Permission Overlay"
    echo ""
    echo "Usage: claude-overlay <command>"
    echo ""
    echo "Commands:"
    echo "  start      Start overlay service"
    echo "  stop       Stop overlay service"
    echo "  restart    Restart overlay service"
    echo "  status     Show running status"
    echo "  logs       Show recent logs"
    echo "  test       Test with sample prompt"
    echo "  uninstall  Remove overlay completely"
    echo ""
}

case "${1:-help}" in
    start)     cmd_start ;;
    stop)      cmd_stop ;;
    restart)   cmd_restart ;;
    status)    cmd_status ;;
    logs)      cmd_logs ;;
    test)      cmd_test ;;
    uninstall) cmd_uninstall ;;
    *)         cmd_help ;;
esac
EOFCLI

    chmod +x "$BIN_DIR/claude-overlay"
    success "Installed: claude-overlay"
}

configure_hook() {
    info "Configuring Claude Code hook..."

    local claude_dir="$HOME/.claude"
    local settings="$claude_dir/settings.json"
    local hook="$INSTALL_DIR/hooks/claude-overlay-hook.js"

    mkdir -p "$claude_dir"

    # Make hook executable
    chmod +x "$hook"

    # Hook entry using the correct Claude Code settings schema
    local hook_entry
    hook_entry=$(cat <<EOFJSON
{
  "matcher": "Bash|Edit|Write|WebFetch|NotebookEdit",
  "hooks": [
    {
      "type": "command",
      "command": "$hook",
      "timeout": 30
    }
  ]
}
EOFJSON
)

    if [[ -f "$settings" ]]; then
        if grep -q "claude-overlay" "$settings" 2>/dev/null; then
            success "Hook already in settings.json"
        elif command -v jq &>/dev/null; then
            # Merge hook into existing settings using jq
            local tmp="$settings.tmp"
            jq --argjson entry "$hook_entry" '
                .hooks //= {} |
                .hooks.PreToolUse //= [] |
                .hooks.PreToolUse += [$entry]
            ' "$settings" > "$tmp" && mv "$tmp" "$settings"
            success "Merged hook into existing settings.json"
        else
            warn "Existing settings.json found but jq not available for auto-merge."
            warn "Add the following to the \"hooks\" section of $settings:"
            echo ""
            echo '  "hooks": {'
            echo '    "PreToolUse": ['
            echo "      $hook_entry"
            echo '    ]'
            echo '  }'
            echo ""
        fi
    else
        # Create new settings.json with just the hook
        cat > "$settings" <<EOFSETTINGS
{
  "hooks": {
    "PreToolUse": [
      $hook_entry
    ]
  }
}
EOFSETTINGS
        success "Created $settings"
    fi
}

update_path() {
    local rc=""
    [[ -f "$HOME/.zshrc" ]] && rc="$HOME/.zshrc"
    [[ -z "$rc" && -f "$HOME/.bashrc" ]] && rc="$HOME/.bashrc"

    if [[ -n "$rc" ]] && ! grep -q "$BIN_DIR" "$rc" 2>/dev/null; then
        echo "" >> "$rc"
        echo "# Claude Code Overlay" >> "$rc"
        echo 'export PATH="${PATH}:'"$BIN_DIR"'"' >> "$rc"
        success "Added to PATH in $rc"
    fi
}

print_done() {
    echo ""
    echo -e "${GREEN}${BOLD}Installation complete!${NC}"
    echo ""
    echo -e "${BOLD}Quick start:${NC}"
    echo ""
    echo "  1. Start overlay:    claude-overlay start"
    echo "  2. Use Claude:       claude"
    echo "  3. Stop overlay:     claude-overlay stop"
    echo ""
    echo -e "${BOLD}Keyboard shortcuts in overlay:${NC}"
    echo "  Enter / Space  →  Allow"
    echo "  Escape         →  Deny"
    echo ""

    if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
        echo -e "${YELLOW}Run this or restart terminal:${NC}"
        echo "  export PATH=\"\$PATH:$BIN_DIR\""
        echo ""
    fi
}

main() {
    banner

    info "Checking requirements..."
    check_os
    check_swift
    check_node
    check_claude
    check_jq
    echo ""

    install_source
    build_overlay
    install_cli
    configure_hook
    update_path

    print_done
}

main "$@"
