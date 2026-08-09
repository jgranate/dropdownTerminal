import QtQuick
import QMLTermWidget 2.0
import qs.Common
import qs.Widgets

// The terminal presentation. Takes a shared QMLTermSession (owned by the
// per-screen presenter) and renders it with QMLTermWidget. Also owns the
// shortcuts, the deterministic refresh behaviour and the color-scheme
// fallback, so presentation changes never touch the session itself.
Item {
    id: root

    signal terminalReady(int pid)
    signal expandRequested()
    signal closeRequested()
    signal outputReceived()
    signal terminalDialogOpened()
    signal terminalDialogDismissed()

    required property var session
    property real terminalOpacity: 0.85
    property bool cursorBlink: false
    property string expandShortcut: "F11"
    property color cursorColor: "#ffcc66"
    property bool escapeToClose: true
    property bool forceCloseOnEscape: false
    property bool trackYaziDeleteDialog: false
    property string colorSchemeName: "dankcolors"
    property string fontFamily: ""
    property int fontSize: 12
    property bool copyOnSelect: true
    property bool rightClickPaste: true
    property bool unreadActivity: false
    property bool searchVisible: false
    property int searchLine: 0
    property int searchColumn: 0
    property bool searchBackwards: false
    property bool hasSearchMatch: false
    property int matchStartLine: 0
    property int matchStartColumn: 0
    property int matchEndLine: 0
    property int matchEndColumn: 0

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
        session: root.session

        Keys.onShortcutOverride: event => {
            if ((event.key === Qt.Key_Escape && root.forceCloseOnEscape)
                    || (root.trackYaziDeleteDialog
                        && (event.key === Qt.Key_D || event.key === Qt.Key_Y
                            || event.key === Qt.Key_N || event.key === Qt.Key_Escape
                            || event.key === Qt.Key_Return || event.key === Qt.Key_Enter)))
                event.accepted = true
        }

        // Close with Escape only while the shell prompt is idle, so terminal
        // programs that use Escape (vim, less, ...) keep receiving it.
        Keys.onPressed: (event) => {
            if (root.trackYaziDeleteDialog) {
                if (event.key === Qt.Key_D)
                    root.terminalDialogOpened()
                else if (event.key === Qt.Key_Y || event.key === Qt.Key_N
                         || event.key === Qt.Key_Escape
                         || event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                    root.terminalDialogDismissed()
                // Do not accept these events: Yazi must still receive them.
            }
            if (event.key === Qt.Key_F
                    && (event.modifiers & Qt.ControlModifier)
                    && (event.modifiers & Qt.ShiftModifier)) {
                event.accepted = true
                root.toggleSearch()
                return
            }
            if (event.key === Qt.Key_Escape
                    && root.escapeToClose
                    && root.session
                    && (root.forceCloseOnEscape || !root.session.hasActiveProcess)) {
                event.accepted = true
                root.closeRequested()
            }
        }
    }

    // QMLTermWidget emits isBusySelecting from its native mouse handlers. Use
    // that instead of a sibling PointerHandler: the painted terminal consumes
    // the pointer interaction, so passive QML handlers do not reliably observe
    // the release. Copy one event-loop turn after the native selection ends so
    // copyClipboard() sees the finalized ScreenWindow selection.
    Connections {
        target: term
        // Full-screen terminal applications can consume Escape before the
        // attached Keys handler. QMLTermWidget emits this native signal from
        // its internal key path, so Files mode can still hide reliably.
        function onTermKeyPressed(event) {
            if (root.forceCloseOnEscape && event && event.key === Qt.Key_Escape)
                root.closeRequested()
        }
        function onIsBusySelecting(busy) {
            if (!busy && root.copyOnSelect)
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
        function onReceivedData(text) {
            if (!root.visible)
                root.unreadActivity = true
            root.outputReceived()
        }
        function onMatchFound(startColumn, startLine, endColumn, endLine) {
            term.revealSearchMatch(startColumn, startLine, endColumn, endLine)
            root.hasSearchMatch = true
            root.matchStartLine = startLine
            root.matchStartColumn = startColumn
            root.matchEndLine = endLine
            root.matchEndColumn = endColumn
            searchStatus.text = ""
        }
        function onNoMatchFound() {
            searchStatus.text = I18n.tr("No match")
        }
    }

    Rectangle {
        id: searchBar
        visible: root.searchVisible
        z: 20
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 8
        anchors.rightMargin: 10
        width: Math.min(430, parent.width - 20)
        height: 38
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHighest

        TextInput {
            id: searchInput
            anchors.left: parent.left
            anchors.right: searchStatus.left
            anchors.leftMargin: 12
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.surfaceText
            selectionColor: Theme.primary
            selectedTextColor: Theme.onPrimary
            font.family: root.effectiveFont
            font.pixelSize: Theme.fontSizeMedium
            clip: true
            focus: root.searchVisible

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    root.closeSearch()
                    event.accepted = true
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.findNext(Boolean(event.modifiers & Qt.ShiftModifier))
                    event.accepted = true
                }
            }
            onTextChanged: {
                root.searchLine = 0
                root.searchColumn = 0
                root.hasSearchMatch = false
                searchStatus.text = ""
                if (text)
                    searchDebounce.restart()
            }
        }

        StyledText {
            id: searchStatus
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: ""
            color: Theme.error
            font.pixelSize: Theme.fontSizeSmall
        }
    }

    Timer {
        id: searchDebounce
        interval: 120
        repeat: false
        onTriggered: root.findNext(false)
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
    onVisibleChanged: {
        if (visible) {
            unreadActivity = false
            refreshDebounce.restart()
            Qt.callLater(term.forceActiveFocus)
        }
    }

    function focusTerminal() {
        term.forceActiveFocus()
    }

    function openSearch() {
        searchVisible = true
        searchLine = 0
        searchColumn = 0
        Qt.callLater(() => {
            searchInput.forceActiveFocus()
            searchInput.selectAll()
        })
    }

    function toggleSearch() {
        if (searchVisible)
            closeSearch()
        else
            openSearch()
    }

    function closeSearch() {
        searchVisible = false
        searchStatus.text = ""
        term.forceActiveFocus()
    }

    function findNext(backwards) {
        if (!searchInput.text)
            return
        searchBackwards = backwards
        if (hasSearchMatch) {
            if (backwards) {
                searchLine = matchStartLine
                searchColumn = Math.max(0, matchStartColumn - 1)
                if (matchStartColumn === 0) {
                    searchLine = Math.max(0, matchStartLine - 1)
                    searchColumn = 2147483647
                }
            } else {
                searchLine = matchEndLine
                searchColumn = matchEndColumn + 1
            }
        } else if (backwards) {
            searchLine = 2147483647
            searchColumn = 2147483647
        } else {
            searchLine = 0
            searchColumn = 0
        }
        root.session.search(searchInput.text, searchLine, searchColumn, !backwards)
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

    // These properties are supplied by the downstream qmltermwidget patch in
    // patches/. Dynamic assignment keeps the plugin usable with the stock
    // package: stock builds retain the old whole-widget opacity as a fallback.
    function applyPatchedAppearance() {
        if ("backgroundOpacity" in term) {
            term.opacity = 1
            term.backgroundOpacity = root.terminalOpacity
        } else {
            term.opacity = root.terminalOpacity
        }

        if ("cursorColor" in term)
            term.cursorColor = root.cursorColor
    }

    onTerminalOpacityChanged: root.applyPatchedAppearance()
    onCursorColorChanged: root.applyPatchedAppearance()

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
        sequence: root.expandShortcut
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
        root.applyPatchedAppearance()
        term.forceActiveFocus()
    }
}
