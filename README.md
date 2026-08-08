# Dropdown Terminal

A DMS **daemon plugin** that hosts a real `QMLTermWidget` terminal in a
layer-shell `PanelWindow` that slides in from any screen edge, toggled over the
DMS IPC plugin surface.

## Requirements

**Required**

- DMS (Dank Material Shell) with `Quickshell`.
- `qmltermwidget` (Arch AUR: `qmltermwidget`). It provides the
  `QMLTermWidget` / `QMLTermSession` QML types. If it is missing, the plugin's
  `startupCheck` blocks activation and shows a toast instead of rendering empty
  windows.
- A Wayland compositor supported by DMS (tested on niri). The plugin uses
  standard layer-shell panels and DMS's focused-screen detection, so it works on
  the compositors DMS supports (`niri`, `hyprland`, `sway`, `scroll`, `miracle`,
  `mango`).

**Optional**

- A keybind to toggle the terminal, e.g. in the active niri `config.kdl` (or
  `dms/binds.kdl` when that file is explicitly included by `config.kdl`):
  `Mod+T { spawn "dms" "ipc" "call" "plugins" "toggle" "dropdownTerminal"; }`.
  In niri, `Mod` normally means the Super/Windows key; use `Alt+T` if Alt is
  the intended modifier.
  (only the keybind above is used; there is no in-plugin keybinding for
  toggling).
- To blur the windows *behind* the terminal (not just the wallpaper), add a niri
  `layer-rule` for the `dms:slideout` namespace, e.g.:
  `layer-rule { match namespace="^dms:slideout$" background-effect { blur true xray false } }`.
  This is compositor-specific and purely optional; without it the terminal is
  still translucent over whatever is behind it, just not blurred.

## Behaviour

- **Real terminal**: a Konsole `Vt102Emulation` + PTY via `QMLTermSession`,
  rendered by `QMLTermWidget` (not a wrapper around another terminal app).
- **Slides from any edge** (right/left/top/bottom). Changing the edge in
  settings updates the live window; it never restarts your shell.
- **Multi-monitor**: one slideout window with an independent set of persistent
  terminal tabs per screen. `toggle()` opens the terminal on the currently
  focused screen. Removing a screen cleanly destroys only that screen's tabs.
- **Persistent tabs**: every tab owns a real `QMLTermSession`, PTY and terminal
  view. Hiding the slideout, switching tabs, changing the edge or resizing does
  not recreate shells or kill running jobs. Sessions persist for the lifetime
  of DMS; restarting DMS, unloading the plugin or removing their screen closes
  them.
- **Ghostty-style tab header**: a single tab uses the full terminal with no
  header. Creating a second tab reveals a flexible header with compact full
  working-directory labels such as `~/.config/DankMaterialShell/plugins`.
  While a foreground program is running, its command name temporarily replaces
  the path. New tabs inherit the active tab's directory.
- **Background activity**: output in an inactive tab adds an unread dot to its
  label. Selecting the tab clears the indicator. The native PTY data signal is
  used, so cursor blinking and repaints do not create false activity.
- **Tab controls**: `Ctrl+Shift+T` creates a tab, `Ctrl+Shift+W` closes the
  active tab, and `Ctrl+Tab` cycles. Drag tabs to reorder them with live
  midpoint snapping, or use `Ctrl+Shift+PageUp` / `Ctrl+Shift+PageDown`.
  Closing the final tab is intentionally disabled.
- **Copy/paste**: `Ctrl+Shift+C` / `Ctrl+Shift+V`.
- **Scrollback search**: the patched widget retains 10,000 lines per tab.
  `Ctrl+Shift+F` opens or closes search, `Enter` moves forward,
  `Shift+Enter` moves backward, and `Escape` closes the search bar. Matches are
  revealed and selected in the terminal output.
- **Mouse clipboard**: selecting text copies it immediately; right-click pastes.
  Both behaviors can be disabled independently in plugin settings.
- **Cursor**: with the optional downstream patch, follows the DMS theme's
  `color6` (the same color used as Ghostty's generated cursor color and by the
  final PS1 segment); the stock widget follows the cell foreground.
  blinking can be enabled in plugin settings.
