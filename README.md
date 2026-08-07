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

- A keybind to toggle the terminal, e.g. in niri's `dms/binds.kdl`:
  `Mod+T { spawn "dms" "ipc" "call" "plugins" "toggle" "dropdownTerminal"; }`
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
- **Multi-monitor**: one slideout window **and one persistent terminal session
  per screen** (the DMS convention, same as the notepad). `toggle()` opens the
  terminal on the currently focused screen. A screen being plugged in or
  removed creates/destroys that screen's terminal cleanly.
- **Session persistence**: the shell/session is owned by the per-screen
  presenter, *not* by the slideout or the terminal view. Changing the slide
  edge, sizes, opacity, font or color scheme does not destroy the session or
  kill running jobs. Shells start lazily the first time each screen's terminal
  is opened (no duplicate shells at startup). Unloading the plugin closes all
  sessions.
- **Copy/paste**: `Ctrl+Shift+C` / `Ctrl+Shift+V`.
- **Mouse clipboard**: selecting text copies it immediately; right-click pastes.
  Both behaviors can be disabled independently in plugin settings.
- **Cursor**: with the optional downstream patch, follows the DMS theme's
  `color6` (the same color used as Ghostty's generated cursor color and by the
  final PS1 segment); the stock widget follows the cell foreground.
  blinking can be enabled in plugin settings.
- **Size toggle**: `Ctrl+T`, `F11`, or the header expand button toggles
  small/large while the terminal is open.
- **Escape to close**: pressing `Escape` closes the slideout, but only while the
  shell prompt is idle — programs that use Escape (vim, less, …) still receive
  it.
- **Focus**: the terminal grabs keyboard focus every time it opens.
- **Theme-aware colors**: a `dankcolors` scheme is generated from the DMS theme's
  ANSI palette and written to the user scheme dir (`~/.local/share/
  qmltermwidget-schemes/dankcolors.colorscheme`) on a best-effort basis. When it
  cannot be provisioned (dir missing/not writable), the terminal falls back to a
  scheme shipped with QMLTermWidget, so nothing is a hard dependency.

## Settings

All settings live under **Settings → Plugins → Dropdown Terminal**:

| Setting | Values / default | Effect |
|---|---|---|
| Slide edge | `right` / `left` / `top` / `bottom` (default `right`) | Which screen edge the terminal slides in from. Applied live. |
| Default size | `small` / `large` (default `small`) | Opening size for a *freshly* opened terminal. Changing it does **not** resize an already-open terminal (your per-session Ctrl+T/F11 state is preserved). |
| Small width / expanded width | 300–1200 / 400–1800 px (defaults `520` / `900`) | Side-panel sizes, clamped to the active screen. |
| Small height / expanded height | 300–900 / 400–1400 px (defaults `480` / `760`) | Top/bottom-panel sizes, clamped to the active screen. |
| Show header | on / off (default on) | Shows the title and expand/close buttons. Keyboard shortcuts still work when hidden. |
| Terminal opacity | 40–100 %, default `85` | Background-only opacity with the patched widget; whole-widget opacity with stock QMLTermWidget. |
| Blinking cursor | on / off (default off) | Whether the terminal text cursor blinks. |
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
 ├─ TerminalPresenter.qml   per screen; owns the persistent QMLTermSession
 │    ├─ SlideoutWindow.qml unified 4-edge slideout (mask, blur, animations)
 │    │    └─ TerminalPane.qml  QMLTermWidget view + shortcuts + refresh
 └─ StartupCheck.qml  fails gracefully if QMLTermWidget is absent
MySettings.qml       PluginSettings UI
schemes/             shipped default dankcolors.colorscheme (reference)
```

Responsibilities are separated so the terminal/session ownership
(`TerminalPresenter` + `QMLTermSession`), the presentation (`SlideoutWindow`),
the settings (daemon + `MySettings`) and daemon control (`Daemon.toggle`)
don't get tangled.

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
- `TerminalPresenter.qml` — per screen. Owns the persistent `QMLTermSession`
  (sibling of the slideout), starts the shell lazily on first open, restores
  focus on every open, and only applies `defaultSize` on the first open.
- `SlideoutWindow.qml` — unified 4-edge slideout (replaces the old
  `VerticalSlideout`/`DankSlideout` duplication). Handles the slide mask,
  blur geometry, delayed unmapping and rapid toggle/reversal safely.
- `TerminalPane.qml` — the terminal view. Shares the presenter's session,
  exposes `applyScheme()` with fallback, `refresh()` on window-visible/geometry
  settle, and the shortcuts (Ctrl+Shift+C/V, Ctrl+T, F11, Escape).
- `StartupCheck.qml` — blocks activation when `QMLTermWidget` is unavailable.
- `MySettings.qml` — the settings UI.
- `schemes/dankcolors.colorscheme` — the shipped default scheme; the daemon
  regenerates it from the DMS theme when available.

## Installation

1. Copy this directory to
   `~/.config/DankMaterialShell/plugins/dropdownTerminal/`.
2. Install `qmltermwidget` (Arch: `paru -S qmltermwidget`).
3. Enable **Dropdown Terminal** in DMS Settings → Plugins.
4. Optionally add a toggle keybind and/or the niri blur `layer-rule` (see
   Requirements).

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
3. **Ctrl+T and F11 are captured** while the terminal window is focused (they
   expand instead of reaching the running program).
4. **Windows-behind blur** (the optional niri `layer-rule`) can lag behind the
   slide animation on some setups — the blur appears once the surface settles.
5. **Escape-to-close** only fires at an idle shell prompt; if the foreground
   process can't be detected reliably (rare TUI edge cases) Escape may not close
   until the program exits.
6. **Cursor theming also needs the downstream package.** With it, the plugin
   binds the cursor to theme-reactive Dank16 `color6`; without it the cursor
   follows the foreground color of the cell underneath it.
7. **Scrollback size is not configurable from this plugin.** The installed
   QMLTermWidget build implements history sizing internally but does not expose
   its `historySize` property or setter to QML. Adding a working control requires
   a small QMLTermWidget API patch.

## Optional patched QMLTermWidget (Arch)

The small downstream patch in `patches/` exposes the renderer's existing
background opacity and fixed cursor-color support as QML properties. It is
pinned to the same upstream commit as Arch's `qmltermwidget 2.0.0.git1-1`.

Build and install it with:

```sh
cd ~/.config/DankMaterialShell/plugins/dropdownTerminal/patches
makepkg -si
systemctl --user restart dms
```

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
  its two small `TerminalDisplay` hunks need rebasing.
- To return to stock at any time, run `sudo pacman -S qmltermwidget` and restart
  DMS. The plugin feature-detects the patch and safely falls back to faded text
  and the stock cursor behavior.
