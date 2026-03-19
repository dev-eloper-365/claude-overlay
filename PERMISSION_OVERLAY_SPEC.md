# Claude Code Permission Overlay Hook System
## Project Specification v1.1

---

## Executive Summary

An OS-level overlay alert system that intercepts Claude Code permission prompts and surfaces them as a minimal, keyboard-first HUD visible across all virtual desktops, spaces, and applications. Designed for zero workflow disruption with sub-200ms appearance latency.

---

## 1. Feature List

### 1.1 Core Features

#### Permission Interception
- **Hook Integration**: Intercept permission requests from Claude Code before they reach standard UI
- **Context Capture**: Extract tool name, parameters, description, and risk level
- **Priority Classification**: Auto-categorize prompts (low/medium/high/critical) based on action type:
  - **Low**: Read, Grep, Glob, TodoWrite, EnterPlanMode, ExitPlanMode
  - **Medium**: Edit, Write, NotebookEdit, Agent, Skill, AskUserQuestion
  - **High**: Bash (non-destructive), WebFetch, EnterWorktree
  - **Critical**: Bash with destructive patterns (`rm -rf`, `git push --force`, `DROP TABLE`, `sudo`)
- **Metadata Preservation**: Maintain full permission context for user review

#### Overlay Display
- **OS-Level Window**: Always-on-top, frameless window visible across all virtual desktops
- **Cross-Desktop Persistence**: Remains visible when switching Spaces (macOS), Virtual Desktops (Windows), or Workspaces (Linux)
- **Multi-Monitor Aware**: Intelligently positions on active monitor where Claude Code is running
- **Z-Index Priority**: Renders above full-screen apps, screensavers, and system dialogs

#### Quick-Approve UX
- **Keyboard-First Interaction**:
  - `Enter` / `Space` → Approve
  - `Esc` / `Backspace` → Deny
  - `Tab` → Cycle through queued prompts
  - `Cmd/Ctrl+D` → Approve and create rule for similar prompts
  - `?` → Show full details panel
- **Mouse Support**: Click approve/deny buttons (fallback only)
- **Auto-Dismiss**: Configurable timeout (default: 30s) with countdown indicator
- **One-Shot Actions**: Single keypress approval with instant visual feedback

#### Text Input Prompts
- **Inline Text Field**: Expands overlay to include a single-line (or multi-line) text input when Claude Code requires free-text response
- **Prompt Types Detected**:
  - `AskUserQuestion`: User selects an option or types custom text
  - Custom commit messages via hooks
  - Any hook or extension that expects `stdin` text
- **Option Selection**: When `AskUserQuestion` provides options, render as selectable chips — number keys (`1`, `2`, `3`, `4`) for quick select
- **"Other" Free Text**: When user selects "Other" or no options exist, overlay expands with a focused `<input>` / `<textarea>`
- **Submit**: `Enter` submits text (single-line) or `Cmd/Ctrl+Enter` submits (multi-line)
- **Cancel**: `Esc` cancels without sending, returns to queue
- **Character Counter**: Shows remaining chars if a limit exists
- **Input History**: `Up/Down` arrows recall previous text inputs from session
- **Paste Support**: Full clipboard paste (`Cmd/Ctrl+V`) with sanitization (strip control chars)

#### Queue Management
- **FIFO Processing**: First-in-first-out display order
- **Queue Visualization**: Compact indicator showing pending count (e.g., "2 more")
- **Batch Operations**: `Cmd/Ctrl+Shift+A` approves all queued items
- **Selective Review**: Arrow keys to preview next/previous in queue
- **Priority Re-ordering**: High-risk prompts jump queue position

#### History Log
- **Persistent Storage**: SQLite database of all decisions (timestamp, action, tool, outcome)
- **Session Grouping**: Organize history by Claude Code conversation sessions
- **Search & Filter**: Query by tool name, date range, decision type
- **Export**: JSON/CSV export for auditing
- **Replay Protection**: Flag identical prompts within 5-second window

**History Database Schema (SQLite)**:
```sql
CREATE TABLE decisions (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  request_id    TEXT NOT NULL UNIQUE,
  session_id    TEXT NOT NULL,
  tool_name     TEXT NOT NULL,
  description   TEXT,
  risk_level    TEXT CHECK(risk_level IN ('low','medium','high','critical')),
  prompt_type   TEXT CHECK(prompt_type IN ('permission','option_select','freetext')) DEFAULT 'permission',
  decision      TEXT CHECK(decision IN ('approved','denied','cancelled','timeout')),
  text_response TEXT,                        -- NULL for approve/deny, populated for text input
  parameters    TEXT,                        -- JSON blob (optional, configurable)
  latency_ms    INTEGER,                     -- Time from display to decision
  created_at    TEXT DEFAULT (datetime('now')),
  rule_id       TEXT                         -- FK to rules table if auto-approved
);

CREATE INDEX idx_decisions_session ON decisions(session_id);
CREATE INDEX idx_decisions_tool ON decisions(tool_name);
CREATE INDEX idx_decisions_created ON decisions(created_at);

CREATE TABLE rules (
  id            TEXT PRIMARY KEY,
  pattern       TEXT NOT NULL,               -- JSON pattern object
  action        TEXT CHECK(action IN ('approve','deny')),
  max_uses      INTEGER,
  uses_count    INTEGER DEFAULT 0,
  expires_at    TEXT,
  created_at    TEXT DEFAULT (datetime('now')),
  last_used_at  TEXT
);
```

### 1.2 Advanced Features

#### Smart Rules Engine
- **Pattern Matching**: Create approval rules based on tool + parameter patterns
- **Scope Limiting**: Rules expire after N uses or time period
- **Revocation**: One-click disable of any auto-approve rule
- **Safety Bounds**: Never auto-approve destructive Bash commands

#### Notification Integration
- **System Notifications**: Optional macOS/Windows/Linux notifications for queued prompts
- **Sound Alerts**: Configurable audio cues (subtle, distinct tones)
- **Do Not Disturb**: Respect OS-level DND settings

#### Accessibility
- **Screen Reader Support**: Full ARIA labels and VoiceOver integration
- **High Contrast Mode**: Alternates color scheme for visibility
- **Configurable Font Sizes**: 12px–24px range
- **Keyboard Navigation**: 100% keyboard operable

---

## 2. UX/Design System

### 2.1 Visual Geometry

#### Window Dimensions
```
Default Size: 480px × 140px (compact mode)
Expanded Size: 480px × 320px (full details mode)
Minimum Size: 360px × 120px (mobile/small screens)
```

#### Positioning Strategy
```
Primary: Top-center of active monitor
  - Horizontal: Screen center ± 0px
  - Vertical: 40px from top edge

Fallback: Bottom-right corner (if top occupied by other overlays)
  - Horizontal: Screen width - 500px
  - Vertical: Screen height - 180px
```

#### Layout Structure — Approve/Deny Mode
```
┌─────────────────────────────────────────────────┐
│ 🔵 TOOL REQUEST                        [×]      │  ← Header (28px height)
├─────────────────────────────────────────────────┤
│ Bash: "git push origin main"                    │  ← Description (60px)
│ Push commits to remote repository               │
├─────────────────────────────────────────────────┤
│ [Deny (Esc)]              [Approve (Enter)] ●3  │  ← Actions (40px)
└─────────────────────────────────────────────────┘
    ↑ Queue indicator (3 pending)
```

