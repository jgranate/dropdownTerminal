pragma ComponentBehavior: Bound
import QtCore
import QtQuick
import Quickshell
import QMLTermWidget 2.0
import qs.Common

Item {
    id: root

    signal expandRequested()
    signal closeRequested()
    signal sessionStarted(int pid)

    property bool active: false
    property string slideEdge: "right"
    property real terminalOpacity: 0.85
    property bool cursorBlink: false
    property string expandShortcut: "F11"
    property color cursorColor: "#ffcc66"
    property bool escapeToClose: true
    property string colorSchemeName: "dankcolors"
    property string fontFamily: ""
    property int fontSize: 12
    property bool copyOnSelect: true
    property bool rightClickPaste: true

    property var tabs: []
    property int currentIndex: -1
    property int nextTabNumber: 1
    property bool helpVisible: false

    Component {
        id: sessionFactory
        QMLTermSession {
            initialWorkingDirectory: "$HOME"
            kbScheme: "default"
        }
    }

    Component {
        id: paneFactory
        TerminalPane {
            anchors.fill: parent
            visible: false
            enabled: visible
            terminalOpacity: root.terminalOpacity
            cursorBlink: root.cursorBlink
            expandShortcut: root.expandShortcut
            cursorColor: root.cursorColor
            escapeToClose: root.escapeToClose
            colorSchemeName: root.colorSchemeName
            fontFamily: root.fontFamily
            fontSize: root.fontSize
            copyOnSelect: root.copyOnSelect
            rightClickPaste: root.rightClickPaste

            onTerminalReady: pid => root.sessionStarted(pid)
            onExpandRequested: root.expandRequested()
            onCloseRequested: root.closeRequested()
        }
    }

    function addTab(startNow = true) {
        if (tabs.length >= 9)
            return
        const number = nextTabNumber++
        const activeSession = currentIndex >= 0 && currentIndex < tabs.length ? tabs[currentIndex].session : null
        const initialDir = activeSession && activeSession.currentDir
                           ? String(activeSession.currentDir)
                           : Paths.strip(StandardPaths.writableLocation(StandardPaths.HomeLocation).toString())
        const session = sessionFactory.createObject(root)
        if (!session)
            return
        session.initialWorkingDirectory = initialDir
        if ("historySize" in session)
            session.historySize = 10000
        const pane = paneFactory.createObject(paneStack, { session: session })
        if (!pane) {
            session.destroy()
            return
        }
        tabs = tabs.concat([{ number: number, title: I18n.tr("Terminal") + " " + number, initialDir: initialDir, session: session, pane: pane }])
        currentIndex = tabs.length - 1
        if (startNow)
            session.startShellProgram()
        Qt.callLater(root.focusTerminal)
    }

    function closeTab(index) {
        if (index < 0 || index >= tabs.length || tabs.length === 1)
            return
        const closing = tabs[index]
        const remaining = tabs.slice()
        remaining.splice(index, 1)
        tabs = remaining
        currentIndex = Math.min(index, remaining.length - 1)
        Qt.callLater(() => {
            closing.pane.destroy()
            closing.session.destroy()
            root.focusTerminal()
        })
    }

    function nextTab() {
        if (tabs.length > 1) {
            currentIndex = (currentIndex + 1) % tabs.length
            Qt.callLater(root.focusTerminal)
        }
    }

    function moveTab(fromIndex, toIndex) {
        if (fromIndex < 0 || fromIndex >= tabs.length || toIndex < 0 || toIndex >= tabs.length || fromIndex === toIndex)
            return
        const activeTab = currentIndex >= 0 && currentIndex < tabs.length ? tabs[currentIndex] : null
        const reordered = tabs.slice()
        const moved = reordered.splice(fromIndex, 1)[0]
        reordered.splice(toIndex, 0, moved)
        tabs = reordered
        currentIndex = activeTab ? reordered.indexOf(activeTab) : Math.min(toIndex, reordered.length - 1)
        Qt.callLater(root.focusTerminal)
    }

    function moveCurrentTab(delta) {
        if (currentIndex < 0)
            return
        moveTab(currentIndex, Math.max(0, Math.min(tabs.length - 1, currentIndex + delta)))
    }

    function ensureStarted() {
        if (tabs.length === 0)
            addTab(true)
    }

    function focusTerminal() {
        const pane = currentIndex >= 0 && currentIndex < tabs.length ? tabs[currentIndex].pane : null
        if (pane)
            pane.focusTerminal()
    }

    function toggleHelp() {
        helpVisible = !helpVisible
        if (helpVisible)
            Qt.callLater(helpOverlay.forceActiveFocus)
        else
            Qt.callLater(root.focusTerminal)
    }

    function applyScheme() {
        for (let i = 0; i < tabs.length; i++)
            tabs[i].pane?.applyScheme()
    }

    function updatePaneVisibility() {
        for (let i = 0; i < tabs.length; i++) {
            const active = i === currentIndex
            tabs[i].pane.visible = active
            tabs[i].pane.enabled = active
            if (active)
                tabs[i].pane.refresh()
        }
    }

    onCurrentIndexChanged: updatePaneVisibility()
    onTabsChanged: updatePaneVisibility()
    onActiveChanged: {
        if (active)
            ensureStarted()
    }

    Item {
        id: paneStack
        anchors.fill: parent
    }

    TerminalHelpOverlay {
        id: helpOverlay
        anchors.fill: parent
        z: 100
        visible: root.helpVisible
        enabled: visible
        expandShortcut: root.expandShortcut
        onCloseRequested: {
            root.helpVisible = false
            Qt.callLater(root.focusTerminal)
        }
    }

    Shortcut {
        sequence: "Ctrl+Shift+/"
        context: Qt.WindowShortcut
        onActivated: root.toggleHelp()
    }

    Shortcut {
        sequence: "Ctrl+Shift+F"
        context: Qt.WindowShortcut
        onActivated: {
            const pane = root.currentIndex >= 0 && root.currentIndex < root.tabs.length
                         ? root.tabs[root.currentIndex].pane : null
            pane?.toggleSearch()
        }
    }

    Shortcut {
        sequence: "Ctrl+Shift+T"
        context: Qt.WindowShortcut
        onActivated: root.addTab(true)
    }

    Shortcut {
        sequence: "Ctrl+Shift+W"
        context: Qt.WindowShortcut
        onActivated: root.closeTab(root.currentIndex)
    }

    Shortcut {
        sequence: "Ctrl+Tab"
        context: Qt.WindowShortcut
        onActivated: root.nextTab()
    }

    Shortcut {
        sequence: "Ctrl+Shift+PgUp"
        context: Qt.WindowShortcut
        onActivated: root.moveCurrentTab(-1)
    }

    Shortcut {
        sequence: "Ctrl+Shift+PgDown"
        context: Qt.WindowShortcut
        onActivated: root.moveCurrentTab(1)
    }

    Component.onCompleted: {
        if (active)
            ensureStarted()
    }
}
