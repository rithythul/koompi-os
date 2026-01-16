import QtQuick 2.0
import calamares.slideshow 1.0

Presentation {
    id: presentation

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }

    Slide {
        Image {
            id: slide1
            source: "slide1.png"
            anchors.centerIn: parent
            width: parent.width * 0.8
            height: parent.height * 0.8
            fillMode: Image.PreserveAspectFit
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 50
            text: "Welcome to KOOMPI OS"
            font.pixelSize: 24
            font.bold: true
            color: "#ffffff"
        }
    }

    Slide {
        Text {
            anchors.centerIn: parent
            text: "🛡️ Immutable & Secure\n\nAutomatic snapshots protect your system.\nRollback anytime with one command."
            font.pixelSize: 20
            color: "#ffffff"
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            width: parent.width * 0.8
        }
    }

    Slide {
        Text {
            anchors.centerIn: parent
            text: "📦 Modern Package Management\n\nUse 'koompi install' for packages.\nAUR support built-in with paru."
            font.pixelSize: 20
            color: "#ffffff"
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            width: parent.width * 0.8
        }
    }

    Slide {
        Text {
            anchors.centerIn: parent
            text: "🎨 Beautiful KDE Plasma\n\nCustomized for KOOMPI with\nmodern dark theme and clean design."
            font.pixelSize: 20
            color: "#ffffff"
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            width: parent.width * 0.8
        }
    }

    Slide {
        Text {
            anchors.centerIn: parent
            text: "🇰🇭 Built for Cambodia\n\nKhmer language support included.\nOptimized for local users."
            font.pixelSize: 20
            color: "#ffffff"
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            width: parent.width * 0.8
        }
    }
}