#### Layout Structure — Option Selection Mode
```
┌─────────────────────────────────────────────────┐
│ 🟣 INPUT REQUIRED                      [×]      │  ← Header (28px)
├─────────────────────────────────────────────────┤
│ Which database should we use?                   │  ← Question (40px)
├─────────────────────────────────────────────────┤
│ [1] PostgreSQL (Recommended)                    │  ← Option chips
│ [2] MySQL                                       │    (32px each)
│ [3] SQLite                                      │
├─────────────────────────────────────────────────┤
│ [Cancel (Esc)]              [Select (1-3)] ●1   │  ← Actions (40px)
└─────────────────────────────────────────────────┘
```

#### Layout Structure — Free Text Input Mode
```
┌─────────────────────────────────────────────────┐
│ 🟣 INPUT REQUIRED                      [×]      │  ← Header (28px)
├─────────────────────────────────────────────────┤
│ Enter your commit message:                      │  ← Prompt (32px)
├─────────────────────────────────────────────────┤
│ ┌─────────────────────────────────────────────┐ │
│ │ █                                           │ │  ← Text input (48-120px)
│ └─────────────────────────────────────────────┘ │    auto-grows for multiline
│                                          0/500  │  ← Char count (16px)
├─────────────────────────────────────────────────┤
│ [Cancel (Esc)]           [Submit (⏎/⌘⏎)] ●1    │  ← Actions (40px)
└─────────────────────────────────────────────────┘
```

#### Input Mode Window Dimensions
```
Option Selection: 480px × (140 + 32 × numOptions)px  (auto-height)
Free Text Single-Line: 480px × 200px
Free Text Multi-Line: 480px × 280px (auto-grows to max 400px)
```

### 2.2 Typography

#### Font Stack
```css
Primary: -apple-system, BlinkMacSystemFont, "Segoe UI",
         "SF Pro Display", Helvetica, Arial, sans-serif

Monospace: "SF Mono", "Cascadia Code", "Fira Code",
           "Consolas", monospace
```

#### Type Scale
- **Tool Name**: 14px semibold, letter-spacing: -0.2px
- **Description**: 13px regular, line-height: 1.4
- **Buttons**: 13px medium
- **Queue Count**: 11px bold
- **Metadata**: 11px regular, opacity: 0.7

### 2.3 Color System

#### Semantic Palette
```css
/* Light Mode (default) */
--bg-overlay: rgba(255, 255, 255, 0.95);
--bg-blur: saturate(180%) blur(20px);
--text-primary: #1a1a1a;
--text-secondary: #666666;
--border: rgba(0, 0, 0, 0.1);

/* Accent Colors */
--info: #007AFF;      /* Low risk (Read, Grep, Glob) */
--warning: #FF9500;   /* Medium risk (Edit, Write) */
--danger: #FF3B30;    /* High risk (Bash rm, git push) */
--critical: #D70015;  /* Critical (force push, delete) */

/* Interactive States */
--approve: #34C759;
--approve-hover: #2FB350;
--deny: #8E8E93;
--deny-hover: #6E6E73;

/* Dark Mode */
--bg-overlay-dark: rgba(30, 30, 30, 0.95);
--text-primary-dark: #f5f5f7;
--text-secondary-dark: #a1a1a6;
```

#### Risk-Based Highlighting
- **Info** (blue): Decorative 3px left border
- **Warning** (orange): 3px border + yellow glow
- **Danger** (red): 3px border + pulsing red glow (1.2s cycle)
- **Critical** (dark red): 4px border + urgent pulse + sound alert

### 2.4 Motion & Animation

#### Entrance
```
Appearance: Slide down + fade in
  - Duration: 180ms
  - Easing: cubic-bezier(0.22, 0.61, 0.36, 1) [ease-out-cubic]
  - Transform: translateY(-20px) → translateY(0)
  - Opacity: 0 → 1
  - Backdrop blur: 0 → 20px (staggered +40ms delay)
```

#### Exit
```
Dismissal: Fade out + scale
  - Duration: 120ms
  - Easing: ease-in
  - Transform: scale(1) → scale(0.96)
  - Opacity: 1 → 0
```

#### Attention Patterns
```
Queue Update: Gentle bounce
  - Scale: 1 → 1.03 → 1
  - Duration: 240ms

Timeout Warning (<5s remaining): Pulse border
  - Opacity: 1 → 0.6 → 1
  - Duration: 600ms loop
```

#### Performance Targets
- Render to visible: <200ms
- Interaction response: <16ms (60fps)
- Queue transition: <100ms
- GPU acceleration: All transforms and opacity

### 2.5 Interaction Patterns

#### Keyboard Navigation Map
```
Global Hotkey: Cmd/Ctrl+Shift+O → Show/Focus overlay
    (NOTE: Avoids Cmd+Shift+P which conflicts with VS Code Command Palette)
In Overlay (Approve/Deny Mode):
  ├─ Enter/Space → Approve and dismiss
  ├─ Esc/Backspace → Deny and dismiss
  ├─ Tab → Next queued prompt
  ├─ Shift+Tab → Previous queued prompt
  ├─ ? → Toggle detail panel
  ├─ H → Open history viewer
  ├─ R → Create approval rule
  └─ Q → Dismiss without action (re-prompts in 10s)

In Overlay (Option Selection Mode):
  ├─ 1-4 → Select option by number
  ├─ ↑/↓ → Highlight option (Enter to confirm)
  ├─ O → Jump to "Other" free text input
  └─ Esc → Cancel selection

In Overlay (Text Input Mode):
  ├─ Enter → Submit text (single-line)
  ├─ Cmd/Ctrl+Enter → Submit text (multi-line)
  ├─ Esc → Cancel input (with unsaved warning if text entered)
  ├─ ↑/↓ → Navigate input history (when input empty)
  ├─ Cmd/Ctrl+V → Paste from clipboard
  └─ Cmd/Ctrl+A → Select all text
```

#### Mouse Interactions
- **Hover States**: 100ms fade to hover color
- **Click Zones**: Minimum 44×44px touch targets
- **Drag-to-Reposition**: Hold header to move overlay (persists position)

#### Focus Management
- **Auto-Focus**: Overlay captures keyboard on appearance
- **Focus Trap**: Tab cycles within overlay, doesn't escape
- **Focus Release**: On dismiss, returns focus to Claude Code

---

## 3. Technical Architecture

### 3.1 System Components

