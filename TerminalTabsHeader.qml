pragma ComponentBehavior: Bound
import QtCore
import QtQuick
import Quickshell
import qs.Common
import qs.Widgets

Item {
    id: root

    property var controller: null
    property int dragFrom: -1
    property int dragTo: -1

    function previewOffset(index, step) {
        if (dragFrom < 0 || dragTo < 0 || dragFrom === dragTo)
            return 0
        if (dragFrom < dragTo && index > dragFrom && index <= dragTo)
            return -step
        if (dragFrom > dragTo && index >= dragTo && index < dragFrom)
            return step
        return 0
    }

    function compactPath(path, fallback) {
        path = String(path || "")
        if (!path)
            return fallback
        const home = Paths.strip(StandardPaths.writableLocation(StandardPaths.HomeLocation).toString())
        if (path === home)
            return "~"
        if (home && path.indexOf(home + "/") === 0)
            return "~/" + path.slice(home.length + 1)
        return path
    }

    function directoryLabel(session, initialDir, fallback) {
        if (!session)
            return compactPath(initialDir, fallback)
        let path = String(session.currentDir || "")
        if (!path)
            path = initialDir
        return compactPath(path, fallback)
    }

    Timer {
        interval: 250
        repeat: true
        running: root.visible
        onTriggered: {
            for (let i = 0; i < tabRepeater.count; i++)
                tabRepeater.itemAt(i)?.refreshTitle()
        }
    }

    Flickable {
        id: tabFlick
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: addButton.left
        anchors.rightMargin: 6
        contentWidth: tabRow.width
        contentHeight: height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Row {
            id: tabRow
            width: tabFlick.width
            height: parent.height
            spacing: 2

            Repeater {
                id: tabRepeater
                model: root.controller ? root.controller.tabs : []

                Rectangle {
                    id: tab
                    required property int index
                    required property var modelData
                    readonly property bool selected: root.controller && root.controller.currentIndex === index
                    property string displayTitle: modelData.title
                    property real dragOffset: 0
                    property real visualOffset: tabDrag.active ? dragOffset : root.previewOffset(index, width + tabRow.spacing)

                    function refreshTitle() {
                        displayTitle = root.directoryLabel(modelData.session, modelData.initialDir, modelData.title)
                    }

                    width: root.controller ? Math.max(72, (tabRow.width - tabRow.spacing * Math.max(0, root.controller.tabs.length - 1)) / root.controller.tabs.length) : 112
                    height: 30
                    anchors.verticalCenter: parent.verticalCenter
                    radius: Theme.cornerRadius
                    color: selected ? Theme.surfaceContainerHighest : (tabHover.hovered ? Theme.surfaceContainerHigh : "transparent")
                    z: tabDrag.active ? 10 : 0

                    transform: Translate {
                        x: tab.visualOffset
                    }

                    Behavior on visualOffset {
                        enabled: !tabDrag.active
                        NumberAnimation {
                            duration: 120
                            easing.type: Easing.OutCubic
                        }
                    }

                    StyledText {
                        id: label
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.right: closeButton.left
                        anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        text: tab.displayTitle
                        color: Theme.surfaceText
                        font.pixelSize: Theme.fontSizeMedium
                        elide: Text.ElideMiddle
                    }

                    Rectangle {
                        id: closeButton
                        visible: root.controller && root.controller.tabs.length > 1
                        anchors.right: parent.right
                        anchors.rightMargin: 5
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20
                        height: 20
                        radius: 10
                        color: closeMouse.containsMouse ? Theme.withAlpha(Theme.error, 0.18) : "transparent"

                        StyledText {
                            anchors.centerIn: parent
                            text: "×"
                            color: closeMouse.containsMouse ? Theme.error : Theme.surfaceText
                            font.pixelSize: 16
                        }

                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: mouse => {
                                mouse.accepted = true
                                root.controller?.closeTab(tab.index)
                            }
                        }
                    }

                    HoverHandler {
                        id: tabHover
                    }

                    TapHandler {
                        id: tabTap
                        acceptedButtons: Qt.LeftButton
                        onTapped: {
                            if (root.controller) {
                                root.controller.currentIndex = tab.index
                                Qt.callLater(root.controller.focusTerminal)
                            }
                        }
                    }

                    DragHandler {
                        id: tabDrag
                        target: null
                        acceptedButtons: Qt.LeftButton
                        xAxis.enabled: true
                        yAxis.enabled: false
                        xAxis.minimum: -tab.index * (tab.width + tabRow.spacing)
                        xAxis.maximum: (root.controller ? root.controller.tabs.length - tab.index - 1 : 0) * (tab.width + tabRow.spacing)

                        onActiveChanged: {
                            if (active) {
                                if (root.controller) {
                                    root.controller.currentIndex = tab.index
                                    root.dragFrom = tab.index
                                    root.dragTo = tab.index
                                }
                            } else if (root.controller) {
                                const destination = root.dragTo
                                tab.dragOffset = 0
                                root.dragFrom = -1
                                root.dragTo = -1
                                root.controller.moveTab(tab.index, destination)
                            }
                        }

                        onTranslationChanged: {
                            tab.dragOffset = translation.x
                            if (active && root.controller) {
                                const step = tab.width + tabRow.spacing
                                root.dragTo = Math.max(0, Math.min(root.controller.tabs.length - 1, tab.index + Math.round(translation.x / step)))
                            }
                        }
                    }

                    Component.onCompleted: refreshTitle()
                }
            }
        }
    }

    Rectangle {
        id: addButton
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 30
        height: 30
        radius: Theme.cornerRadius
        color: addMouse.containsMouse ? Theme.surfaceContainerHighest : "transparent"

        StyledText {
            anchors.centerIn: parent
            text: "+"
            color: Theme.surfaceText
            font.pixelSize: 19
        }

        MouseArea {
            id: addMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.controller?.addTab(true)
        }
    }
}