- **Size toggle**: the configurable shortcut (default `F11`), `Ctrl+T`, or the
  header expand button toggles small/large while the terminal is open.
- **Escape to close**: pressing `Escape` closes the slideout, but only while the
  shell prompt is idle — programs that use Escape (vim, less, …) still receive
  it.
- **Focus**: the terminal grabs keyboard focus every time it opens.
- **Theme-aware colors**: a `dankcolors` scheme is generated from the DMS theme's
  ANSI palette and written to the user scheme dir (`~/.local/share/
  qmltermwidget-schemes/dankcolors.colorscheme`) on a best-effort basis. When it
  cannot be provisioned (dir missing/not writable), the terminal falls back to a
  scheme shipped with QMLTermWidget, so nothing is a hard dependency.
- **Readable dark-theme output**: ANSI color 0 uses the theme's bright-black
  (`color8`) gray, and bold default text retains the normal foreground instead
  of falling back to black.

## Settings

All settings live under **Settings → Plugins → Dropdown Terminal**:

| Setting | Values / default | Effect |
|---|---|---|
| Slide edge | `right` / `left` / `top` / `bottom` (default `right`) | Which screen edge the terminal slides in from. Applied live. |
| Default size | `small` / `large` (default `small`) | Opening size for a *freshly* opened terminal. Changing it does **not** resize an already-open terminal (your per-session expanded state is preserved). |
| Small width / expanded width | 300–1200 / 400–1800 px (defaults `520` / `900`) | Side-panel sizes, clamped to the active screen. |
| Small height / expanded height | 300–900 / 400–1400 px (defaults `480` / `760`) | Top/bottom-panel sizes, clamped to the active screen. |
| Show header | on / off (default on) | Shows directory tabs and expand/close buttons when multiple tabs exist. A single tab has no header. Keyboard shortcuts still work when hidden. |
| Terminal opacity | 40–100 %, default `85` | Background-only opacity with the patched widget; whole-widget opacity with stock QMLTermWidget. |
| Blinking cursor | on / off (default off) | Whether the terminal text cursor blinks. |
| Expand/minimize shortcut | Qt key sequence (default `F11`) | Toggles terminal size; `Ctrl+T` remains as a fixed fallback. |
| Copy on select | on / off (default on) | Immediately copies selected terminal text to the clipboard. |
| Right-click paste | on / off (default on) | Pastes clipboard contents with the right mouse button. Disable this when an application needs right-button mouse reporting. |
| Escape closes the terminal | on / off (default on) | Enables the idle-prompt-only Escape-to-close. |
| Terminal color scheme | scheme file name (default `dankcolors`) | Any `.colorscheme` name QMLTermWidget can load. |
| Terminal font family | text, default empty | Fixed-width font for the terminal; empty = the DMS mono font. |
| Terminal font size | 8–24 pt (default `12`) | Terminal text size. |

## Architecture

```
plugin.json          manifest (daemon + settings + startupCheck)
Daemon.qml           daemon root: validates settings, one TerminalPresenter per
                     screen, focused-screen toggle(), best-effort scheme write
 ├─ TerminalPresenter.qml   per-screen slideout and tab controller wiring
 │    ├─ SlideoutWindow.qml unified 4-edge slideout (mask, blur, animations)
 │    ├─ TerminalTabsHeader.qml dynamic tabs, activity, drag/snap, add/close
 │    └─ TerminalTabs.qml   owns one QMLTermSession + TerminalPane per tab
 │         └─ TerminalPane.qml QMLTermWidget view, clipboard, shortcuts, refresh
 └─ StartupCheck.qml  fails gracefully if QMLTermWidget is absent
MySettings.qml       PluginSettings UI
schemes/             shipped default dankcolors.colorscheme (reference)
```

Responsibilities are separated so tab/session ownership (`TerminalTabs`), tab
chrome (`TerminalTabsHeader`), presentation (`SlideoutWindow`), settings
(`Daemon` + `MySettings`) and daemon control (`Daemon.toggle`) don't get
tangled.