```
┌─────────────────────────────────────────────────────┐
│              Claude Code (Main Process)              │
│  ┌────────────────────────────────────────────────┐ │
│  │  Permission Request Hook (hook.ts)             │ │
│  │  - Intercepts tool permission checks           │ │
│  │  - Emits to IPC channel: 'permission:request'  │ │
│  └────────────────┬───────────────────────────────┘ │
└───────────────────┼──────────────────────────────────┘
                    │ IPC (Unix Socket / Named Pipe)
                    ▼
┌─────────────────────────────────────────────────────┐
│         Overlay Service (Separate Process)           │
│  ┌────────────────────────────────────────────────┐ │
│  │  IPC Server (ipc-server.ts)                    │ │
│  │  - Receives permission requests                │ │
│  │  - Manages queue state                         │ │
│  │  - Emits decisions back to Claude Code         │ │
│  └────────────────┬───────────────────────────────┘ │
│                   ▼                                  │
│  ┌────────────────────────────────────────────────┐ │
│  │  Queue Manager (queue.ts)                      │ │
│  │  - FIFO processing                             │ │
│  │  - Priority sorting                            │ │
│  │  - Deduplication                               │ │
│  └────────────────┬───────────────────────────────┘ │
│                   ▼                                  │
│  ┌────────────────────────────────────────────────┐ │
│  │  OS Window Manager (platform/*)                │ │
│  │  - macOS: NSPanel + CALayer                    │ │
│  │  - Linux: X11 override-redirect / Wayland layer│ │
│  │  - Windows: WS_EX_TOPMOST + layered window     │ │
│  └────────────────┬───────────────────────────────┘ │
│                   ▼                                  │
│  ┌────────────────────────────────────────────────┐ │
│  │  Renderer (WebView / Native UI)               │ │
│  │  - HTML/CSS overlay content                    │ │
│  │  - Event handlers                              │ │
│  │  - Animation engine                            │ │
│  └────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────┐
│         History Service (Optional Process)           │
│  - SQLite database writer                            │
│  - Query API for history viewer                      │
└─────────────────────────────────────────────────────┘
```

### 3.2 Hook Implementation

#### Hook Type: **Claude Code Shell Hook (`PreToolUse` / `PostToolUse`)**

Claude Code's hook system executes shell commands at specific lifecycle events. The overlay registers as a `PreToolUse` hook that runs before every tool execution.

**Hook config** (`~/.claude/settings.json`):
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "",
        "command": "claude-overlay-hook permission --socket /tmp/claude-overlay-$(id -u).sock"
      }
    ]
  }
}
```

**Hook execution flow:**
1. Claude Code prepares to run a tool (e.g., `Bash`)
2. Claude Code invokes the `PreToolUse` hook shell command
3. Hook receives tool context as JSON on **stdin**:
   ```json
   { "hook_type": "PreToolUse", "tool_name": "Bash", "tool_input": { "command": "git push origin main" } }
   ```
4. `claude-overlay-hook` binary forwards this to the overlay's IPC socket
5. Overlay displays the prompt; user approves/denies/types
6. `claude-overlay-hook` outputs decision to **stdout** and exits:
   - **Exit code 0** + `{"decision":"approve"}` → Claude Code proceeds
   - **Exit code 2** + `{"decision":"block","reason":"User denied"}` → Claude Code aborts
   - For text input: `{"decision":"approve","text":"user's response"}`

#### Integration Points
1. **Hook Config**: `~/.claude/settings.json` → `hooks.PreToolUse` (auto-configured by VS Code extension or CLI installer)
2. **Hook Binary**: `claude-overlay-hook` — tiny CLI bundled with overlay, acts as stdin→IPC→stdout bridge
3. **Environment Variable**: `CLAUDE_OVERLAY_SOCKET` overrides default socket path
4. **Config File**: `~/.claude/overlay-config.json` for overlay preferences

### 3.3 IPC Layer

#### Protocol: **JSON-RPC 2.0 over Unix Socket (macOS/Linux) / Named Pipe (Windows)**

##### Permission Request (Approve/Deny)
```json
// Request (Claude Code → Overlay)
{
  "jsonrpc": "2.0",
  "id": "req_1234567890",
  "method": "permission.request",
  "params": {
    "toolName": "Bash",
    "description": "Run git push origin main",
    "parameters": {
      "command": "git push origin main"
    },
    "riskLevel": "high",
    "timestamp": "2026-03-14T10:30:00Z",
    "sessionId": "sess_abc123"
  }
}

// Response (Overlay → Claude Code)
{
  "jsonrpc": "2.0",
  "id": "req_1234567890",
  "result": {
    "decision": "approved",
    "timestamp": "2026-03-14T10:30:02.150Z",
    "latency": 2150,
    "ruleSaved": false
  }
}
```

##### Text Input Request (Option Selection)
```json
// Request (Claude Code → Overlay)
{
  "jsonrpc": "2.0",
  "id": "req_9876543210",
  "method": "input.select",
  "params": {
    "promptType": "option_select",
    "question": "Which database should we use?",
    "header": "Database",
    "options": [
      { "label": "PostgreSQL (Recommended)", "description": "Battle-tested, full SQL" },
      { "label": "MySQL", "description": "Widely deployed" },
      { "label": "SQLite", "description": "Embedded, zero config" }
    ],
    "multiSelect": false,
    "allowOther": true,
    "timestamp": "2026-03-14T10:31:00Z",
    "sessionId": "sess_abc123"
  }
}

// Response — user selected an option
{
  "jsonrpc": "2.0",
  "id": "req_9876543210",
  "result": {
    "inputType": "option",
    "selectedIndex": 0,
    "selectedLabel": "PostgreSQL (Recommended)",
    "timestamp": "2026-03-14T10:31:01.800Z",
    "latency": 1800
  }
}

// Response — user selected "Other" and typed custom text
{
  "jsonrpc": "2.0",
  "id": "req_9876543210",
  "result": {
    "inputType": "freetext",
    "text": "Use CockroachDB for distributed resilience",
    "timestamp": "2026-03-14T10:31:08.400Z",
    "latency": 8400
  }
}
```

##### Text Input Request (Free Text)
```json
// Request (Claude Code → Overlay)
{
  "jsonrpc": "2.0",
  "id": "req_5555555555",
  "method": "input.text",
  "params": {
    "promptType": "freetext",
    "question": "Enter your commit message:",
    "placeholder": "feat: ...",
    "multiline": true,
    "maxLength": 500,
    "required": true,
    "timestamp": "2026-03-14T10:32:00Z",
    "sessionId": "sess_abc123"
  }
}

// Response
{
  "jsonrpc": "2.0",
  "id": "req_5555555555",
  "result": {
    "inputType": "freetext",
    "text": "feat: add dark mode toggle to settings\n\nIncludes persistent user preference via localStorage.",
    "timestamp": "2026-03-14T10:32:14.200Z",
    "latency": 14200
  }
}
```

##### Error / Timeout / Cancel
```json
// Error (timeout/crash)
{
  "jsonrpc": "2.0",
  "id": "req_1234567890",
  "error": {
    "code": -32001,
    "message": "Overlay timeout after 30s",
    "data": { "fallbackAction": "deny" }
  }
}

// Cancel (user pressed Esc on text input)
{
  "jsonrpc": "2.0",
  "id": "req_5555555555",
  "error": {
    "code": -32002,
    "message": "User cancelled input",
    "data": { "fallbackAction": "cancel" }
  }
}
```

#### Fallback Behavior
- **Overlay Unreachable**: Fall back to standard Claude Code permission UI
- **Timeout**: Auto-deny after 30s, log warning
- **Crash Recovery**: Restart overlay service, queue pending requests

### 3.4 Platform-Specific Rendering

#### macOS (Primary Target)
**Technology**: Swift + AppKit + WebKit
```
- Window Type: NSPanel (floating, non-activating)
- Level: CGWindowLevelForKey(.statusWindow) + 1
- Collection Behavior: .canJoinAllSpaces | .fullScreenAuxiliary
- WebView: WKWebView for content rendering
- Backdrop: NSVisualEffectView (vibrancy: .hudWindow)
- Keyboard: Global event monitor via CGEventTap
```

**Cross-Space Visibility**: `NSWindowCollectionBehavior.canJoinAllSpaces`

#### Linux
**Technology**: Rust + GTK4 / X11 + WebKitGTK
```
X11:
  - Window Type: override-redirect (bypasses WM)
  - Attributes: _NET_WM_STATE_ABOVE, _NET_WM_STATE_STICKY
  - Level: XMapRaised + XSetInputFocus for keyboard

