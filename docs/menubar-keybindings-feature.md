# Menu Bar & Customizable Keybindings

## Overview

Add a macOS menu bar status item to the overlay app with a minimal settings UI that lets users remap the Allow and Deny shortcut keys. The overlay currently hardcodes Enter/Space for Allow and Escape for Deny — this feature makes those configurable and persisted via UserDefaults.

## Current State (partially implemented)

The following code is already written in `overlay-macos/Sources/OverlayMacOS/main.swift` but **not yet wired into AppDelegate or compiled/tested**:

### Done

- **`KeybindSettings`** singleton (lines 8–62)
  - Persists `approveKeyCode`, `denyKeyCode`, `approveLabel`, `denyLabel` via UserDefaults
  - Posts `Notification.Name.keybindsChanged` on any change
  - `keyName(for:)` maps `UInt16` key codes to human-readable labels (A-Z, 0-9, F1-F6, Return, Escape, Space, Tab, Delete)
  - Defaults: Allow = Return, Deny = Escape

- **`MenuBarController`** (lines 70–265)
  - Creates `NSStatusItem` with `shield.checkered` SF Symbol (falls back to lock icon)
  - Menu shows current Allow/Deny keybinds, "Shortcuts..." item (Cmd+,), and Quit
  - `rebuildMenu()` auto-fires on `.keybindsChanged` notification
  - Settings window (320x180): two key-capture fields, a hint label, and "Reset to Defaults" button
  - Key capture flow: click field -> shows "Press a key..." in blue -> captures next keyDown -> saves to KeybindSettings

- **`setupKeyHandling()` updated** (lines ~895–940)
  - Local and global key monitors now read from `KeybindSettings.shared` instead of hardcoded key codes
  - Binary prompt mode checks `settings.approveKeyCode` / `settings.denyKeyCode`

### Remaining TODO

1. **Wire `MenuBarController` into `AppDelegate`**
   ```swift
   // In AppDelegate, add property:
   private var menuBar: MenuBarController?

   // In applicationDidFinishLaunching, add:
   menuBar = MenuBarController()
   ```

2. **Change activation policy** from `.accessory` to `.accessory` is correct (no dock icon), but verify the menu bar item appears. The status item should persist since `MenuBarController` is held by AppDelegate.

3. **Update button `keyEquivalent` on keybind change**
   - The binary mode buttons (`approveButton`, `denyButton`) still use hardcoded `keyEquivalent` values (`"\r"` and `"\u{1b}"`)
   - Add a `NotificationCenter` observer in `OverlayPanelController` to update these when keybinds change:
   ```swift
   NotificationCenter.default.addObserver(
       forName: .keybindsChanged, object: nil, queue: .main
   ) { [weak self] _ in
       self?.updateButtonKeyEquivalents()
   }
   ```
   - Map `keyCode -> keyEquivalent` string (only relevant for printable characters; for special keys like F-keys, clear the keyEquivalent and rely solely on the key monitor)

4. **Update button titles to show current keybind**
   - `approveButton.title` should reflect the current Allow key: e.g. `"Allow (Y)"` if remapped to Y
   - `denyButton.title` similarly

5. **Build and test**
   ```bash
   cd overlay-macos && swift build -c release
   ```

6. **Edge cases to handle**
   - Prevent assigning the same key to both Allow and Deny (show shake animation or alert)
   - Handle modifier keys (Cmd, Ctrl, Option, Shift) — currently ignored, decide whether to support combos
   - The settings window key monitor swallows events — ensure it doesn't conflict with the overlay's own key monitors (the settings window should only capture when visible and a field is in capture mode)
   - UserDefaults key code `0` is ambiguous (it's `kVK_ANSI_A`) — the current getter uses `!= 0` check which means A cannot be set as a shortcut. Fix: use a sentinel like `-1` or store as Optional via a different mechanism

7. **Deploy updated binary**
   ```bash
   cp overlay-macos/.build/release/overlay-macos ~/.claude-overlay/overlay-macos/.build/release/
   claude-overlay restart
   ```

## Architecture

```
┌──────────────────────────────────┐
│           AppDelegate            │
│  ┌────────────┐ ┌──────────────┐ │
│  │ MenuBar    │ │ OverlayPanel │ │
│  │ Controller │ │ Controller   │ │
│  └─────┬──────┘ └──────┬───────┘ │
│        │               │         │
│        ▼               ▼         │
│  ┌─────────────────────────────┐ │
│  │      KeybindSettings        │ │
│  │     (UserDefaults)          │ │
│  └─────────────────────────────┘ │
│        │                         │
│   .keybindsChanged               │
│   (NotificationCenter)           │
└──────────────────────────────────┘
```

- `KeybindSettings` is the single source of truth
- Both `MenuBarController` and `OverlayPanelController` observe `.keybindsChanged`
- `MenuBarController` owns the settings window and key capture
- `OverlayPanelController` reads keybinds at key-event time (no caching needed, UserDefaults is fast)

## File Changes

| File | Change |
|------|--------|
| `overlay-macos/Sources/OverlayMacOS/main.swift` | Added `KeybindSettings`, `MenuBarController`, updated `setupKeyHandling()` |
| `overlay-macos/Sources/OverlayMacOS/main.swift` | **TODO**: Wire into `AppDelegate`, update button keyEquivalents |

## Key Code Reference

| Key | Code | Constant |
|-----|------|----------|
| Return | 36 | `kVK_Return` |
| Escape | 53 | `kVK_Escape` |
| Space | 49 | `kVK_Space` |
| Tab | 48 | `kVK_Tab` |
| Delete | 51 | `kVK_Delete` |
| A-Z | 0-45 | `kVK_ANSI_A` etc. |
| 0-9 | 18-29 | `kVK_ANSI_0` etc. |

Import: `import Carbon.HIToolbox` (already added)
