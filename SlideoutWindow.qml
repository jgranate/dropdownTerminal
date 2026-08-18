pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets

// Unified slideout panel for DMS: a layer-shell PanelWindow that animates in
// and out along any screen edge (left/right/top/bottom). This is a single
// component derived from the horizontal `DankSlideout` and the previous
// vertical copy, generalized over the slide axis so horizontal and vertical
// configuration is not duplicated.
PanelWindow {
    id: root

    property string layerNamespace: "dms:slideout"
    WlrLayershell.namespace: layerNamespace

    // --- DMS slideout interface ---
    property bool isVisible: false
    property var modelData: null
    property bool triggerUsesOverlayLayer: false
    property bool suppressOverlayLayer: false
    property string slideEdge: "right"
    // Slideout dimension in logical units (width for left/right edges,
    // height for top/bottom). Always clamped against the screen below.
    property real smallSize: 480
    property real expandedSize: 960
    property real minimumSize: 300
    property real edgeGap: 0
    property bool expandable: false
    property bool expanded: false
    property Component content: null
    // Content may expose a focus boolean under a custom name. The terminal
    // keeps the historical default; other slideouts can opt in without
    // pretending to be terminal widgets.
    property string focusProperty: "terminalHasFocus"
    property bool drawContentBorder: true
    property bool drawContentBackground: true
    property Component headerContent: null
    property string title: ""
    property bool headerVisible: title !== ""
    property alias container: contentContainer
    property alias loadedItem: contentLoader.item
    property real customTransparency: -1
    signal aboutToHide
    signal revealed
    signal contentLoaded

    // --- edge helpers ---
    readonly property bool horizontalEdge: slideEdge === "left" || slideEdge === "right"
    readonly property bool verticalEdge: !horizontalEdge
    readonly property bool slideFromLeft: slideEdge === "left"
    readonly property bool slideFromTop: slideEdge === "top"

    readonly property real screenW: modelData ? modelData.width : 1280
    readonly property real screenH: modelData ? modelData.height : 800
    // Available space along the slide axis; used to clamp the panel size so
    // small/expanded modes stay sensible on low-resolution and scaled outputs.
    readonly property real availableSpan: horizontalEdge ? screenW : screenH

    readonly property real dpr: CompositorService.getScreenScale(root.screen)
    readonly property real smallSpan: Math.max(root.minimumSize, Math.min(root.smallSize, availableSpan * 0.5))
    readonly property real expandedSpan: Math.max(smallSpan, Math.min(root.expandedSize, availableSpan * 0.8))
    readonly property real alignedSpan: Theme.px(root.expanded ? expandedSpan : smallSpan, dpr)
    readonly property real alignedEdgeGap: Theme.px(edgeGap, dpr)
    readonly property real slideoutSlideSnapX: Theme.snap(slideContainer.slideOffset, dpr)
    readonly property real slideoutSlideSnapY: Theme.snap(slideContainer.slideOffset, dpr)

    // --- window configuration ---
    visible: root.mappedVisible
    screen: modelData

    anchors.top: root.horizontalEdge ? true : root.slideFromTop
    anchors.bottom: root.horizontalEdge ? true : !root.slideFromTop
    anchors.left: root.verticalEdge ? true : root.slideFromLeft
    anchors.right: root.verticalEdge ? true : !root.slideFromLeft

    // Keep the layer-shell surface at its maximum span while the visible panel
    // resizes inside its input mask. Resizing the Wayland surface itself before
    // the inner height animation completes causes a conspicuous clip/stutter,
    // especially when a top-edge panel contracts from expanded to small.
    implicitWidth: root.horizontalEdge ? Theme.px(root.expandedSpan, dpr) : screenW
    implicitHeight: root.horizontalEdge ? screenH : Theme.px(root.expandedSpan, dpr)

    color: "transparent"

    readonly property bool slideoutBlurActive: root.visible && BlurService.enabled && Theme.connectedSurfaceBlurEnabled

    WlrLayershell.layer: (!suppressOverlayLayer && (triggerUsesOverlayLayer || CompositorService.framePeerSurfacesUseOverlayForScreen(modelData))) ? WlrLayershell.Overlay : WlrLayershell.Top
    WlrLayershell.exclusiveZone: 0
    // OnDemand lets normal windows take focus later. Explicitly request window
    // activation in show() so opening from a compositor keybind still focuses
    // the terminal without requiring a click.
    WlrLayershell.keyboardFocus: isVisible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // --- show / hide with rapid-toggle protection ---
    property bool mappedVisible: false
    property bool _showPending: false

    function show() {
        root.mappedVisible = true
        root._showPending = true
        Qt.callLater(() => {
            if (root._showPending) {
                root.isVisible = true
                root.requestActivate()
                root.revealed()
            } else {
                // A hide() superseded this show before the deferred call ran.
                root.mappedVisible = false
            }
            root._showPending = false
        })
    }

    function hide() {
        root.aboutToHide()
        root._showPending = false
        root.isVisible = false
    }

    function toggle() {
        if (root.isVisible)
            root.hide()
        else
            root.show()
    }

    mask: Region {
        item: Rectangle {
            x: root.horizontalEdge ? (root.slideFromLeft ? root.alignedEdgeGap : (root.width - slideContainer.width - root.alignedEdgeGap)) : root.alignedEdgeGap
            y: root.verticalEdge ? (root.slideFromTop ? root.alignedEdgeGap : (root.height - slideContainer.height - root.alignedEdgeGap)) : root.alignedEdgeGap
            width: root.horizontalEdge ? slideContainer.width : (root.width - root.alignedEdgeGap * 2)
            height: root.verticalEdge ? slideContainer.height : (root.height - root.alignedEdgeGap * 2)
        }
    }

    Item {
        id: slideContainer
        anchors.top: root.horizontalEdge ? parent.top : (root.slideFromTop ? parent.top : undefined)
        anchors.bottom: root.horizontalEdge ? parent.bottom : (root.slideFromTop ? undefined : parent.bottom)
        anchors.left: root.verticalEdge ? parent.left : (root.slideFromLeft ? parent.left : undefined)
        anchors.right: root.verticalEdge ? parent.right : (root.slideFromLeft ? undefined : parent.right)
        anchors.topMargin: root.alignedEdgeGap
        anchors.bottomMargin: root.alignedEdgeGap
        anchors.leftMargin: root.alignedEdgeGap
        anchors.rightMargin: root.alignedEdgeGap
        width: root.horizontalEdge ? root.alignedSpan : (root.width - root.alignedEdgeGap * 2)
        height: root.horizontalEdge ? (root.height - root.alignedEdgeGap * 2) : root.alignedSpan

        property real slideOffset: root.horizontalEdge ? (root.slideFromLeft ? -root.alignedSpan : root.alignedSpan) : (root.slideFromTop ? -root.alignedSpan : root.alignedSpan)

        Connections {
            target: root
            function onIsVisibleChanged() {
                slideContainer.slideOffset = root.isVisible ? 0 : (root.horizontalEdge ? (root.slideFromLeft ? -slideContainer.width : slideContainer.width) : (root.slideFromTop ? -slideContainer.height : slideContainer.height))
            }
        }

        Behavior on slideOffset {
            NumberAnimation {
                id: slideAnimation
                duration: 450
                easing.type: Easing.OutCubic

                onRunningChanged: {
                    if (!running && !root.isVisible)
                        root.mappedVisible = false
                }
            }
        }

        Behavior on width {
            enabled: root.horizontalEdge && root.expandable
            NumberAnimation {
                duration: Theme.popoutAnimationDuration
                easing.type: Easing.OutCubic
            }
        }

        Behavior on height {
            enabled: root.verticalEdge && root.expandable
            NumberAnimation {
                duration: Theme.popoutAnimationDuration
                easing.type: Easing.OutCubic
            }
        }

        Item {
            id: contentRect
            layer.enabled: Quickshell.env("DMS_DISABLE_LAYER") !== "true" && Quickshell.env("DMS_DISABLE_LAYER") !== "1"
            layer.smooth: false
            layer.textureSize: Qt.size(0, 0)
            opacity: 1

            readonly property color slideoutSurfaceColor: root.drawContentBackground ? (root.customTransparency >= 0 ? Theme.withAlpha(Theme.surfaceContainer, root.customTransparency) : Theme.popupLayerColor(Theme.surfaceContainer)) : "transparent"
            // Keep the painted surface just inside the layer-shell window. A
            // surface flush with the window boundary loses its final border
            // pixel to clipping, most visibly along the bottom of a top panel.
            readonly property real surfaceInset: Math.max(1, BlurService.borderWidth)

            width: Math.max(0, parent.width - surfaceInset * 2)
            height: Math.max(0, parent.height - surfaceInset * 2)
            x: surfaceInset + (root.horizontalEdge ? root.slideoutSlideSnapX : 0)
            y: surfaceInset + (root.verticalEdge ? root.slideoutSlideSnapY : 0)

            Rectangle {
                anchors.fill: parent
                color: contentRect.slideoutSurfaceColor
                radius: Theme.connectedSurfaceRadius
                // Layer-shell QWindow.active is not reliable under Niri. The
                // terminal view's activeFocus tracks actual keyboard focus.
                readonly property bool contentFocused: root.loadedItem && root.loadedItem[root.focusProperty] === true
                border.color: root.drawContentBorder && contentFocused ? Theme.primary : (Theme.isConnectedEffect ? Theme.withAlpha(BlurService.borderColor, 0) : BlurService.borderColor)
                border.width: root.drawContentBorder ? (contentFocused ? Theme.px(2, root.dpr) : (Theme.isConnectedEffect ? 0 : BlurService.borderWidth)) : 0
            }

            Column {
                id: headerColumn
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Theme.spacingL
                spacing: Theme.spacingM
                visible: root.headerVisible

                Row {
                    width: parent.width
                    height: 32

                    Column {
                        visible: root.headerContent === null
                        width: parent.width - buttonRow.width
                        spacing: Theme.spacingXS
                        anchors.verticalCenter: parent.verticalCenter

                        StyledText {
                            text: root.title
                            font.pixelSize: Theme.fontSizeLarge
                            color: Theme.surfaceText
                            font.weight: Font.Medium
                        }
                    }

                    Loader {
                        id: headerContentLoader
                        visible: root.headerContent !== null
                        width: parent.width - buttonRow.width
                        height: parent.height
                        sourceComponent: root.headerContent
                    }

                    Row {
                        id: buttonRow
                        spacing: Theme.spacingXS

                        DankActionButton {
                            id: expandButton
                            iconName: root.expanded ? "unfold_less" : "unfold_more"
                            iconSize: Theme.iconSize - 4
                            iconColor: Theme.surfaceText
                            visible: root.expandable
                            onClicked: root.expanded = !root.expanded
                        }

                        DankActionButton {
                            id: closeButton
                            iconName: "close"
                            iconSize: Theme.iconSize - 4
                            iconColor: Theme.surfaceText
                            onClicked: root.hide()
                        }
                    }
                }
            }

            Item {
                id: contentContainer
                anchors.top: root.headerVisible ? headerColumn.bottom : parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.topMargin: root.headerVisible ? 0 : Theme.spacingL
                anchors.leftMargin: Theme.spacingL
                anchors.rightMargin: Theme.spacingL
                anchors.bottomMargin: Theme.spacingL

                Loader {
                    id: contentLoader
                    anchors.fill: parent
                    sourceComponent: root.content
                    onLoaded: root.contentLoaded()
                }
            }
        }
    }

    WindowBlur {
        targetWindow: root
        blurX: root.slideoutBlurActive ? slideContainer.x + contentRect.x : 0
        blurY: root.slideoutBlurActive ? slideContainer.y + contentRect.y : 0
        blurWidth: root.slideoutBlurActive ? contentRect.width : 0
        blurHeight: root.slideoutBlurActive ? contentRect.height : 0
        blurRadius: Theme.connectedSurfaceRadius
    }
}