Wayland:
  - Layer Shell Protocol (zwlr_layer_shell_v1)
  - Layer: OVERLAY
  - Anchor: TOP | LEFT | RIGHT
  - Keyboard: exclusive keyboard interactivity
```

**Cross-Workspace**: `_NET_WM_STATE_STICKY` atom (X11) / Layer Shell (Wayland)

#### Windows
**Technology**: Rust + Windows API + WebView2
```
- Window Style: WS_POPUP (frameless)
- Extended Style: WS_EX_TOPMOST | WS_EX_TOOLWINDOW | WS_EX_LAYERED
- Layered: SetLayeredWindowAttributes for transparency
- Virtual Desktop: IVirtualDesktopManager monitoring
- Renderer: Microsoft Edge WebView2
- Keyboard: SetWindowsHookEx (WH_KEYBOARD_LL) for global hotkeys
```

**Cross-Desktop**: Manually re-create window on each virtual desktop (Windows API limitation workaround)

### 3.5 Renderer Architecture

#### Option A: Embedded WebView (Recommended)
**Pros**:
- Consistent UI across platforms
- CSS animations and flexbox
- Easy styling iteration
- Hot-reload during development

**Stack**:
- HTML/CSS for layout
- TypeScript for logic
- Preact/SolidJS (lightweight, <5KB) for reactivity
- No build step (ES modules)

#### Option B: Native UI
**Pros**:
- Faster cold start (<50ms)
- Lower memory footprint (~10MB vs ~50MB)
- Better OS integration

**Stack**:
- macOS: SwiftUI
- Linux: GTK4 native widgets
- Windows: Win32 controls

**Recommendation**: Start with WebView (faster iteration), optimize to native if performance issues arise.

### 3.6 Data Flow

```
User triggers tool in Claude Code
  ↓
Hook intercepts permission check
  ↓
Serialize context → IPC message
  ↓
Overlay service receives via socket
  ↓
Queue manager adds to FIFO (or jumps if high priority)
  ↓
Window manager creates/updates overlay
  ↓
Renderer displays prompt (target: <200ms total)
  ↓
User presses Enter (approve) or Esc (deny)
  ↓
Event captured by keyboard handler
  ↓
Decision serialized → IPC response
  ↓
Claude Code receives decision
  ↓
Tool executes (approved) or aborts (denied)
  ↓