- `dms ipc call plugins toggle dropdownTerminal` calls `PluginService.togglePlugin`
  → `Daemon.toggle()` → the focused screen's presenter toggles.
- The daemon uses `Variants` over `SettingsData.getFilteredScreens("dropdownTerminal")`
  and `BarWidgetService.getFocusedScreenName()` for focused-screen targeting —
  the established DMS multi-screen patterns (no `Quickshell.screens[0]`).
- Screen geometry: small/expanded sizes are clamped against the active screen's
  available span, so both modes stay sensible on low-resolution and scaled
  displays.

## Files

- `Daemon.qml` — daemon root. Reads/validates settings, hosts the per-screen
  `Variants`, implements `toggle()`, and writes the generated `dankcolors`
  scheme via a `FileView` (no root, no hard-coded paths).
- `TerminalPresenter.qml` — per screen. Wires the slideout, tab controller and
  tab header together, restores focus, and applies `defaultSize` on first open.
- `SlideoutWindow.qml` — unified 4-edge slideout (replaces the old
  `VerticalSlideout`/`DankSlideout` duplication). Handles the slide mask,
  conditional/custom header, blur geometry, delayed unmapping and rapid
  toggle/reversal safely.
- `TerminalTabs.qml` — creates and owns up to nine persistent tab sessions and
  panes; handles creation, closing, selection, directory inheritance and
  keyboard reordering without rebuilding live terminal views.
- `TerminalTabsHeader.qml` — flexible path/command tab labels, unread-activity
  indicators, add/close controls, and animated drag reordering with midpoint
  snapping.
- `TerminalPane.qml` — one QMLTermWidget view. Implements native-signal
  copy-on-select and activity tracking, right-click paste, scrollback search,
  scheme fallback, deterministic refresh, Ctrl+Shift+C/V, Ctrl+T, the
  configurable size toggle and Escape handling.
- `StartupCheck.qml` — blocks activation when `QMLTermWidget` is unavailable.
- `MySettings.qml` — the settings UI.
- `schemes/dankcolors.colorscheme` — the shipped default scheme; the daemon
  regenerates it from the DMS theme when available.

## Installation

1. Copy this directory to
   `~/.config/DankMaterialShell/plugins/dropdownTerminal/`.
2. Install `qmltermwidget` (Arch: `paru -S qmltermwidget`).
3. Enable **Dropdown Terminal** in DMS Settings → Plugins.
4. Add a toggle keybind to the `binds` block in the niri configuration that is
   actually loaded. For example:

   ```kdl
   Alt+T hotkey-overlay-title="Dropdown Terminal" {
       spawn "dms" "ipc" "call" "plugins" "toggle" "dropdownTerminal";
   }
   ```

   A standalone `dms/binds.kdl` has no effect unless the main `config.kdl`
   includes it.
5. Restart DMS, wait a couple of seconds for plugin discovery, and test the
   toggle:

   ```sh
   systemctl --user restart dms
   dms ipc call plugins toggle dropdownTerminal
   ```

### Blur on niri

The terminal can be translucent without compositor blur. For background blur,
enable **Settings → Appearance → Background Blur** in DMS (`"blurEnabled":
true` in `~/.config/DankMaterialShell/settings.json`) and add this to the active
niri configuration:

```kdl
layer-rule {
    match namespace="^dms:slideout$"
    background-effect {
        blur true
        xray false
    }
}
```

`xray false` blurs the real windows behind the terminal. Xray mode generally
uses the wallpaper as the blur backdrop instead. Validate and reload niri after
editing:

```sh
niri validate -c ~/.config/niri/config.kdl
niri msg action load-config-file
```

## Development loop

- `Daemon.qml` / `plugin.json` changes:
  `dms ipc call plugin-scan reload dropdownTerminal`.
- `TerminalPane.qml` / `SlideoutWindow.qml` / `TerminalPresenter.qml` / new
  files: full restart — `systemctl --user restart dms`.
