pragma Singleton
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

/**
 * A nice wrapper for date and time strings.
 */
Singleton {
    id: root

    property alias inhibit: idleInhibitor.enabled
    inhibit: false

    Connections {
        target: Persistent
        function onReadyChanged() {
            if (!Persistent.isNewHyprlandInstance) {
                root.inhibit = Persistent.states.idle.inhibit;
            } else {
                Persistent.states.idle.inhibit = root.inhibit;
            }
        }
    }

    function toggleInhibit(active = null) {
        if (active !== null) {
            root.inhibit = active;
        } else {
            root.inhibit = !root.inhibit;
        }
        Persistent.states.idle.inhibit = root.inhibit;
    }

    // The Wayland inhibitor below only works while its surface is mapped, which
    // is unreliable on Hyprland (the 1x1 window often never maps). Back it with a
    // systemd idle inhibitor, which hypridle honors directly.
    Process {
        running: root.inhibit
        command: ["systemd-inhibit", "--what=idle:sleep", "--mode=block",
                  "--who=quickshell", "--why=Keep system awake", "sleep", "infinity"]
    }

    IdleInhibitor {
        id: idleInhibitor
        window: PanelWindow {
            // Inhibitor only works while its surface is actually mapped.
            // A 0x0 window never maps, so Hyprland ignores the inhibitor.
            visible: idleInhibitor.enabled
            implicitWidth: 1
            implicitHeight: 1
            color: "transparent"
            // Just in case...
            anchors {
                right: true
                bottom: true
            }
            // Make it not interactable
            mask: Region {
                item: null
            }
        }
    }
}
