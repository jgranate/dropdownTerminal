import QtCore
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services

// Daemon root for the Dropdown Terminal plugin.
//
// Responsibilities:
//   - validate and expose plugin settings (edge, size, opacity, font, scheme)
//   - create one TerminalPresenter per screen (DMS convention)
//   - expose toggle() for `dms ipc call plugins toggle dropdownTerminal`,
//     opening the terminal on the focused screen
//   - best-effort provisioning of the theme-reactive 'dankcolors' scheme file
Item {
    id: root

    property string pluginId: ""
    property var pluginService: null

    readonly property var log: Log.scoped("dropdownTerminal")

    // --- settings (validated, never trust stored strings blindly) ---
    property string slideEdge: "right"
    property string defaultSize: "small"
    property int terminalOpacity: 85
    property bool cursorBlink: false
    readonly property color cursorColor: (Theme.dank16 && Theme.dank16.default && Theme.dank16.default.color6)
                                         ? Theme.dank16.default.color6 : "#ffcc66"
    property bool escapeToClose: true
    property string colorSchemeName: "dankcolors"
    property string fontFamily: ""
    property int fontSize: 12
    property int smallWidth: 520
    property int expandedWidth: 900
    property int smallHeight: 480
    property int expandedHeight: 760
    property bool showHeader: true
    property bool copyOnSelect: true
    property bool rightClickPaste: true

    function normalizeEdge(v) {
        return ["left", "right", "top", "bottom"].indexOf(v) !== -1 ? v : "right"
    }

    function normalizeSize(v) {
        return v === "large" ? "large" : "small"
    }

    function reloadSettings() {
        slideEdge = normalizeEdge(pluginService ? pluginService.loadPluginData(pluginId, "slideEdge", "right") : "right")
        defaultSize = normalizeSize(pluginService ? pluginService.loadPluginData(pluginId, "defaultSize", "small") : "small")
        const rawOpacity = Number(pluginService ? pluginService.loadPluginData(pluginId, "terminalOpacity", 85) : 85)
        terminalOpacity = isFinite(rawOpacity) ? Math.max(40, Math.min(100, Math.round(rawOpacity))) : 85
        const rawCursorBlink = pluginService ? pluginService.loadPluginData(pluginId, "cursorBlink", false) : false
        cursorBlink = rawCursorBlink === true || rawCursorBlink === 1 || String(rawCursorBlink).toLowerCase() === "true"
        const rawEscape = pluginService ? pluginService.loadPluginData(pluginId, "escapeToClose", true) : true
        escapeToClose = rawEscape !== false
        const rawScheme = pluginService ? pluginService.loadPluginData(pluginId, "terminalColorScheme", "dankcolors") : "dankcolors"
        colorSchemeName = String(rawScheme || "dankcolors").trim() || "dankcolors"
        const rawFont = pluginService ? pluginService.loadPluginData(pluginId, "terminalFont", "") : ""
        fontFamily = String(rawFont || "")
        const rawFontSize = Number(pluginService ? pluginService.loadPluginData(pluginId, "terminalFontSize", 12) : 12)
        fontSize = isFinite(rawFontSize) ? Math.max(8, Math.min(24, Math.round(rawFontSize))) : 12
        const rawSmallWidth = Number(pluginService ? pluginService.loadPluginData(pluginId, "smallWidth", 520) : 520)
        smallWidth = isFinite(rawSmallWidth) ? Math.max(300, Math.min(1200, Math.round(rawSmallWidth))) : 520
        const rawExpandedWidth = Number(pluginService ? pluginService.loadPluginData(pluginId, "expandedWidth", 900) : 900)
        expandedWidth = isFinite(rawExpandedWidth) ? Math.max(smallWidth, Math.min(1800, Math.round(rawExpandedWidth))) : 900
        const rawSmallHeight = Number(pluginService ? pluginService.loadPluginData(pluginId, "smallHeight", 480) : 480)
        smallHeight = isFinite(rawSmallHeight) ? Math.max(300, Math.min(900, Math.round(rawSmallHeight))) : 480
        const rawExpandedHeight = Number(pluginService ? pluginService.loadPluginData(pluginId, "expandedHeight", 760) : 760)
        expandedHeight = isFinite(rawExpandedHeight) ? Math.max(smallHeight, Math.min(1400, Math.round(rawExpandedHeight))) : 760
        const rawShowHeader = pluginService ? pluginService.loadPluginData(pluginId, "showHeader", true) : true
        showHeader = !(rawShowHeader === false || rawShowHeader === 0 || String(rawShowHeader).toLowerCase() === "false")
        const rawCopyOnSelect = pluginService ? pluginService.loadPluginData(pluginId, "copyOnSelect", true) : true
        copyOnSelect = !(rawCopyOnSelect === false || rawCopyOnSelect === 0 || String(rawCopyOnSelect).toLowerCase() === "false")
        const rawRightClickPaste = pluginService ? pluginService.loadPluginData(pluginId, "rightClickPaste", true) : true
        rightClickPaste = !(rawRightClickPaste === false || rawRightClickPaste === 0 || String(rawRightClickPaste).toLowerCase() === "false")
    }

    Component.onCompleted: root.reloadSettings()

    Connections {
        target: pluginService
        function onPluginDataChanged(id) {
            if (id === pluginId)
                root.reloadSettings()
        }
    }

    // One presenter (window + session) per screen, filtered by the DMS screen
    // preference mechanism. Screens are removed/added through the model.
    // One presenter (window + session) per screen, filtered by the DMS screen
    // preference mechanism. Screens are removed/added through the model.
    Variants {
        id: presenterVariants
        model: SettingsData.getFilteredScreens("dropdownTerminal")

        delegate: TerminalPresenter {
            slideEdge: root.slideEdge
            defaultExpanded: root.defaultSize === "large"
            terminalOpacityPercent: root.terminalOpacity
            cursorBlink: root.cursorBlink
            cursorColor: root.cursorColor
            escapeToClose: root.escapeToClose
            colorSchemeName: root.colorSchemeName
            fontFamily: root.fontFamily
            fontSize: root.fontSize
            smallWidth: root.smallWidth
            expandedWidth: root.expandedWidth
            smallHeight: root.smallHeight
            expandedHeight: root.expandedHeight
            showHeader: root.showHeader
            copyOnSelect: root.copyOnSelect
            rightClickPaste: root.rightClickPaste
        }
    }

    function activePresenter() {
        const variants = presenterVariants.instances
        const count = variants ? variants.length : 0
        if (count === 0)
            return null

        const focused = BarWidgetService.getFocusedScreenName()
        if (focused) {
            for (let i = 0; i < count; i++) {
                const p = variants[i]
                if (p.modelData && p.modelData.name === focused)
                    return p
            }
        }
        for (let i = 0; i < count; i++) {
            if (variants[i].isVisible)
                return variants[i]
        }
        return variants[0]
    }

    function toggle() {
        const p = root.activePresenter()
        if (p)
            p.toggle()
        else
            root.log.warn("toggle requested but no screen is available")
    }

    // --- color-scheme provisioning ---
    // QMLTermWidget reads schemes from the first <importPath>/QMLTermWidget/
    // color-schemes directory. On this setup that resolves to a user-writable
    // data dir (typically ~/.local/share/qmltermwidget-schemes). Writing is
    // best-effort: when it is not possible the terminal falls back to a scheme
    // shipped with QMLTermWidget, so nothing is a hard dependency.
    readonly property string schemeDir: Paths.strip(StandardPaths.writableLocation(StandardPaths.GenericDataLocation).toString()) + "/qmltermwidget-schemes"
    readonly property string schemeFile: root.schemeDir + "/dankcolors.colorscheme"

    readonly property var defaultPalette: [
        "#14172a", "#ff6456", "#7dff66", "#ffe256",
        "#f2b843", "#764e00", "#ffcc66", "#fff8ec",
        "#a5a096", "#ff958c", "#a4ff93", "#ffed93",
        "#ffd37c", "#ffdb93", "#ffe8ba", "#fffcf7"
    ]
    readonly property string defaultBackground: "#141218"
    readonly property string defaultForeground: "#e6e0e9"

    function generateScheme() {
        const d = (Theme.dank16 && Theme.dank16.default) ? Theme.dank16.default : null
        let ini = "[General]\nDescription=Dank Colors (DMS theme)\nOpacity=1\n\n"
        ini += "[Background]\nColor=" + root.defaultBackground + "\n\n"
        ini += "[Foreground]\nColor=" + root.defaultForeground + "\n\n"
        for (let i = 0; i < 8; i++)
            ini += "[Color" + i + "]\nColor=" + (d ? (d["color" + i] || root.defaultPalette[i]) : root.defaultPalette[i]) + "\n\n"
        for (let i = 0; i < 8; i++)
            ini += "[Color" + i + "Intense]\nColor=" + (d ? (d["color" + (i + 8)] || root.defaultPalette[i + 8]) : root.defaultPalette[i + 8]) + "\n\n"
        return ini
    }

    function writeScheme() {
        Paths.mkdir(root.schemeDir)
        schemeWriter.path = root.schemeFile
        schemeWriter.setText(root.generateScheme())
    }

    FileView {
        id: schemeWriter
        blockWrites: true
        atomicWrites: true
        onSaved: {
            root.log.info("terminal scheme written to " + root.schemeFile)
            root.applySchemeToPanes()
        }
        onSaveFailed: {
            root.log.warn("could not write terminal scheme; the terminal will use a built-in QMLTermWidget scheme")
            root.applySchemeToPanes()
        }
    }

    function applySchemeToPanes() {
        const variants = presenterVariants.instances
        const count = variants ? variants.length : 0
        for (let i = 0; i < count; i++) {
            if (variants[i].pane)
                variants[i].pane.applyScheme()
        }
    }

    // The matugen-derived palette can take a few seconds after boot; retry
    // briefly then write whatever we have. Never blocks the terminal from
    // opening.
    property int _paletteRetries: 0

    Timer {
        id: paletteRetry
        interval: 500
        repeat: true
        running: true
        onTriggered: {
            if (Theme.dank16 && Theme.dank16.default) {
                stop()
                root.writeScheme()
                return
            }
            if (++root._paletteRetries >= 24) {
                stop()
                root.writeScheme()
            }
        }
    }
}