History service logs decision (async, non-blocking)
```

**Latency Budget**:
- Hook intercept: <10ms
- IPC round-trip: <20ms
- Window creation: <80ms (cached window reuse)
- Render paint: <50ms
- User decision: variable (200ms–30s)
- IPC response: <20ms
- **Total to visible**: <160ms ✓ (under 200ms target)

---

## 4. Implementation Roadmap

### Phase 1: Core Architecture (Weeks 1-2)
**Goal**: Proof-of-concept on macOS

**Deliverables**:
- [x] Basic IPC server (Unix socket listener)
- [x] Simple permission hook bridge CLI (`hooks/claude-overlay-hook.js`)
- [x] Hardcoded overlay simulator (terminal-based PoC for Phase 1 wiring)
- [x] Approve/deny keyboard handling
- [ ] Round-trip latency < 300ms

**Tech Stack**:
- Swift for macOS overlay
- TypeScript for IPC server
- Node.js IPC client in Claude Code

**Success Criteria**: Press tool execute → overlay appears → press Enter → tool runs

### Phase 2: Visual Polish (Weeks 3-4)
**Goal**: Production-ready UI/UX

**Deliverables**:
- [ ] WebView integration with HTML/CSS
- [ ] Full design system implementation
- [ ] Smooth animations (entrance/exit)
- [ ] Risk-based color coding
- [ ] Responsive layout (multi-monitor)
- [ ] Optimize to <200ms latency

**Tech Stack**:
- WKWebView + local HTML
- CSS animations (GPU-accelerated)
- Preact for state management

**Success Criteria**: UI matches Figma designs, animations smooth at 60fps

### Phase 3: Queue & History (Weeks 5-6)
**Goal**: Handle multiple prompts

**Deliverables**:
- [ ] FIFO queue manager
- [ ] Queue visualization UI
- [ ] Tab navigation between queued items
- [ ] SQLite history database
- [ ] History viewer UI (separate window)
- [ ] Export to JSON/CSV

**Tech Stack**:
- TypeScript queue data structure
- better-sqlite3 for storage
- Simple HTML table for history viewer

**Success Criteria**: 10 rapid prompts → all queued → processable via keyboard

### Phase 4: Cross-Platform (Weeks 7-10)
**Goal**: Linux and Windows support

**Deliverables**:
- [ ] Rust overlay service (platform-agnostic core)
- [ ] Linux X11 implementation
- [ ] Linux Wayland implementation
- [ ] Windows implementation
- [ ] Platform abstraction layer
- [ ] Automated build pipeline (macOS/Linux/Windows)

**Tech Stack**:
- Rust (core logic)
- Platform-specific bindings (x11/gtk/winapi crates)
- Cross-compilation via cargo

**Success Criteria**: Same UX on all three OSes, <200ms latency maintained

### Phase 5: Smart Features (Weeks 11-12)
**Goal**: Power-user enhancements

**Deliverables**:
- [ ] Auto-approve rules engine
- [ ] Pattern matching for rules
- [ ] Rule management UI
- [ ] Configurable timeout
- [ ] Sound alerts (optional)
- [ ] System notification integration
- [ ] Preferences panel

**Tech Stack**:
- JSON schema for rules
- Pattern matching library (micromatch)
- Native sound APIs (AVFoundation/ALSA/XAudio2)

**Success Criteria**: "Auto-approve all Read calls" rule works end-to-end

### Phase 6: Hardening (Weeks 13-14)
**Goal**: Production stability

**Deliverables**:
- [ ] Crash recovery (auto-restart overlay service)
- [ ] Comprehensive error handling
- [ ] Accessibility audit (screen reader testing)
- [ ] Performance profiling (memory leaks, CPU spikes)
- [ ] Penetration testing (IPC injection attacks)
- [ ] Full test suite (unit + integration)
- [ ] Documentation (user guide + API docs)

**Tech Stack**:
- Jest for testing
- Valgrind/Instruments for profiling
- VoiceOver/NVDA for accessibility

**Success Criteria**: 24-hour stress test with 0 crashes, <100MB memory

---

## 5. Tooling & Dependencies

### Development Tools
- **Languages**: TypeScript (IPC), Swift (macOS), Rust (cross-platform core)
- **Build System**:
  - macOS: Xcode + Swift Package Manager
  - Linux/Windows: Cargo (Rust)
  - Node: pnpm
- **Version Control**: Git (monorepo structure)
- **CI/CD**: GitHub Actions (cross-platform builds)

### Core Dependencies

#### TypeScript/Node.js (IPC Layer)
```json
{
  "better-sqlite3": "^11.0.0",      // History database
  "nanoid": "^5.0.0",                // Request ID generation
  "ws": "^8.18.0",                   // WebSocket fallback (if Unix socket issues)
  "zod": "^3.23.0"                   // Schema validation
}
```

#### Swift (macOS Overlay)
```swift
// Swift Package Manager
dependencies: [
  .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")  // Auto-updates
]
```

#### Rust (Cross-Platform Core)
```toml
[dependencies]
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
tokio = { version = "1", features = ["full"] }  # Async runtime
tao = "0.30"                                     # Cross-platform windowing
wry = "0.43"                                     # WebView renderer
x11 = "2.21"                                     # Linux X11
wayland-client = "0.31"                          # Linux Wayland
windows = { version = "0.58", features = ["Win32"] }
```

### Testing Tools
- **Unit Tests**: Jest (TypeScript), XCTest (Swift), cargo test (Rust)
- **E2E Tests**: Playwright (simulate keyboard input)
- **Accessibility**: axe-core, pa11y
- **Performance**: Chrome DevTools (WebView profiling)

---

## 6. Edge Cases & Failure Modes

### 6.1 Multi-Prompt Scenarios

#### Rapid-Fire Requests
**Scenario**: User triggers 20 tool calls in 2 seconds

**Behavior**:
- Queue all 20 in FIFO order
- Display count badge: "●19 more"
- Tab key advances through queue
- Option to "Approve All" (Cmd+Shift+A) with confirmation for high-risk items

**Mitigation**:
- Dedupe identical requests within 5s window
- Auto-collapse similar tools (e.g., 5× Read → "Approve 5 Read operations?")
- Virtual scrolling in queue (only render visible items)

#### Concurrent High-Risk Operations
**Scenario**: `git push --force` + `rm -rf build/` queued simultaneously

**Behavior**:
- Separate high-risk items with visual divider
- Force individual approval (no batch approve for critical)
- Show expanded details by default for critical items

**Mitigation**: Priority queue bumps critical to front

### 6.2 System Failures

#### Overlay Process Crash
**Detection**: IPC health check every 5s (ping/pong)

**Recovery**:
1. Claude Code detects missed health check
2. Attempts restart of overlay service
3. Replays queued requests from in-memory buffer
4. Falls back to standard UI if restart fails 3×

**User Impact**: <5s interruption, in-flight requests safe

#### IPC Socket Corruption
**Symptoms**: Malformed JSON, broken pipe errors

**Recovery**:
1. Close and recreate socket
2. Flush send buffer
3. Resend last message with exponential backoff
4. Fallback to WebSocket on localhost:62341 (alternate transport)

**User Impact**: Transparent retry, <1s delay

#### Database Lock (SQLite)
**Scenario**: History database locked during write

**Mitigation**:
- Write-Ahead Logging (WAL mode) for concurrent reads
- 5s timeout on writes
- In-memory buffer for failed writes (flush later)
- Non-blocking history writes (fire-and-forget)

**User Impact**: None (history is non-critical path)

### 6.3 Display & Windowing

#### Full-Screen Applications
**macOS**: Use `.fullScreenAuxiliary` collection behavior (appears over full-screen apps)

**Linux**:
- X11: `_NET_WM_STATE_ABOVE` works over most full-screen apps
- Wayland: Layer shell OVERLAY layer renders above all surfaces

**Windows**: `WS_EX_TOPMOST` + foreground window check (re-raise if buried)

**Fallback**: If overlay invisible, send system notification as backup alert

#### Headless / SSH / CI Environments
**Problem**: No display server available (remote SSH, Docker, GitHub Actions)

**Detection**:
- Check `$DISPLAY` (X11) or `$WAYLAND_DISPLAY` (Wayland) on Linux
- Check `$SSH_CONNECTION` or `$SSH_TTY` for remote sessions
- Check `process.stdout.isTTY` for non-interactive shells
- macOS: Check `CGMainDisplayID() == 0` for headless

**Behavior**:
- Auto-disable overlay, fall back to Claude Code's standard terminal permission UI
- Log: `"overlay disabled: no display detected"`
- Set env var `CLAUDE_OVERLAY_DISABLED=headless` so hook exits immediately (exit 0, passthrough)
- If user has `--force-overlay` flag, attempt overlay anyway (useful for VNC/remote desktop)
**Desired Behavior**: Appear on monitor where Claude Code window is active

**Detection**:
- macOS: `NSScreen.screens` + `NSWindow.screen` for Claude Code
- Linux: `_NET_WM_FULLSCREEN_MONITORS` / wl_output
- Windows: `MonitorFromWindow(hWnd, MONITOR_DEFAULTTONEAREST)`

**Edge Case**: Claude Code spans two monitors → use monitor with majority of window area

#### Virtual Desktop/Spaces Transitions
**macOS Spaces**:
- `canJoinAllSpaces` keeps overlay visible on all Spaces
- If user switches Space mid-prompt, overlay follows seamlessly

**Windows Virtual Desktops**:
- IVirtualDesktopManager API tracks active desktop
- Re-create window instance on each desktop (annoying limitation)
- Cache window state to maintain position

**Linux Workspaces**:
- `_NET_WM_STATE_STICKY` (X11) pins to all workspaces
- Wayland: Layer shell automatically handles

**Fallback**: If cross-desktop fails, send notification when user returns to original desktop

### 6.4 Input & Focus

#### Focus Stealing Prevention
**Problem**: Overlay steals focus from user's active typing

**Mitigation**:
- macOS: Use non-activating NSPanel (doesn't steal app focus)
- Windows: `WS_EX_NOACTIVATE` extended style
- Linux: override-redirect windows don't participate in focus

**Keyboard Capture**: Use global event monitor, not focus-based input

#### Conflicting Keyboard Shortcuts
**Problem**: User's global hotkeys collide with overlay shortcuts

**Mitigation**:
- Make shortcuts configurable
- Default to rare combos (Cmd+Shift+O avoids VS Code's Cmd+Shift+P Command Palette)
- Detect conflicts via OS accessibility APIs
- Warn user on first launch if conflict detected

#### Screen Readers (Accessibility)
**Challenge**: Overlay content invisible to VoiceOver/NVDA

**Solution**:
- macOS: Mark NSPanel as `NSAccessibilityElement`, provide text descriptions
- Windows: Implement IAccessible interface
- Linux: ATK/AT-SPI support via GTK

**Announce Pattern**: "Permission request: Bash, git push. Press Enter to approve, Escape to deny."

### 6.5 Performance Degradation

#### Memory Leaks
**Potential Source**: WebView instances not deallocated

**Detection**: Monitor RSS memory every 30s, alert if >200MB

**Mitigation**:
- Destroy WebView on dismiss, recreate on next prompt
- Weak references to DOM elements
- Periodic forced GC (every 100 prompts)

#### High CPU Usage
**Potential Source**: Animation loops, CSS blur re-calculations

**Detection**: Sample CPU via `getrusage()`, alert if >5% sustained

**Mitigation**:
- Pause animations when overlay hidden
- Use `transform` and `opacity` only (GPU-accelerated)
- Debounce resize events (300ms)

#### Network Latency (IPC)
**Scenario**: Overloaded system, IPC socket slow

**Detection**: Track IPC round-trip time, alert if >100ms p99

**Mitigation**:
- Prioritize permission responses over history writes
- Use Unix domain sockets (faster than TCP loopback)
- Dedicated IPC thread (not main event loop)

### 6.6 Security Concerns

#### IPC Injection Attacks
**Attack**: Malicious process sends fake approval to Unix socket

**Defense**:
- Socket file permissions: `0600` (owner-only read/write)
- Validate message signatures (HMAC-SHA256 with shared secret)
- Process ID verification (check sender PID matches Claude Code)
- Reject out-of-order responses (sequence numbers)

#### Keylogging Risk
**Risk**: Malware captures keystrokes meant for overlay

**Mitigation**:
- No sensitive data entry in overlay (approval only)
- OS-level keystroke encryption (use Secure Input on macOS)
- Warn user if screen recording detected (macOS ScreenCaptureKit)

#### Privilege Escalation
**Risk**: Overlay runs with elevated privileges, exploited

**Defense**:
- Run overlay service as regular user (never root/admin)
- Sandbox on macOS (App Sandbox entitlements)
- Use seccomp-bpf on Linux (restrict syscalls)
- Minimal Windows privileges (no SE_DEBUG_NAME)

### 6.7 Text Input Failures

#### Focus Loss During Typing
**Problem**: User is typing into the overlay text field and another app steals focus

**Mitigation**:
- Overlay reclaims focus within 100ms if text field is active (non-activating panel receives key events via global event monitor)
- Persist partially typed text in local state; never discard on blur
- Visual indicator: border turns amber when unfocused, blue when refocused
- macOS: Use `NSPanel.becomesKeyOnlyIfNeeded` — but override with `makeKey()` while text input is active

#### Paste Injection
**Problem**: User pastes multi-MB clipboard content or content with embedded control characters

**Mitigation**:
- Strip NUL bytes, ANSI escape sequences, and non-printable chars (except \n for multiline)
- Enforce `maxLength` from the request params (default: 2000 chars)
- Truncate with toast: "Pasted text truncated to 2000 characters"
- Reject pastes >1MB entirely (show warning, don't freeze renderer)

#### Empty / Whitespace-Only Submission
**Problem**: User submits blank text for a `required: true` field

**Mitigation**:
- Trim whitespace before validation
- Shake animation on submit button + red border on input field
- "This field is required" inline validation message
- Submit button disabled until non-empty content detected

#### Long Text Rendering
**Problem**: User types 500+ chars in single-line mode, UI overflows

**Mitigation**:
- Auto-switch to multi-line textarea if text exceeds 80 chars
- Horizontal scroll in single-line mode (overflow-x: auto)
- Live character count: `450/500` turns red past 90% of limit

#### Multi-Line Submit Ambiguity
**Problem**: User presses Enter to add a newline but submits instead

**Mitigation**:
- Single-line: Enter submits (standard behavior)
- Multi-line: Enter adds newline, Cmd/Ctrl+Enter submits
- Clear visual cue: submit button shows "⌘⏎" or "Ctrl+Enter" label
- First-launch tooltip: "Press ⌘+Enter to submit"

#### Input History Conflicts
**Problem**: User presses Up arrow to recall history but has unsaved text in field

**Mitigation**:
- Only enable history recall when input is empty OR cursor is at position 0
- If input has text, Up/Down moves cursor normally (multi-line)
- History entries shown as ghost text (preview), Enter to accept, Esc to dismiss

### 6.8 User Experience Failures

#### Invisible Overlay (Unknown Cause)
**Detection**: No user input for 10s after prompt sent

**Recovery**:
1. Flash menu bar icon (macOS) / taskbar (Windows)
2. Send system notification: "Permission request waiting"
3. Play attention sound (if enabled)
4. Log diagnostic info (screen count, resolution, OS version)

**User Action**: Click menu bar icon → brings overlay to front

#### Timeout Confusion
**Problem**: User doesn't realize 30s timeout

**Mitigation**:
- Progress bar showing time remaining
- Color shift from blue → yellow → red as timeout approaches
- Sound alert at 10s, 5s remaining
- Configurable timeout in preferences

#### Accidental Approval
**Problem**: User hits Enter by muscle memory

**Mitigation**:
- 500ms grace period after overlay appears (ignore Enter)
- Configurable "confirm critical actions" toggle
- Visual feedback before execution (2s "Approved..." message)
- Undo last decision (Cmd+Z within 3s)

---

## 7. Success Metrics

### Performance KPIs
- **P50 Latency**: <150ms (request → visible)
- **P99 Latency**: <250ms
- **Memory Footprint**: <80MB (idle), <120MB (10 queued)
- **CPU Usage**: <2% (idle), <8% (active animations)
- **Crash Rate**: <0.1% of prompts

### User Experience KPIs
- **Keyboard-Only Success Rate**: >95% of users never use mouse
- **Multi-Desktop Success**: 100% visibility across virtual desktops
- **Accessibility Score**: WCAG 2.2 Level AA compliance
- **Time to Approval**: Median <2s (faster than standard UI)

### Reliability KPIs
- **Uptime**: >99.9% (max 8.6s downtime per day)
- **IPC Success Rate**: >99.99% (1 failure per 10k requests)
- **Fallback Trigger Rate**: <0.5% (rare fallback to standard UI)

---

## 8. Future Enhancements (Post-V1)

### Advanced Features
- **Voice Control**: "Approve" / "Deny" via speech recognition
- **Gesture Support**: Swipe right to approve (touchpad/trackpad)
- **Collaborative Mode**: Remote approval via Slack/Teams integration
- **AI Auto-Approval**: ML model learns user patterns, suggests approvals
- **Mobile Companion**: iOS/Android app for remote approvals

### Integration Opportunities
- **IDE Plugins**: VS Code, JetBrains native overlays
- **Terminal Multiplexers**: tmux/screen aware positioning
- **Window Managers**: i3/Yabai custom positioning rules
- **Cloud Sync**: Sync approval history + rules across devices

### Developer Tools
- **Overlay SDK**: Public API for third-party tool integrations
- **Custom Themes**: User-created CSS themes
- **Plugin System**: Extend with custom decision logic
- **Telemetry Dashboard**: Analyze approval patterns over time

---

## 9. VS Code Extension Integration

### 9.1 Why a VS Code Extension?

The overlay system exists as a standalone OS-level process, but the **easiest install path for users** is a VS Code extension because:

1. **One-click install** from the VS Code Marketplace (no `brew`, `cargo install`, or manual binary download)
2. **Auto-updates** via VS Code extension update mechanism
3. **Configuration UI** via VS Code Settings (no hand-editing JSON files)
4. **Lifecycle management** — extension activates/deactivates the overlay service automatically
5. **Claude Code Terminal integration** — hooks into Claude Code running inside VS Code's integrated terminal

The extension is a **thin orchestrator** — it bundles the native overlay binary and manages its lifecycle. The overlay itself still renders as an OS-level window (not a VS Code webview), preserving cross-desktop visibility.

### 9.2 Installation — Least User Effort

#### Path A: VS Code Marketplace (Recommended — 1 click)
```
1. Open VS Code
2. Cmd/Ctrl+Shift+X → Search "Claude Code Overlay"
3. Click "Install"
4. Done. Extension auto-starts overlay service on first Claude Code permission prompt.
```

The `.vsix` package bundles platform-specific native binaries:
```
claude-code-overlay-1.0.0.vsix
├── extension/
│   ├── dist/extension.js         (VS Code extension entry point)
│   ├── dist/extension.js.map
│   └── package.json
├── binaries/
│   ├── darwin-arm64/overlay       (macOS Apple Silicon)
│   ├── darwin-x64/overlay         (macOS Intel)
│   ├── linux-x64/overlay          (Linux x64)
│   └── win32-x64/overlay.exe     (Windows x64)
└── webview/
    ├── overlay.html
    ├── overlay.css
    └── overlay.js
