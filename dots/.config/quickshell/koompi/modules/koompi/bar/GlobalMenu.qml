pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: root

    readonly property string daemonBin: {
        const url = Qt.resolvedUrl("../../../scripts/global-menu/zig-out/bin/global-menu-daemon")
        return url.toString().replace("file://", "")
    }

    property var menuItems: []
    property int openIdx: -1

    implicitWidth: itemRow.implicitWidth

    Process {
        id: daemon
        command: [root.daemonBin]
        running: true
        stdout: SplitParser {
            onRead: (line) => {
                try {
                    const d = JSON.parse(line)
                    root.menuItems = d.items ?? []
                } catch (e) {
                    root.menuItems = []
                }
            }
        }
        onRunningChanged: if (!running) restartTimer.start()
    }

    Timer {
        id: restartTimer
        interval: 3000
        onTriggered: daemon.running = true
    }

    Row {
        id: itemRow
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        Repeater {
            id: menuRepeater
            model: root.menuItems

            Item {
                id: menuBtn
                required property var modelData
                required property int index

                readonly property bool isOpen: root.openIdx === index
                readonly property bool hasChildren: (modelData.items?.length ?? 0) > 0

                implicitWidth: btnLabel.implicitWidth + 14
                implicitHeight: Appearance.sizes.baseBarHeight

                Rectangle {
                    anchors { fill: parent; margins: 3 }
                    radius: Appearance.rounding.small
                    color: menuBtn.isOpen || btnHover.containsMouse
                        ? Appearance.colors.colLayer1Hover
                        : "transparent"
                    Behavior on color {
                        animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                    }
                }

                StyledText {
                    id: btnLabel
                    anchors.centerIn: parent
                    text: menuBtn.modelData.label ?? ""
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnLayer0
                    opacity: (menuBtn.modelData.enabled ?? true) ? 1.0 : 0.4
                }

                MouseArea {
                    id: btnHover
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.openIdx = menuBtn.isOpen ? -1 : menuBtn.index
                    onEntered: {
                        if (root.openIdx >= 0 && !menuBtn.isOpen)
                            root.openIdx = menuBtn.index
                    }
                }

                Loader {
                    id: popupLoader
                    active: menuBtn.isOpen && menuBtn.hasChildren

                    sourceComponent: PopupWindow {
                        id: popup
                        color: "transparent"

                        anchor {
                            window: menuBtn.QsWindow.window
                            item: menuBtn
                            gravity: Config.options.bar.bottom ? Edges.Top : Edges.Bottom
                            edges: Config.options.bar.bottom ? Edges.Top : Edges.Bottom
                        }

                        implicitWidth: popupBg.implicitWidth + popupBg.padding * 2 + 8
                        implicitHeight: popupBg.implicitHeight + popupBg.padding * 2 + 8

                        // Close on outside click
                        MouseArea {
                            anchors.fill: parent
                            z: -1
                            onClicked: root.openIdx = -1
                        }

                        StyledRectangularShadow {
                            target: popupBg
                        }

                        Rectangle {
                            id: popupBg
                            readonly property real padding: 4
                            anchors {
                                fill: parent
                                margins: 4
                            }
                            color: Appearance.colors.colLayer0
                            radius: Appearance.rounding.windowRounding
                            border.width: 1
                            border.color: Appearance.colors.colLayer0Border
                            clip: true

                            implicitWidth: entryCol.implicitWidth + padding * 2
                            implicitHeight: entryCol.implicitHeight + padding * 2

                            opacity: 0
                            Component.onCompleted: opacity = 1
                            Behavior on opacity {
                                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                            }

                            ColumnLayout {
                                id: entryCol
                                anchors {
                                    fill: parent
                                    margins: popupBg.padding
                                }
                                spacing: 0

                                Repeater {
                                    model: menuBtn.modelData.items ?? []

                                    delegate: MenuEntry {
                                        required property var modelData
                                        entry: modelData
                                        Layout.fillWidth: true
                                        onActivated: {
                                            root.openIdx = -1
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component MenuEntry: RippleButton {
        id: entryBtn
        required property var entry
        signal activated()

        readonly property bool isSep: entry.sep ?? false

        implicitHeight: isSep ? 1 : 32
        Layout.topMargin: isSep ? 4 : 0
        Layout.bottomMargin: isSep ? 4 : 0
        horizontalPadding: 12
        implicitWidth: entryContent.implicitWidth + horizontalPadding * 2
        enabled: !isSep

        colBackground: isSep
            ? Appearance.m3colors.m3outlineVariant
            : ColorUtils.transparentize(Appearance.colors.colLayer0)

        Component.onCompleted: {
            if (isSep) buttonColor = colBackground
        }

        releaseAction: () => {
            if (!isSep) entryBtn.activated()
        }

        contentItem: RowLayout {
            id: entryContent
            anchors {
                verticalCenter: parent.verticalCenter
                left: parent.left; right: parent.right
                leftMargin: entryBtn.horizontalPadding
                rightMargin: entryBtn.horizontalPadding
            }
            spacing: 8

            StyledText {
                Layout.fillWidth: true
                text: entryBtn.isSep ? "" : (entryBtn.entry.label ?? "")
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer0
                opacity: (entryBtn.entry.enabled ?? true) ? 1.0 : 0.4
                elide: Text.ElideRight
            }
        }
    }
}
