import QtCore
import QtQuick
import Quickshell
import Quickshell.Io
import QMLTermWidget 2.0
import qs.Common

// One persistent, non-tabbed Yazi session. The PTY is created once with this
// per-screen component and survives slideout hide/show cycles.
Item {
    id: root

    signal sessionStarted(int pid)
    signal expandRequested()
    signal closeRequested()

    property bool active: false
    property string yaziExecutable: "yazi"
    property string yaziConfigDir: ""
    property string previewKey: "default"
    property real terminalOpacity: 0.85
    property bool cursorBlink: false
    property string expandShortcut: "F11"
    property color cursorColor: "#ffcc66"
    property string colorSchemeName: "dankcolors"
    property string fontFamily: ""
    property int fontSize: 12
    property bool copyOnSelect: true
    property bool rightClickPaste: true
    property bool _started: false
    property string hoveredPath: ""
    property bool previewSuppressed: false

    readonly property bool terminalHasFocus: pane.termDisplay.activeFocus
    readonly property string previewDir: Paths.strip(StandardPaths.writableLocation(StandardPaths.GenericCacheLocation).toString()) + "/DankMaterialShell/dropdownTerminal"
    readonly property string previewFile: root.previewDir + "/yazi-hover-" + root.previewKey
    readonly property bool hoveredIsImage: /\.(avif|bmp|gif|heic|heif|ico|jpe?g|png|svg|tiff?|webp)$/i.test(root.hoveredPath)
    readonly property url previewSource: root.hoveredIsImage
                                         ? "file://" + root.hoveredPath.split("/").map(part => encodeURIComponent(part)).join("/")
                                         : ""

    QMLTermSession {
        id: session
        initialWorkingDirectory: "$HOME"
        kbScheme: "default"
        shellProgram: "/usr/bin/env"
        shellProgramArgs: [
            "YAZI_CONFIG_HOME=" + root.yaziConfigDir,
            "DMS_YAZI_PREVIEW_FILE=" + root.previewFile,
            root.yaziExecutable
        ]
        onFinished: console.info("dropdownTerminal.files: Yazi session finished")
    }

    TerminalPane {
        id: pane
        anchors.fill: parent
        session: session
        terminalOpacity: root.terminalOpacity
        cursorBlink: root.cursorBlink
        expandShortcut: root.expandShortcut
        cursorColor: root.cursorColor
        // Yazi needs Escape to leave search, filter, selection, and other
        // modal states. Hide Files mode with Mod+E or the header close button.
        escapeToClose: false
        forceCloseOnEscape: false
        trackYaziDeleteDialog: true
        colorSchemeName: root.colorSchemeName
        fontFamily: root.fontFamily
        fontSize: root.fontSize
        copyOnSelect: root.copyOnSelect
        rightClickPaste: root.rightClickPaste

        onTerminalReady: pid => root.sessionStarted(pid)
        onExpandRequested: root.expandRequested()
        onCloseRequested: root.closeRequested()
        // Yazi draws confirmation dialogs inside the terminal surface. Hide
        // the separate QML image layer while its delete dialog is active.
        onTerminalDialogOpened: {
            root.previewSuppressed = true
        }
        onTerminalDialogDismissed: {
            if (root.previewSuppressed)
                restorePreview.restart()
        }
    }

    // Yazi's terminal preview column remains underneath. For image files this
    // native pane occupies that same right-hand region; for every other file
    // it disappears and Yazi's normal text/metadata preview remains visible.
    Rectangle {
        id: imagePreview
        visible: root.hoveredIsImage && !root.previewSuppressed
        enabled: false
        z: 20
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: Math.max(220, parent.width * 0.37)
        color: Theme.surfaceContainer

        Image {
            id: previewImage
            anchors.fill: parent
            anchors.margins: Theme.spacingM
            source: root.previewSource
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            cache: false
            smooth: true
            mipmap: true
        }

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: 1
            border.color: Theme.outline
        }
    }

    FileView {
        id: hoverFile
        path: root.previewFile
        watchChanges: true
        printErrors: false
        onLoaded: root.hoveredPath = text().trim()
        onFileChanged: reload()
        onLoadFailed: root.hoveredPath = ""
    }

    Timer {
        id: restorePreview
        interval: 120
        repeat: false
        onTriggered: root.previewSuppressed = false
    }

    function ensureStarted() {
        if (root._started)
            return
        root._started = true
        Paths.mkdir(root.previewDir)
        if ("historySize" in session)
            session.historySize = 10000
        session.startShellProgram()
    }

    function focusTerminal() {
        pane.focusTerminal()
    }

    function applyScheme() {
        pane.applyScheme()
    }

    onActiveChanged: {
        if (active)
            ensureStarted()
    }

    Shortcut {
        sequence: "Ctrl+Shift+F"
        context: Qt.WindowShortcut
        onActivated: pane.toggleSearch()
    }

}