```

**Platform detection at activation**: Extension reads `process.platform` + `process.arch` and spawns the correct binary.

#### Path B: CLI one-liner (for non-VS Code users / headless)
```bash
code --install-extension claude-code-overlay
```

#### Path C: Open VSX Registry (for VS Codium / Cursor / other forks)
Publish to Open VSX Registry simultaneously for non-Microsoft marketplace users.

#### Path D: Manual binary (escape hatch)
```bash
# macOS
brew install claude-code-overlay

# Linux
curl -fsSL https://get.claude-overlay.dev | sh

# Windows
winget install claude-code-overlay
```

### 9.3 Extension Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                      VS Code Extension                        │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐    │
│  │  Extension Entry (extension.ts)                       │    │
│  │  - activate(): spawn overlay binary, register hooks   │    │
│  │  - deactivate(): graceful shutdown overlay process    │    │
│  └──────────┬───────────────────────────────────────────┘    │
│             │                                                 │
│  ┌──────────▼───────────────────────────────────────────┐    │
│  │  Terminal Monitor (terminal-monitor.ts)                │    │
│  │  - Watches VS Code integrated terminal for Claude Code│    │
│  │  - Detects permission prompts via PTY output parsing  │    │
│  │  - Alternative: uses Claude Code hook config to route │    │
│  │    prompts to overlay IPC socket                      │    │
│  └──────────┬───────────────────────────────────────────┘    │
│             │                                                 │
│  ┌──────────▼───────────────────────────────────────────┐    │
│  │  Config Provider (config.ts)                          │    │
│  │  - Reads VS Code settings → writes overlay config     │    │
│  │  - Syncs theme (dark/light) with VS Code theme        │    │
│  │  - Exposes settings via contributes.configuration     │    │
│  └──────────┬───────────────────────────────────────────┘    │
│             │                                                 │
│  ┌──────────▼───────────────────────────────────────────┐    │
│  │  Overlay Process Manager (process-manager.ts)         │    │
│  │  - Spawns native binary as child process              │    │
│  │  - Health monitoring (restart on crash)               │    │
│  │  - stdout/stderr → VS Code Output Channel             │    │
│  │  - Graceful shutdown on extension deactivate          │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐    │
│  │  Status Bar Item                                      │    │
│  │  - Shows overlay status: ● Active / ○ Inactive       │    │
│  │  - Click → toggle overlay on/off                      │    │
│  │  - Shows pending permission count badge               │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐    │
│  │  Commands (contributes.commands)                      │    │
│  │  - claude-overlay.toggle          Toggle overlay      │    │
│  │  - claude-overlay.showHistory     Open history panel  │    │
│  │  - claude-overlay.manageRules     Open rules editor   │    │
│  │  - claude-overlay.approveAll      Approve all queued  │    │
│  │  - claude-overlay.clearQueue      Clear pending queue │    │
│  └──────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────┘
         │                                │
         │ spawn binary                   │ IPC socket
         ▼                                ▼
┌────────────────────┐     ┌──────────────────────────┐
│  Native Overlay    │◄───►│  Claude Code (Terminal)   │
│  Process (binary)  │ IPC │  with hook configured     │
└────────────────────┘     └──────────────────────────┘
```