- Logs: `journalctl --user -u dms --since "1 min ago" | grep dropdownTerminal`.
  Raw `console.log` from plugin QML is not captured; `Log.scoped("dropdownTerminal")`
  is.

## Known limitations

1. **The stock QMLTermWidget still fades text.** Install the optional downstream
   package below to expose background-only opacity. The plugin feature-detects
   it and falls back safely to whole-widget opacity with the repository package.
2. **Palette applies at terminal start.** QMLTermWidget caches the scheme list
   per process, so the generated `dankcolors` palette is picked up when a
   terminal is created (or on the next DMS start after a theme change), not live
   on every theme change.
3. **Ctrl+T and the configured size shortcut are captured** while the terminal
   window is focused (they expand instead of reaching the running program).
4. **Windows-behind blur** (the optional niri `layer-rule`) can lag behind the
   slide animation on some setups — the blur appears once the surface settles.
5. **Escape-to-close** only fires at an idle shell prompt; if the foreground
   process can't be detected reliably (rare TUI edge cases) Escape may not close
   until the program exits.
6. **Cursor theming also needs the downstream package.** With it, the plugin
   binds the cursor to theme-reactive Dank16 `color6`; without it the cursor
   follows the foreground color of the cell underneath it.
7. **Enhanced scrollback needs the downstream package.** Stock QMLTermWidget
   still has its normal wheel scrollback, but the 10,000-line history and
   Ctrl+Shift+F match navigation use the added QML history and reveal APIs.
8. **Tabs are process-lifetime persistent, not tmux sessions.** They survive
   hiding and tab switches but not a DMS restart, logout or crash. A maximum of
   nine tabs is currently enforced per screen.

## Optional patched QMLTermWidget (Arch)

The small downstream patches in `patches/` expose the renderer's existing
background opacity and fixed cursor-color support as QML properties. They also
expose configurable history size, native received-output notifications and a
method that scrolls to and selects a search match. The package is pinned to the
same upstream commit as Arch's `qmltermwidget 2.0.0.git1-1`.

Build and install it with:

```sh
cd ~/.config/DankMaterialShell/plugins/dropdownTerminal/patches
makepkg --cleanbuild --clean --force
pkexec pacman -U --noconfirm --ask=4 \
  qmltermwidget-dank-2.0.0.git1.dank2-1-x86_64.pkg.tar.zst
pkexec ln -s ~/.local/share/qmltermwidget-schemes \
  /usr/lib/qt6/qml/QMLTermWidget/color-schemes
systemctl --user restart dms
```

`--ask=4` lets non-interactive Pacman confirm replacement of the conflicting
stock `qmltermwidget` package. The color-scheme link is required because the
patched package deliberately leaves schemes in the user-managed data
directory; without it QMLTermWidget may not find `dankcolors` and can render
with a white fallback background. If the link already exists, leave it in
place.

The PKGBUILD deliberately runs the build and install stages single-threaded to
avoid an upstream parallel-copy race in the keyboard layouts. The stock package
is sufficient for a basic terminal. The patched package adds background-only
opacity, a theme-controlled cursor, accurate activity notifications and the
enhanced scrollback/search behavior. Cursor blinking is a separate plugin
setting and is off by default.

This replaces the repository `qmltermwidget` package with
`qmltermwidget-dank`. To return to stock, install `qmltermwidget` again with
Pacman.

### Keeping the patch updated

- Run `pacman -Syu` normally. The custom package provides `qmltermwidget`, so
  Pacman keeps it installed; it is intentionally pinned and does not silently
  merge future upstream changes.
- Occasionally compare `pacman -Si qmltermwidget` with
  `pacman -Q qmltermwidget-dank`.
- To adopt a newer upstream release, update the commit and `pkgver` in
  `patches/PKGBUILD`, then run `makepkg -Csi`. If the patch no longer applies,
  the small `TerminalDisplay` and `KSession` hunks need rebasing.
- To return to stock at any time, run `sudo pacman -S qmltermwidget` and restart
  DMS. The plugin feature-detects the patch and safely falls back to faded text
  and the stock cursor behavior.
