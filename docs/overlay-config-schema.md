# Permission Overlay Configuration Schema

## Version 1.0.0

---

## Overview

Configuration for the Permission Overlay system is stored in JSON format with JSON Schema validation. This document describes all configuration options, their defaults, and validation rules.

---

## 1. Configuration File Locations

### 1.1 Primary Config
```
~/.claude/overlay-config.json
```

### 1.2 Platform-Specific Overrides
```
macOS:   ~/Library/Application Support/Claude/overlay-config.json
Linux:   ~/.config/claude/overlay-config.json
Windows: %APPDATA%\Claude\overlay-config.json
```

### 1.3 Project-Specific Config
```
./.claude/overlay-config.json  (in project root)
```

**Precedence**: Project > Platform-specific > Primary

---

## 2. JSON Schema

### 2.1 Root Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Permission Overlay Configuration",
  "type": "object",
  "properties": {
    "version": {
      "type": "string",
      "pattern": "^\\d+\\.\\d+\\.\\d+$",
      "description": "Config schema version",
      "default": "1.0.0"
    },
    "display": { "$ref": "#/definitions/DisplayConfig" },
    "behavior": { "$ref": "#/definitions/BehaviorConfig" },
    "keyboard": { "$ref": "#/definitions/KeyboardConfig" },
    "rules": { "$ref": "#/definitions/RulesConfig" },
    "notifications": { "$ref": "#/definitions/NotificationsConfig" },
    "history": { "$ref": "#/definitions/HistoryConfig" },
    "advanced": { "$ref": "#/definitions/AdvancedConfig" }
  },
  "additionalProperties": false
}
```

---

## 3. Configuration Sections

### 3.1 Display Configuration

```json
{
  "display": {
    "position": "top-center",
    "positionOffset": {
      "x": 0,
      "y": 40
    },
    "size": {
      "compact": { "width": 480, "height": 140 },
      "expanded": { "width": 480, "height": 320 }
    },
    "theme": "auto",
    "customColors": {
      "background": "rgba(255, 255, 255, 0.95)",
      "text": "#1a1a1a",
      "approve": "#34C759",
      "deny": "#8E8E93"
    },
    "fontSize": 13,
    "fontFamily": "system-ui",
    "blur": 20,
    "opacity": 0.95,
    "animation": {
      "enabled": true,
      "duration": 180,
      "easing": "ease-out-cubic"
    },
    "multiMonitor": {
      "strategy": "active-window",
      "fallback": "primary"
    }
  }
}
```

**Field Descriptions**:

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `position` | enum | `"top-center"` | Overlay position: `"top-center"`, `"top-left"`, `"top-right"`, `"bottom-center"`, `"bottom-left"`, `"bottom-right"`, `"center"` |
| `positionOffset.x` | number | `0` | Horizontal offset in pixels (-1000 to 1000) |
| `positionOffset.y` | number | `40` | Vertical offset in pixels (0 to 500) |
| `size.compact.width` | number | `480` | Compact mode width (360-800px) |
| `size.compact.height` | number | `140` | Compact mode height (120-300px) |
| `theme` | enum | `"auto"` | Color theme: `"auto"`, `"light"`, `"dark"`, `"high-contrast"` |
| `fontSize` | number | `13` | Base font size (10-24px) |
| `blur` | number | `20` | Backdrop blur radius (0-40px) |
| `opacity` | number | `0.95` | Background opacity (0.5-1.0) |
| `animation.enabled` | boolean | `true` | Enable animations |
| `animation.duration` | number | `180` | Animation duration (50-500ms) |
| `multiMonitor.strategy` | enum | `"active-window"` | `"active-window"`, `"primary"`, `"mouse-cursor"`, `"fixed-monitor"` |

**Example (Minimal Bottom-Right)**:
```json
{
  "display": {
    "position": "bottom-right",
    "positionOffset": { "x": -20, "y": -20 },
    "size": {
      "compact": { "width": 400, "height": 120 }
    },
    "theme": "dark"
  }
}
```

### 3.2 Behavior Configuration

```json
{
  "behavior": {
    "timeout": 30000,
    "timeoutAction": "deny",
    "timeoutPerRisk": {
      "low": 15000,
      "medium": 30000,
      "high": 45000,
      "critical": 90000
    },
    "showCountdown": true,
    "countdownWarningAt": 5000,
    "autoDismiss": true,
    "queueStrategy": "fifo",
    "maxQueueDepth": 100,
    "deduplication": {
      "enabled": true,
      "windowMs": 5000
    },
    "priorities": {
      "critical": 1,
      "high": 2,
      "medium": 3,
      "low": 4
    },
    "riskClassification": {
      "low": ["Read", "Grep", "Glob", "TodoWrite", "EnterPlanMode", "ExitPlanMode"],
      "medium": ["Edit", "Write", "NotebookEdit", "Agent", "Skill", "AskUserQuestion"],
      "high": ["Bash", "WebFetch", "EnterWorktree"],
      "critical": []
    }
  }
}
```

**Field Descriptions**:

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `timeout` | number | `30000` | Default auto-timeout in ms (5000-300000) |
| `timeoutAction` | enum | `"deny"` | Action on timeout: `"deny"`, `"approve"`, `"defer"` |
| `timeoutPerRisk` | object | see below | Override timeout per risk level (low/medium/high/critical) |
| `timeoutPerRisk.low` | number | `15000` | Timeout for low-risk prompts |
| `timeoutPerRisk.medium` | number | `30000` | Timeout for medium-risk prompts |
| `timeoutPerRisk.high` | number | `45000` | Timeout for high-risk prompts |
| `timeoutPerRisk.critical` | number | `90000` | Timeout for critical prompts |
| `showCountdown` | boolean | `true` | Show countdown timer |
| `countdownWarningAt` | number | `5000` | Warning threshold in ms |
| `autoDismiss` | boolean | `true` | Auto-dismiss after decision |
| `queueStrategy` | enum | `"fifo"` | `"fifo"`, `"lifo"`, `"priority"` |
| `maxQueueDepth` | number | `100` | Max queued requests (10-500) |
| `deduplication.enabled` | boolean | `true` | Dedupe identical requests |
| `deduplication.windowMs` | number | `5000` | Deduplication time window |

**Custom Risk Classification Example**:
```json
{
  "behavior": {
    "riskClassification": {
      "low": ["Read", "Grep", "Glob"],
      "medium": ["Edit", "Write", "TodoWrite"],
      "high": ["Bash", "WebFetch"],
      "critical": ["Bash.*rm -rf.*", "Bash.*git push --force.*"]
    }
  }
}
```

### 3.3 Keyboard Configuration

```json
{
  "keyboard": {
    "enabled": true,
    "shortcuts": {
      "approve": ["Enter", "Space"],
      "deny": ["Escape", "Backspace"],
      "nextInQueue": ["Tab"],
      "prevInQueue": ["Shift+Tab"],
      "toggleDetails": ["?"],
      "createRule": ["Cmd+D", "Ctrl+D"],
      "showHistory": ["H"],
      "approveAll": ["Cmd+Shift+A", "Ctrl+Shift+A"],
      "globalFocus": ["Cmd+Shift+O", "Ctrl+Shift+O"]
    },
    "repeatDelay": 500,
    "captureGlobal": true,
    "focusTrap": true
  }
}
```

**Field Descriptions**:

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `enabled` | boolean | `true` | Enable keyboard navigation |
| `shortcuts.*` | string[] | various | Key combinations (Electron accelerator format) |
| `repeatDelay` | number | `500` | Key repeat delay in ms |
| `captureGlobal` | boolean | `true` | Capture keys even when overlay unfocused |
| `focusTrap` | boolean | `true` | Trap focus within overlay |

**Accelerator Format**: Same as Electron
- Single key: `"A"`, `"1"`, `"Enter"`
- Modifiers: `"Cmd+A"`, `"Ctrl+Shift+P"`, `"Alt+F4"`
- Platform aliases: `"CmdOrCtrl+S"` (Cmd on macOS, Ctrl elsewhere)

**Example (Vim-style Navigation)**:
```json
{
  "keyboard": {
    "shortcuts": {
      "approve": ["Y"],
      "deny": ["N"],
      "nextInQueue": ["J"],
      "prevInQueue": ["K"],
      "toggleDetails": ["I"]
    }
  }
}
```

### 3.4 Rules Configuration

```json
{
  "rules": {
    "enabled": true,
    "autoApprovePatterns": [
      {
        "id": "auto-read-local",
        "pattern": {
          "toolName": "Read",
          "parameters": {
            "file_path": "/Users/username/project/**"
          }
        },
        "action": "approve",
        "scope": {
          "maxUses": 1000,
          "expiresAt": "2026-12-31T23:59:59Z"
        },
        "createdAt": "2026-03-14T10:00:00Z"
      }
    ],
    "autoDenyPatterns": [
      {
        "id": "deny-force-push",
        "pattern": {
          "toolName": "Bash",
          "parameters": {
            "command": ".*git push.*--force.*"
          }
        },
        "action": "deny",
        "scope": {}
      }
    ],
    "maxRules": 50,
    "allowUserCreation": true
  }
}
```

**Pattern Matching**:
- String values: Support regex (must be valid JS regex)
- Nested objects: Match recursively
- Arrays: Match any element
- `**` wildcard: Match any path segment

**Example (Auto-Approve Safe Tools)**:
```json
{
  "rules": {
    "autoApprovePatterns": [
      {
        "pattern": { "toolName": "Read" },
        "action": "approve",
        "scope": { "maxUses": 10000 }
      },
      {
        "pattern": { "toolName": "Grep" },
        "action": "approve"
      },
      {
        "pattern": { "toolName": "Glob" },
        "action": "approve"
      }
    ]
  }
}
```

### 3.5 Notifications Configuration

```json
{
  "notifications": {
    "enabled": true,
    "system": {
      "enabled": true,
      "onQueue": true,
      "onTimeout": true,
      "respectDND": true
    },
    "sound": {
      "enabled": true,
      "volume": 0.5,
      "sounds": {
        "request": "default",
        "approved": "success",
        "denied": "error",
        "timeout": "warning",
        "critical": "urgent"
      }
    },
    "visual": {
      "flashMenuBar": true,
      "badgeCount": true
    }
  }
}
```

**Sound Options**:
- `"default"`: System default notification sound
- `"success"`: Success chime
- `"error"`: Error beep
- `"warning"`: Warning tone
- `"urgent"`: Urgent alert (loud)
- `"silent"`: No sound
- `"/path/to/custom.mp3"`: Custom sound file

**Example (Silent Mode)**:
```json
{
  "notifications": {
    "system": { "enabled": false },
    "sound": { "enabled": false },
    "visual": {
      "flashMenuBar": true,
      "badgeCount": false
    }
  }
}
```

### 3.6 History Configuration

```json
{
  "history": {
    "enabled": true,
    "database": {
      "path": "~/.claude/overlay-history.db",
      "maxSizeMB": 100,
      "retentionDays": 90,
      "autoVacuum": true
    },
    "logging": {
      "includeParameters": false,
      "includeMetadata": true,
      "anonymize": false
    },
    "export": {
      "autoExport": false,
      "exportPath": "~/Downloads/claude-overlay-history.json",
      "exportFormat": "json"
    }
  }
}
```

**Field Descriptions**:

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `database.maxSizeMB` | number | `100` | Max database size (10-1000MB) |
| `database.retentionDays` | number | `90` | Delete records older than N days (7-365) |
| `logging.includeParameters` | boolean | `false` | Log full tool parameters (may contain sensitive data) |
| `anonymize` | boolean | `false` | Hash file paths and commands |
| `export.format` | enum | `"json"` | `"json"`, `"csv"`, `"sqlite"` |

**Privacy Example (Minimal Logging)**:
```json
{
  "history": {
    "logging": {
      "includeParameters": false,
      "includeMetadata": false,
      "anonymize": true
    },
    "database": {
      "retentionDays": 7
    }
  }
}
```

### 3.7 Advanced Configuration

```json
{
  "advanced": {
    "ipc": {
      "transport": "unix-socket",
      "socketPath": "/tmp/claude-overlay-{uid}.sock",
      "reconnectAttempts": 3,
      "reconnectDelay": 1000,
      "timeout": 5000
    },
    "performance": {
      "gpuAcceleration": true,
      "allowBackgroundThrottle": false,
      "maxMemoryMB": 150,
      "lazyLoadHistory": true
    },
    "security": {
      "requireAuth": true,
      "secretPath": "~/.claude/overlay-secret.key",
      "allowedClients": ["claude-code"],
      "validateSignatures": true
    },
    "debugging": {
      "enabled": false,
      "logLevel": "info",
      "logPath": "~/.claude/overlay.log",
      "metrics": false,
      "metricsPort": 9090
    }
  }
}
```

**Debug Mode Example**:
```json
{
  "advanced": {
    "debugging": {
      "enabled": true,
      "logLevel": "debug",
      "logPath": "/tmp/overlay-debug.log",
      "metrics": true
    }
  }
}
```

---

## 4. Complete Example Configurations

### 4.1 Minimal (Keyboard-Only Power User)

```json
{
  "version": "1.0.0",
  "display": {
    "position": "top-center",
    "theme": "dark",
    "animation": { "enabled": false }
  },
  "behavior": {
    "timeout": 10000,
    "timeoutAction": "deny"
  },
  "keyboard": {
    "shortcuts": {
      "approve": ["Y"],
      "deny": ["N"]
    }
  },
  "notifications": {
    "enabled": false
  }
}
```

### 4.2 Maximum Safety (Paranoid Mode)

```json
{
  "version": "1.0.0",
  "behavior": {
    "timeout": 60000,
    "timeoutAction": "deny",
    "riskClassification": {
      "low": ["Read", "Grep", "Glob"],
      "medium": ["Edit"],
      "high": ["Write", "Bash", "WebFetch"],
      "critical": [".*"]
    }
  },
  "rules": {
    "enabled": false
  },
  "notifications": {
    "sound": {
      "enabled": true,
      "sounds": {
        "request": "urgent",
        "critical": "urgent"
      }
    }
  },
  "history": {
    "logging": {
      "includeParameters": true,
      "includeMetadata": true
    }
  }
}
```

### 4.3 Auto-Approve Safe Tools

```json
{
  "version": "1.0.0",
  "rules": {
    "autoApprovePatterns": [
      {
        "pattern": { "toolName": "Read" },
        "action": "approve"
      },
      {
        "pattern": { "toolName": "Grep" },
        "action": "approve"
      },
      {
        "pattern": { "toolName": "Glob" },
        "action": "approve"
      },
      {
        "pattern": {
          "toolName": "Bash",
          "parameters": { "command": "git status" }
        },
        "action": "approve"
      }
    ],
    "autoDenyPatterns": [
      {
        "pattern": {
          "toolName": "Bash",
          "parameters": { "command": ".*rm -rf.*" }
        },
        "action": "deny"
      }
    ]
  }
}
```

### 4.4 Multi-Monitor Developer

```json
{
  "version": "1.0.0",
  "display": {
    "position": "top-center",
    "multiMonitor": {
      "strategy": "active-window",
      "fallback": "primary"
    }
  },
  "behavior": {
    "timeout": 20000,
    "queueStrategy": "priority"
  },
  "keyboard": {
    "shortcuts": {
      "globalFocus": ["Cmd+Shift+P"]
    },
    "captureGlobal": true
  }
}
```

---

## 5. Environment Variable Overrides

Configuration values can be overridden via environment variables:

```bash
# Override IPC socket path
export CLAUDE_OVERLAY_SOCKET=/custom/path/socket.sock