### 9.4 Claude Code Hook Configuration

The extension auto-configures Claude Code's hook system on activation:

```json
// Auto-written to ~/.claude/settings.json (or project .claude/settings.json)
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "",
        "command": "claude-overlay-hook permission --socket /tmp/claude-overlay.sock"
      }
    ],
    "PostToolUse": [
      {
        "matcher": "",
        "command": "claude-overlay-hook log-result --socket /tmp/claude-overlay.sock"
      }
    ]
  }
}
```

**How the hook works**:
1. Claude Code hits a permission check → calls the `PreToolUse` hook command
2. `claude-overlay-hook` CLI (bundled tiny binary) sends the tool context to the overlay's IPC socket
3. Overlay displays the prompt, user approves/denies/types
4. `claude-overlay-hook` receives the decision via IPC and exits with:
   - Exit code `0` → approved (Claude Code proceeds)
   - Exit code `2` → denied (Claude Code blocks)
   - `stdout` contains JSON with text input if applicable
5. Claude Code reads the hook's stdout/exit code and acts accordingly

**For text input prompts (`AskUserQuestion`)**:
```bash
# Hook receives question context on stdin, writes user answer to stdout
echo '{"question":"Which DB?","options":["PG","MySQL"]}' | claude-overlay-hook input --socket /tmp/claude-overlay.sock
# stdout: {"selectedLabel":"PG"} or {"text":"CockroachDB"}
```

### 9.5 VS Code Settings (contributes.configuration)

```jsonc
{
  "claude-overlay.enabled": {
    "type": "boolean",
    "default": true,
    "description": "Enable the permission overlay HUD"
  },
  "claude-overlay.position": {
    "type": "string",
    "enum": ["top-center", "top-right", "bottom-right", "bottom-center"],
    "default": "top-center",
    "description": "Default overlay position on screen"
  },
  "claude-overlay.theme": {
    "type": "string",
    "enum": ["auto", "light", "dark"],
    "default": "auto",
    "description": "Overlay color theme (auto follows VS Code)"
  },
  "claude-overlay.timeout": {
    "type": "number",
    "default": 30,
    "minimum": 5,
    "maximum": 300,
    "description": "Seconds before auto-deny on unanswered prompt"
  },
  "claude-overlay.soundEnabled": {
    "type": "boolean",
    "default": false,
    "description": "Play sound on new permission request"
  },
  "claude-overlay.keyboardShortcut": {
    "type": "string",
    "default": "cmd+shift+p",
    "description": "Global hotkey to focus overlay"
  },
  "claude-overlay.autoApproveRules": {
    "type": "array",
    "default": [],
    "description": "Auto-approve rules (managed via claude-overlay.manageRules command)"
  },
  "claude-overlay.gracePeriodMs": {
    "type": "number",
    "default": 500,
    "description": "Milliseconds to ignore input after overlay appears (prevents accidental approval)"
  }
}
```

### 9.6 package.json (Extension Manifest — Key Fields)

