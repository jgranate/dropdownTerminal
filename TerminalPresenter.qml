pragma ComponentBehavior: Bound
import QtQuick
import QMLTermWidget 2.0
import qs.Common
import qs.Services

// One slideout window plus one persistent terminal session per screen, the
// established DMS convention for per-screen surfaces (see the notepad).
//
// The QMLTermSession is owned here as a sibling of the slideout window, NOT
// inside the terminal pane, so that changing the slide edge, sizes, opacity or
// font never destroys the running shell. The shell is started lazily the first
// time the terminal is opened on this screen.
Item {
    id: root

    property var modelData: null
    property string slideEdge: "right"
    property bool defaultExpanded: false
    property int terminalOpacityPercent: 85
    property bool cursorBlink: false
    property string expandShortcut: "F11"
    property color cursorColor: "#ffcc66"
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

    readonly property var log: Log.scoped("dropdownTerminal")
    readonly property bool horizontalEdge: slideEdge === "left" || slideEdge === "right"

    QMLTermSession {
        id: session
        initialWorkingDirectory: "$HOME"
        kbScheme: "default"
    }

    property bool _openedOnce: false

    // Called on every reveal. Applies the default size only the first time the
    // terminal is opened; afterwards the user's per-session expanded state is
    // preserved across unrelated setting changes.
    function ensureOpened() {
        if (!root._openedOnce) {
            root._openedOnce = true
            slideout.expanded = root.defaultExpanded
            session.startShellProgram()
        }
    }

    SlideoutWindow {
        id: slideout
        modelData: root.modelData
        slideEdge: root.slideEdge
        smallSize: root.horizontalEdge ? root.smallWidth : root.smallHeight
        expandedSize: root.horizontalEdge ? root.expandedWidth : root.expandedHeight
        expandable: true
        customTransparency: 0.7
        title: root.showHeader ? I18n.tr("Terminal") : ""

        content: Component {
            TerminalPane {
                session: session
                terminalOpacity: root.terminalOpacityPercent / 100
                cursorBlink: root.cursorBlink
                expandShortcut: root.expandShortcut
                cursorColor: root.cursorColor
                escapeToClose: root.escapeToClose
                colorSchemeName: root.colorSchemeName
                fontFamily: root.fontFamily
                fontSize: root.fontSize
                copyOnSelect: root.copyOnSelect
                rightClickPaste: root.rightClickPaste

                onTerminalReady: pid => root.log.info("session started pid=" + pid)
                onExpandRequested: slideout.expanded = !slideout.expanded
                onCloseRequested: slideout.hide()
            }
        }

        onRevealed: {
            root.ensureOpened()
            // Restore terminal focus whenever the slideout opens.
            Qt.callLater(() => {
                if (slideout.isVisible)
                    slideout.loadedItem?.focusTerminal()
            })
        }
    }

    function toggle() {
        slideout.toggle()
    }

    function show() {
        slideout.show()
    }

    function hide() {
        slideout.hide()
    }

    readonly property bool isVisible: slideout.isVisible
    readonly property var pane: slideout.loadedItem
}
