import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Hyprland

Item { // Faux global menu: app icon + bold app name + window title
    id: root
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(root.QsWindow.window?.screen)
    readonly property Toplevel activeWindow: ToplevelManager.activeToplevel

    property string activeWindowAddress: `0x${activeWindow?.HyprlandToplevel?.address}`
    property bool focusingThisMonitor: HyprlandData.activeWorkspace?.monitor == monitor?.name
    property var biggestWindow: HyprlandData.biggestWindowForWorkspace(HyprlandData.monitors[root.monitor?.id]?.activeWorkspace.id)

    readonly property bool hasWindow: root.focusingThisMonitor && root.activeWindow?.activated && root.biggestWindow
    readonly property string appClass: root.hasWindow ? (root.activeWindow?.appId ?? "") : ((root.biggestWindow?.class) ?? "")
    readonly property string windowTitle: root.hasWindow ? (root.activeWindow?.title ?? "") : ((root.biggestWindow?.title) ?? `${Translation.tr("Workspace")} ${monitor?.activeWorkspace?.id ?? 1}`)

    function prettyName(s) {
        if (!s || s.length === 0)
            return Translation.tr("Desktop");
        var n = String(s).split('.').pop().replace(/[-_]/g, ' ');
        return n.replace(/\b\w/g, function (c) {
            return c.toUpperCase();
        });
    }

    implicitWidth: rowLayout.implicitWidth

    RowLayout {
        id: rowLayout

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 6

        IconImage {
            id: appIcon
            implicitSize: 17
            Layout.alignment: Qt.AlignVCenter
            visible: root.appClass.length > 0 && status === Image.Ready
            source: Quickshell.iconPath(AppSearch.guessIcon(root.appClass), "")
        }

        StyledText { // Bold app name, menubar-style
            Layout.alignment: Qt.AlignVCenter
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.DemiBold
            color: Appearance.colors.colOnLayer0
            elide: Text.ElideRight
            text: root.prettyName(root.appClass)
        }

        StyledText { // Window title, dimmed
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            visible: root.windowTitle.length > 0
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
            elide: Text.ElideRight
            text: root.windowTitle
        }
    }
}
