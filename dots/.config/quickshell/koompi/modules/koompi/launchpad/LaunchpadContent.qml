pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Quickshell

FocusScope {
    id: root

    property bool active: false

    // The grid never runs under the bar, the same reserve Quick Look uses.
    readonly property real barInset: 40
    readonly property int columns: 7
    readonly property int rows: 5
    readonly property int pageSize: columns * rows

    property string query: ""
    property int selectedIndex: 0

    // What counts as an app someone actually opens, versus a tool that only
    // exists because something else installed it. Front is checked before
    // tools so an IDE stays an IDE and is not demoted for also being tagged
    // Development.
    readonly property var frontCategories: ["WebBrowser", "IDE", "TextEditor", "TerminalEmulator", "Office", "FileManager", "AudioVideo", "Audio", "Video", "Graphics", "Photography", "InstantMessaging", "Chat", "Email", "Player", "Game", "Spreadsheet", "WordProcessor", "Presentation"]
    readonly property var toolCategories: ["Settings", "System", "HardwareSettings", "Monitor", "Development", "Building", "Debugger", "Profiling", "RevisionControl", "Translation", "Documentation", "ConsoleOnly"]
    // AI apps rarely carry a category that says so - most ship Utility or
    // nothing - so they are named outright rather than guessed at.
    readonly property var frontNames: ["claude", "chatgpt", "lm studio", "lmstudio", "ollama", "openwork", "cursor", "windsurf", "jan", "msty", "obsidian", "zed"]

    function tier(entry) {
        const name = (entry.name ?? "").toLowerCase();
        if (root.frontNames.some(n => name.indexOf(n) !== -1))
            return 0;
        const cats = entry.categories ?? [];
        if (cats.some(c => root.frontCategories.indexOf(c) !== -1))
            return 0;
        if (cats.some(c => root.toolCategories.indexOf(c) !== -1))
            return 2;
        return 1;
    }

    // Anything actually launched leads, whatever it is - a tool you reach for
    // daily should not be buried on page two. Past that, user-facing apps come
    // before tools, and ties fall back to alphabetical so the grid is stable.
    readonly property var allApps: AppSearch.list
        .filter(a => !a.noDisplay)
        .slice()
        .sort((a, b) => {
            const scoreA = LaunchpadUsage.score(a.id);
            const scoreB = LaunchpadUsage.score(b.id);
            if (scoreA !== scoreB)
                return scoreB - scoreA;
            const tierA = root.tier(a);
            const tierB = root.tier(b);
            if (tierA !== tierB)
                return tierA - tierB;
            return a.name.localeCompare(b.name);
        })
    readonly property var apps: root.query.length === 0
        ? root.allApps
        : AppSearch.fuzzyQuery(root.query).filter(a => !a.noDisplay)
    readonly property int pageCount: Math.max(1, Math.ceil(root.apps.length / root.pageSize))

    function reset() {
        root.query = "";
        root.selectedIndex = 0;
        root.launchingId = "";
        launchCloseTimer.stop();
        pager.positionViewAtBeginning();
        searchInput.text = "";
        // Claiming focus here alone is not enough: reset() runs the moment the
        // state flips, before the layer surface is mapped, so the grab lands on
        // a window that does not exist yet and typing goes nowhere.
        focusTimer.restart();
    }

    Timer {
        id: focusTimer
        interval: 60
        repeat: false
        onTriggered: searchInput.forceActiveFocus()
    }

    function close() {
        GlobalStates.launchpadOpen = false;
    }

    // The app is started immediately and the overlay lingers a beat, rather
    // than the other way round: delaying execute() to play an animation would
    // make the app genuinely slower to appear. The pause only exists so the
    // click is acknowledged before everything disappears.
    property string launchingId: ""

    Timer {
        id: launchCloseTimer
        interval: 430
        repeat: false
        onTriggered: root.close()
    }

    function launch(entry) {
        if (!entry || root.launchingId.length > 0)
            return;
        root.launchingId = entry.id;
        LaunchpadUsage.record(entry.id);
        entry.execute();
        launchCloseTimer.restart();
    }

    function launchSelected() {
        root.launch(root.apps[root.selectedIndex]);
    }

    // Selection drives the page, not the other way round: arrowing off the
    // edge of a page should carry the view with it.
    function select(index) {
        if (root.apps.length === 0)
            return;
        root.selectedIndex = Math.max(0, Math.min(root.apps.length - 1, index));
        pager.currentIndex = Math.floor(root.selectedIndex / root.pageSize);
    }

    onQueryChanged: {
        root.selectedIndex = 0;
        pager.positionViewAtBeginning();
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Appearance.m3colors.m3background.r, Appearance.m3colors.m3background.g, Appearance.m3colors.m3background.b, 0.62)

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    // A horizontal ListView drops vertical wheel events entirely, so a mouse
    // wheel or two-finger scroll does nothing to it. This lives on the overlay
    // rather than inside the pager on purpose: a handler declared inside a
    // Flickable is parented to its moving contentItem and never hit-tests where
    // you expect. Deltas accumulate to a threshold so a touchpad's stream of
    // small steps is one page and not a dozen.
    property real wheelAccum: 0

    Timer {
        id: wheelCooldown
        interval: 260
        repeat: false
        onTriggered: root.wheelAccum = 0
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            if (wheelCooldown.running)
                return;
            const delta = event.angleDelta.x !== 0 ? event.angleDelta.x : -event.angleDelta.y;
            root.wheelAccum += delta;
            if (Math.abs(root.wheelAccum) < 90)
                return;
            const step = root.wheelAccum > 0 ? -1 : 1;
            root.wheelAccum = 0;
            wheelCooldown.restart();
            // Page only. Dragging the selection along would light up a tile the
            // pointer is nowhere near.
            pager.currentIndex = Math.max(0, Math.min(root.pageCount - 1, pager.currentIndex + step));
        }
    }

    Item {
        id: stage
        anchors.fill: parent

        opacity: root.active ? 1 : 0
        scale: root.active ? 1 : 1.08
        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.expressiveEffects
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Appearance.animation.elementMove.duration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial
            }
        }

        Rectangle {
            id: searchField
            anchors {
                top: parent.top
                topMargin: root.barInset + 26
                horizontalCenter: parent.horizontalCenter
            }
            width: 340
            height: 38
            radius: Appearance.rounding.full
            color: Qt.rgba(Appearance.colors.colLayer1.r, Appearance.colors.colLayer1.g, Appearance.colors.colLayer1.b, 0.7)

            MaterialSymbol {
                id: searchIcon
                anchors {
                    left: parent.left
                    leftMargin: 14
                    verticalCenter: parent.verticalCenter
                }
                text: "search"
                iconSize: Appearance.font.pixelSize.large
                color: Appearance.colors.colSubtext
            }

            StyledTextInput {
                id: searchInput
                anchors {
                    left: searchIcon.right
                    leftMargin: 10
                    right: parent.right
                    rightMargin: 14
                    verticalCenter: parent.verticalCenter
                }
                focus: true
                onTextChanged: root.query = text

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: searchInput.text.length === 0
                    text: qsTr("Search")
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.small
                }

                Keys.onPressed: event => {
                    switch (event.key) {
                    case Qt.Key_Escape:
                        if (root.query.length > 0)
                            searchInput.text = "";
                        else
                            root.close();
                        event.accepted = true;
                        break;
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                        root.launchSelected();
                        event.accepted = true;
                        break;
                    case Qt.Key_Left:
                        root.select(root.selectedIndex - 1);
                        event.accepted = true;
                        break;
                    case Qt.Key_Right:
                        root.select(root.selectedIndex + 1);
                        event.accepted = true;
                        break;
                    case Qt.Key_Up:
                        root.select(root.selectedIndex - root.columns);
                        event.accepted = true;
                        break;
                    case Qt.Key_Down:
                        root.select(root.selectedIndex + root.columns);
                        event.accepted = true;
                        break;
                    case Qt.Key_PageUp:
                        root.select(root.selectedIndex - root.pageSize);
                        event.accepted = true;
                        break;
                    case Qt.Key_PageDown:
                        root.select(root.selectedIndex + root.pageSize);
                        event.accepted = true;
                        break;
                    case Qt.Key_Home:
                        root.select(0);
                        event.accepted = true;
                        break;
                    case Qt.Key_End:
                        root.select(root.apps.length - 1);
                        event.accepted = true;
                        break;
                    }
                }
            }
        }

        ListView {
            id: pager
            anchors {
                top: searchField.bottom
                topMargin: 22
                bottom: pageDots.top
                bottomMargin: 12
                left: parent.left
                right: parent.right
                leftMargin: 60
                rightMargin: 60
            }

            readonly property real cellWidth: width / root.columns
            readonly property real cellHeight: height / root.rows
            readonly property real iconSize: Math.max(44, Math.min(96, Math.min(cellWidth, cellHeight) * 0.5))

            orientation: ListView.Horizontal
            snapMode: ListView.SnapOneItem
            highlightRangeMode: ListView.StrictlyEnforceRange
            // A zero-width range pinned at 0 is what forces a page boundary.
            // Ending it at `width` instead makes the whole viewport the range,
            // so a half-scrolled page already satisfies it and never snaps.
            preferredHighlightBegin: 0
            preferredHighlightEnd: 0
            // Velocity has to be switched off explicitly or it wins over the
            // duration: the 400px/s default drags a 1800px page across the
            // screen over four and a half seconds, which reads as paging being
            // broken rather than slow.
            highlightMoveVelocity: -1
            highlightMoveDuration: 320
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            model: root.pageCount
            // Neighbouring pages stay realised so a drag reveals the next page
            // already painted instead of a blank panel that fills in late.
            cacheBuffer: width * 2

            delegate: Item {
                id: page
                required property int index
                width: pager.width
                height: pager.height

                // Anchored to the top rather than centred so a partly filled
                // page - the last one, or a short set of search results - keeps
                // its first row where every full page puts it.
                Grid {
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    columns: root.columns

                    Repeater {
                        model: root.apps.slice(page.index * root.pageSize, (page.index + 1) * root.pageSize)

                        delegate: LaunchpadItem {
                            required property var modelData
                            required property int index

                            entry: modelData
                            width: pager.cellWidth
                            height: pager.cellHeight
                            iconSize: pager.iconSize
                            launching: root.launchingId.length > 0 && root.launchingId === modelData.id
                            dimmed: root.launchingId.length > 0 && root.launchingId !== modelData.id
                            selected: root.selectedIndex === page.index * root.pageSize + index
                            onActivated: root.launch(modelData)
                            onHovered: root.selectedIndex = page.index * root.pageSize + index
                        }
                    }
                }
            }
        }

        StyledText {
            anchors.centerIn: pager
            visible: root.apps.length === 0
            text: qsTr("No apps match “%1”").arg(root.query)
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.normal
        }

        Row {
            id: pageDots
            anchors {
                bottom: parent.bottom
                bottomMargin: 34
                horizontalCenter: parent.horizontalCenter
            }
            spacing: 10
            visible: root.pageCount > 1

            Repeater {
                model: root.pageCount

                delegate: Rectangle {
                    required property int index
                    width: 8
                    height: 8
                    radius: 4
                    color: pager.currentIndex === index ? Appearance.colors.colOnLayer0 : Appearance.colors.colSubtext
                    opacity: pager.currentIndex === index ? 0.9 : 0.35

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Appearance.animationCurves.expressiveEffects
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pager.currentIndex = index
                    }
                }
            }
        }
    }
}