# Enable debug mode
export CLAUDE_OVERLAY_DEBUG=true

# Set theme
export CLAUDE_OVERLAY_THEME=dark

# Disable animations
export CLAUDE_OVERLAY_ANIMATIONS=false

# Custom timeout (ms)
export CLAUDE_OVERLAY_TIMEOUT=15000
```

**Precedence**: Environment vars > Project config > Platform config > User config > Defaults

---

## 6. Configuration Validation

### 6.1 Validation Errors

Invalid configurations are rejected with detailed error messages:

```json
{
  "valid": false,
  "errors": [
    {
      "field": "display.fontSize",
      "message": "Value 50 is outside allowed range (10-24)",
      "got": 50,
      "expected": "number between 10 and 24"
    },
    {
      "field": "behavior.timeout",
      "message": "Must be a positive integer",
      "got": "30s",
      "expected": "number (milliseconds)"
    }
  ]
}
```

### 6.2 Validation CLI

```bash
# Validate configuration file
claude-overlay validate ~/.claude/overlay-config.json

# Output:
# ✓ Configuration valid
# ✓ All rules have valid patterns
# ✓ No conflicting shortcuts
# ⚠ Warning: Very high maxQueueDepth (500)
```

### 6.3 Schema Linting

Use JSON Schema linters for IDE validation:

```json
{
  "$schema": "https://claude.ai/schemas/overlay-config-v1.schema.json"
}
```

**VS Code**: Auto-completion and validation with schema

---

## 7. Migration Guides

### 7.1 Upgrading from v0.9.x to v1.0.0

**Breaking Changes**:
- `display.opacity` now 0.0-1.0 (was 0-100)
- `behavior.riskLevels` renamed to `behavior.riskClassification`
- `keyboard.hotkeys` renamed to `keyboard.shortcuts`

**Automatic Migration**:
```bash
claude-overlay migrate-config ~/.claude/overlay-config.json --from 0.9 --to 1.0
```

---

## 8. Best Practices

### 8.1 Security
- ✅ Never commit `overlay-secret.key` to version control
- ✅ Use restrictive file permissions (`chmod 600` on configs)
- ✅ Avoid auto-approving destructive Bash commands
- ✅ Enable history logging for audit trails

### 8.2 Performance
- ✅ Disable animations on low-end hardware
- ✅ Set reasonable `maxQueueDepth` (50-100)
- ✅ Enable `lazyLoadHistory` for large databases
- ✅ Use `gpuAcceleration: true` when available

### 8.3 Usability
- ✅ Keep timeout >10s for thoughtful decisions
- ✅ Enable countdown warnings
- ✅ Use distinct shortcuts (avoid conflicts)
- ✅ Configure sound alerts for critical prompts

---

## Document Metadata
- **Version**: 1.0.0
- **Last Updated**: 2026-03-14
- **Status**: Draft
- **JSON Schema**: [overlay-config-v1.schema.json](../schemas/overlay-config-v1.schema.json)
