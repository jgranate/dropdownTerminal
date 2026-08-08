pragma ComponentBehavior: Bound
import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: root

    signal closeRequested()

    property string expandShortcut: "F11"

    readonly property var shortcuts: [
        { keys: "Ctrl+Shift+T", action: I18n.tr("New tab") },
        { keys: "Ctrl+Shift+W", action: I18n.tr("Close tab") },
        { keys: "Ctrl+Tab", action: I18n.tr("Next tab") },
        { keys: "Ctrl+Shift+PgUp / PgDown", action: I18n.tr("Reorder tab") },
        { keys: "Ctrl+Shift+F", action: I18n.tr("Search scrollback") },
        { keys: "Ctrl+Shift+C / V", action: I18n.tr("Copy / paste") },
        { keys: root.expandShortcut + " / Ctrl+T", action: I18n.tr("Resize terminal") },
        { keys: "Escape", action: I18n.tr("Hide at an idle prompt") },
        { keys: "Ctrl+Shift+?", action: I18n.tr("Toggle this help") }
    ]

    focus: visible
    Keys.onEscapePressed: event => {
        event.accepted = true
        root.closeRequested()
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.withAlpha(Theme.surface, 0.72)

        MouseArea {
            anchors.fill: parent
            onClicked: root.closeRequested()
        }
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(parent.width - 32, 520)
        height: Math.min(parent.height - 32, contentColumn.implicitHeight + 36)
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh
        border.width: 1
        border.color: Theme.outline

        MouseArea {
            anchors.fill: parent
            onClicked: mouse => mouse.accepted = true
        }

        Column {
            id: contentColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 18
            spacing: 12

            Item {
                width: parent.width
                height: 30

                StyledText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.tr("Terminal shortcuts")
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.DemiBold
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28
                    height: 28
                    radius: 14
                    color: closeMouse.containsMouse ? Theme.surfaceContainerHighest : "transparent"

                    StyledText {
                        anchors.centerIn: parent
                        text: "×"
                        color: Theme.surfaceText
                        font.pixelSize: 18
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.closeRequested()
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.outline
            }

            Repeater {
                model: root.shortcuts

                Row {
                    required property var modelData
                    width: contentColumn.width
                    spacing: 16

                    StyledText {
                        width: Math.min(210, parent.width * 0.48)
                        text: modelData.keys
                        color: Theme.primary
                        font.pixelSize: Theme.fontSizeMedium
                        font.family: Theme.monoFontFamily
                    }

                    StyledText {
                        width: parent.width - x
                        text: modelData.action
                        color: Theme.surfaceText
                        font.pixelSize: Theme.fontSizeMedium
                    }
                }
            }

            StyledText {
                width: parent.width
                text: I18n.tr("The show/hide shortcut is configured in your compositor.")
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.WordWrap
            }
        }
    }
}
