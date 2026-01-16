import QtQuick 2.15

Rectangle {
    id: root
    color: "#1a1a2e"
    
    property int stage
    
    onStageChanged: {
        if (stage == 1) {
            introAnimation.running = true
        }
    }
    
    Image {
        id: logo
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -40
        source: "images/logo.png"
        sourceSize.width: 180
        sourceSize.height: 180
        opacity: 0
        scale: 0.8
    }
    
    Text {
        id: brandText
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: logo.bottom
        anchors.topMargin: 30
        text: "KOOMPI OS"
        color: "#ffffff"
        font.pixelSize: 28
        font.weight: Font.Light
        font.letterSpacing: 4
        opacity: 0
    }
    
    // Loading indicator
    Row {
        id: loadingDots
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 100
        spacing: 12
        opacity: 0
        
        Repeater {
            model: 3
            Rectangle {
                id: dot
                width: 10
                height: 10
                radius: 5
                color: "#33ccff"
                opacity: 0.3
                
                SequentialAnimation on opacity {
                    running: true
                    loops: Animation.Infinite
                    PauseAnimation { duration: index * 200 }
                    NumberAnimation { to: 1; duration: 300; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 0.3; duration: 300; easing.type: Easing.InOutQuad }
                    PauseAnimation { duration: 400 }
                }
            }
        }
    }
    
    ParallelAnimation {
        id: introAnimation
        running: false
        
        NumberAnimation {
            target: logo
            property: "opacity"
            from: 0
            to: 1
            duration: 800
            easing.type: Easing.OutCubic
        }
        
        NumberAnimation {
            target: logo
            property: "scale"
            from: 0.8
            to: 1
            duration: 800
            easing.type: Easing.OutBack
        }
        
        SequentialAnimation {
            PauseAnimation { duration: 300 }
            NumberAnimation {
                target: brandText
                property: "opacity"
                from: 0
                to: 1
                duration: 600
                easing.type: Easing.OutCubic
            }
        }
        
        SequentialAnimation {
            PauseAnimation { duration: 600 }
            NumberAnimation {
                target: loadingDots
                property: "opacity"
                from: 0
                to: 1
                duration: 400
                easing.type: Easing.OutCubic
            }
        }
    }
}