```jsonc
{
  "name": "claude-code-overlay",
  "displayName": "Claude Code Permission Overlay",
  "description": "OS-level HUD for Claude Code permission prompts — approve, deny, or respond with a keypress",
  "version": "1.0.0",
  "publisher": "claude-code-extensions",
  "engines": { "vscode": "^1.85.0" },
  "categories": ["Other"],
  "keywords": ["claude", "claude-code", "permissions", "overlay", "HUD", "AI"],
  "activationEvents": [
    "onStartupFinished"
  ],
  "main": "./dist/extension.js",
  "contributes": {
    "commands": [
      { "command": "claude-overlay.toggle", "title": "Claude Overlay: Toggle" },
      { "command": "claude-overlay.showHistory", "title": "Claude Overlay: Show History" },
      { "command": "claude-overlay.manageRules", "title": "Claude Overlay: Manage Rules" },
      { "command": "claude-overlay.approveAll", "title": "Claude Overlay: Approve All Queued" },
      { "command": "claude-overlay.clearQueue", "title": "Claude Overlay: Clear Queue" }
    ],
    "configuration": { "$ref": "#/9.5" },
    "keybindings": [
      {
        "command": "claude-overlay.toggle",
        "key": "ctrl+shift+alt+p",
        "mac": "cmd+shift+ctrl+p"
      }
    ]
  }
}
```

### 9.7 Build & Publish Pipeline

```
Build Matrix (GitHub Actions):
┌──────────────────────────────────────────────────────┐
│ Trigger: git tag v*                                   │
├──────────────────────────────────────────────────────┤
│ Job 1: Build native binaries (parallel)               │
│   ├─ macOS arm64 (runs-on: macos-14)                 │
│   ├─ macOS x64 (runs-on: macos-13)                   │
│   ├─ Linux x64 (runs-on: ubuntu-22.04)               │
│   └─ Windows x64 (runs-on: windows-2022)             │
├──────────────────────────────────────────────────────┤
│ Job 2: Build extension (depends on Job 1)             │
│   ├─ Download all binary artifacts                    │
│   ├─ npm run compile (TypeScript → JS)                │
│   ├─ vsce package --target platform (per-platform)    │
│   ├─ → claude-code-overlay-darwin-arm64-1.0.0.vsix   │
│   ├─ → claude-code-overlay-darwin-x64-1.0.0.vsix     │
│   ├─ → claude-code-overlay-linux-x64-1.0.0.vsix      │
│   └─ → claude-code-overlay-win32-x64-1.0.0.vsix      │
├──────────────────────────────────────────────────────┤
│ Job 3: Publish (depends on Job 2)                     │
│   ├─ vsce publish (VS Code Marketplace)               │
│   ├─ ovsx publish (Open VSX Registry)                 │
│   └─ GitHub Release (attach .vsix + binaries)         │
└──────────────────────────────────────────────────────┘
```

**Per-platform VSIX**: Uses VS Code's [platform-specific extensions](https://code.visualstudio.com/api/working-with-extensions/publishing-extension#platformspecific-extensions) to publish separate `.vsix` per OS/arch — users automatically get the correct binary for their platform. No universal fat package.

### 9.8 First-Run Experience

```
1. User installs extension from Marketplace
2. Extension activates on VS Code startup
3. Status bar shows: "Claude Overlay: ● Initializing..."
4. Extension checks for Claude Code CLI:
   a. Found → auto-configure hook in ~/.claude/settings.json
   b. Not found → show info notification:
      "Claude Code CLI not detected. Install it to use the permission overlay."
      [Install Claude Code] [Dismiss]
5. Spawn native overlay binary (daemon mode, hidden until needed)
6. Status bar updates: "Claude Overlay: ● Ready"
7. First permission prompt from Claude Code → overlay appears
8. Show one-time welcome tooltip on overlay:
   "Enter = Approve | Esc = Deny | ? = Details"
   [Got it]
```

No configuration needed. Zero setup. Install → works.

---

## Appendix A: Technology Decision Matrix

| Component | Option 1 | Option 2 | Chosen | Rationale |
|-----------|----------|----------|--------|-----------|
| IPC Transport | Unix Socket | WebSocket | **Unix Socket** | Lower latency, OS-native |
| Renderer | WebView | Native UI | **WebView** | Faster iteration, consistent styling |
| Language (macOS) | Swift | Objective-C | **Swift** | Modern, better safety, SwiftUI option |
| Language (Cross-platform) | Rust | Go | **Rust** | Better FFI, memory safety, no GC pauses |
| Window Library (Rust) | Tao + Wry | Tauri | **Tao + Wry** | Lighter weight, more control |
| State Management | Preact | SolidJS | **Preact** | Proven, larger ecosystem |
| Database | SQLite | LevelDB | **SQLite** | Better query support, tooling |
| Build System | Makefiles | Just | **Cargo/SPM** | Language-native, better caching |

---

## Appendix B: API Reference

### Claude Code Hook Configuration (Real Hook System)
```json
// ~/.claude/settings.json — auto-configured by installer / VS Code extension
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "",
        "command": "claude-overlay-hook permission --socket /tmp/claude-overlay-$(id -u).sock"
      }
    ],
    "PostToolUse": [
      {
        "matcher": "",
        "command": "claude-overlay-hook log-result --socket /tmp/claude-overlay-$(id -u).sock"
      }
    ]
  }
}
```

### Hook Bridge (claude-overlay-hook CLI)
```bash
# Permission prompt — reads stdin, writes stdout
echo '{"hook_type":"PreToolUse","tool_name":"Bash","tool_input":{"command":"ls"}}' \
  | claude-overlay-hook permission --socket /tmp/claude-overlay-501.sock
# stdout: {"decision":"approve"}
# exit code: 0

# Text input prompt
echo '{"question":"Which DB?","options":["PG","MySQL"]}' \
  | claude-overlay-hook input --socket /tmp/claude-overlay-501.sock
# stdout: {"selectedLabel":"PG"} or {"text":"CockroachDB"}
# exit code: 0
```

### Overlay IPC Server
```typescript
// Overlay service endpoint
ipcServer.on('permission.request', async (params, respond) => {
  const queueItem = await queueManager.enqueue(params);
  const decision = await displayOverlay(queueItem);
  await historyLog.write(params, decision);
  respond({ decision, timestamp: Date.now() });
});
```

### Rules Engine
```typescript
// Auto-approval rule example
const rule = {
  pattern: { toolName: 'Read', parameters: { file_path: '/Users/**' } },
  action: 'approve',
  scope: { maxUses: 100, expiresAt: '2026-12-31' }
};

rulesEngine.add(rule);
```

---

## Document Metadata
- **Version**: 1.1.0
- **Last Updated**: 2026-03-14
- **Author**: System Design Specification
- **Status**: Draft - Awaiting Implementation
- **Target Platforms**: macOS 12+, Ubuntu 22.04+, Windows 11+
- **Distribution**: VS Code Marketplace (primary), Open VSX, Homebrew, winget
- **Estimated Effort**: 16 weeks (1 engineer) or 8 weeks (2 engineers)

---

**Next Steps**:
1. Review and approve specification
2. Scaffold VS Code extension repo (`yo code --type=ts`)
3. Build native overlay binary (Phase 1 — macOS PoC)
4. Wire Claude Code hook → IPC → overlay round-trip
5. Publish alpha to VS Code Marketplace (unlisted)
6. Create design mockups in Figma (parallel track)
7. Establish CI/CD pipeline for cross-platform builds
