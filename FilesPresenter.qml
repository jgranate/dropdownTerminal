pragma ComponentBehavior: Bound
import QtQuick
import qs.Common
import qs.Services

// Dedicated files slideout for one screen. Its FilesTerminal owns exactly one
// QMLTermSession and deliberately has no terminal-tab controller or header.
Item {
    id: root

    property var modelData: null
    property string slideEdge: "right"
    property string yaziExecutable: "yazi"
    property string yaziConfigDir: ""
    property int terminalOpacityPercent: 85
    property bool cursorBlink: false
    property string expandShortcut: "F11"
    property color cursorColor: "#ffcc66"
    property string colorSchemeName: "dankcolors"
    property string fontFamily: ""
    property int fontSize: 12
    property int smallWidth: 520
    property int expandedWidth: 900
    property int smallHeight: 480
    property int expandedHeight: 760
    property bool copyOnSelect: true
    property bool rightClickPaste: true
    property bool _openedOnce: false

    readonly property var log: Log.scoped("dropdownTerminal.files")
    readonly property bool horizontalEdge: slideEdge === "left" || slideEdge === "right"

    function ensureOpened() {
        if (!root._openedOnce) {
            root._openedOnce = true
            slideout.expanded = true
        }
        slideout.loadedItem?.ensureStarted()
    }

    SlideoutWindow {
        id: slideout
        modelData: root.modelData
        slideEdge: root.slideEdge
        smallSize: root.horizontalEdge ? root.smallWidth : root.smallHeight
        expandedSize: root.horizontalEdge ? root.expandedWidth : root.expandedHeight
        expandable: true
        expanded: true
        customTransparency: 0.7
        title: I18n.tr("Files")
        headerVisible: true

        content: Component {
            FilesTerminal {
                active: slideout.isVisible
                yaziExecutable: root.yaziExecutable
                yaziConfigDir: root.yaziConfigDir
                previewKey: root.modelData && root.modelData.name ? String(root.modelData.name).replace(/[^A-Za-z0-9_-]/g, "_") : "default"
                terminalOpacity: root.terminalOpacityPercent / 100
                cursorBlink: root.cursorBlink
                expandShortcut: root.expandShortcut
                cursorColor: root.cursorColor
                colorSchemeName: root.colorSchemeName
                fontFamily: root.fontFamily
                fontSize: root.fontSize
                copyOnSelect: root.copyOnSelect
                rightClickPaste: root.rightClickPaste

                onSessionStarted: pid => root.log.info("Yazi session started pid=" + pid)
                onExpandRequested: slideout.expanded = !slideout.expanded
                onCloseRequested: slideout.hide()
            }
        }

        onRevealed: {
            root.ensureOpened()
            Qt.callLater(() => {
                if (slideout.isVisible)
                    slideout.loadedItem?.focusTerminal()
            })
        }

        onContentLoaded: {
            if (root._openedOnce || slideout.isVisible)
                root.ensureOpened()
        }
    }

    function show() { slideout.show() }
    function hide() { slideout.hide() }
    readonly property bool isVisible: slideout.isVisible
    readonly property var pane: slideout.loadedItem
}
