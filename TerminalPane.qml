import QtQuick
import QMLTermWidget 2.0
import qs.Common

// The terminal presentation. Takes a shared QMLTermSession (owned by the
// per-screen presenter) and renders it with QMLTermWidget. Also owns the
// shortcuts, the deterministic refresh behaviour and the color-scheme
// fallback, so presentation changes never touch the session itself.
Item {
    id: root

    signal terminalReady(int pid)
    signal expandRequested()
    signal closeRequested()

    required property var session
    property real terminalOpacity: 0.85
    property bool cursorBlink: false
    property bool escapeToClose: true
    property string colorSchemeName: "dankcolors"
    property string fontFamily: ""
    property int fontSize: 12
    property bool copyOnSelect: true
    property bool rightClickPaste: true

    property alias termDisplay: term

    readonly property string effectiveFont: root.fontFamily ? root.fontFamily : Theme.defaultMonoFontFamily

    QMLTermWidget {
        id: term
        anchors.fill: parent
        focus: true

        font.family: root.effectiveFont
        font.pointSize: root.fontSize
        lineSpacing: 1
        antialiasText: true
        blinkingCursor: root.cursorBlink
        // The emulation reports its own cursor state after session startup and
        // may overwrite this QML property. Keep the explicit plugin preference
        // authoritative rather than silently reverting to the shell default.
        onBlinkingCursorChanged: {
            if (blinkingCursor !== root.cursorBlink)
                Qt.callLater(() => blinkingCursor = Qt.binding(() => root.cursorBlink))
        }
        colorScheme: root.colorSchemeName
        useFBORendering: false
        opacity: root.terminalOpacity

        session: root.session

        // Close with Escape only while the shell prompt is idle, so terminal
        // programs that use Escape (vim, less, ...) keep receiving it.
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape && root.escapeToClose && root.session && !root.session.hasActiveProcess) {
                event.accepted = true
                root.closeRequested()
            }
        }
    }

    // This QMLTermWidget build does not reliably emit copyAvailable when its
    // ScreenWindow selection changes. PointHandler observes the left pointer
    // passively, without stealing the drag from the terminal; copy after release
    // so copyClipboard() sees the finalized selection.
    PointHandler {
        id: selectionReleaseObserver
        enabled: root.copyOnSelect
        acceptedButtons: Qt.LeftButton
        onActiveChanged: {
            if (!active)
                copySelectionDebounce.restart()
        }
    }

    Timer {
        id: copySelectionDebounce
        interval: 30
        repeat: false
        onTriggered: {
            if (root.copyOnSelect)
                term.copyClipboard()
        }
    }

    Connections {
        target: root.session
        function onStarted() {
            root.terminalReady(root.session.getShellPID())
        }
    }

    // A right-button-only overlay leaves selection, wheel scrolling and normal
    // left-button terminal interaction to QMLTermWidget.
    MouseArea {
        anchors.fill: parent
        enabled: root.rightClickPaste
        acceptedButtons: Qt.RightButton
        onClicked: mouse => {
            term.pasteClipboard()
            term.forceActiveFocus()
            mouse.accepted = true
        }
    }

    // Deterministic lifecycle refresh: repaint once after the window becomes
    // visible (hide/show, remap) and once after geometry settles (resize,
    // expand, edge change). QMLTermWidget with an Image render target can keep
    // a stale image across those transitions, so we fetch the screen image and
    // force a repaint. This replaces the previous double callLater + fixed
    // 600 ms timer.
    Connections {
        target: term.Window.window
        function onVisibleChanged() {
            if (term.Window.window && term.Window.window.visible)
                root.refresh()
        }
    }

    Timer {
        id: refreshDebounce
        interval: 80
        repeat: false
        onTriggered: root.refresh()
    }
    onWidthChanged: refreshDebounce.restart()
    onHeightChanged: refreshDebounce.restart()

    function focusTerminal() {
        term.forceActiveFocus()
    }

    // QMLTermWidget resolves scheme files lazily, so if the scheme file is
    // written after this pane was created the property must be assigned again.
    // Falls back to schemes that ship with QMLTermWidget when the configured
    // scheme is unavailable.
    function applyScheme() {
        if (!term)
            return
        const candidates = [root.colorSchemeName, "Linux", "Falcon"]
        for (const name of candidates) {
            term.colorScheme = name
            if (term.colorScheme === name) {
                if (name !== root.colorSchemeName)
                    console.warn("dropdownTerminal: color scheme '" + root.colorSchemeName + "' is unavailable, using '" + name + "'")
                return
            }
        }
        console.warn("dropdownTerminal: no usable QMLTermWidget color scheme found")
    }

    function refresh() {
        if (!term || !term.session)
            return
        Qt.callLater(() => {
            term.updateImage()
            term.update()
        })
    }

    // Preserve Ctrl+Shift+C / Ctrl+Shift+V. Both the original Ctrl+T binding
    // and F11 toggle the slideout size.
    // WindowShortcut context keeps these from firing while the terminal is
    // hidden or another window is focused.
    Shortcut {
        sequence: "Ctrl+Shift+C"
        context: Qt.WindowShortcut
        onActivated: term.copyClipboard()
    }

    Shortcut {
        sequence: "Ctrl+Shift+V"
        context: Qt.WindowShortcut
        onActivated: term.pasteClipboard()
    }

    Shortcut {
        sequence: "F11"
        context: Qt.WindowShortcut
        onActivated: root.expandRequested()
    }

    Shortcut {
        sequence: "Ctrl+T"
        context: Qt.WindowShortcut
        onActivated: root.expandRequested()
    }

    Component.onCompleted: {
        root.applyScheme()
        term.forceActiveFocus()
    }
}
