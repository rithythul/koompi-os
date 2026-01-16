import QtQuick 2.15
import QtQuick.Controls 2.15
import SddmComponents 2.0

Rectangle {
    id: root
    width: 1920
    height: 1080

    Image {
        id: background
        anchors.fill: parent
        source: config.background || "/usr/share/wallpapers/KOOMPI/contents/images/1920x1080.png"
        fillMode: Image.PreserveAspectCrop
    }

    Rectangle {
        anchors.fill: parent
        color: "#00000066"
    }

    Column {
        anchors.centerIn: parent
        spacing: 20

        Image {
            id: logo
            source: "/usr/share/koompi/icons/koompi-menu-dark.png"
            width: 128
            height: 128
            anchors.horizontalCenter: parent.horizontalCenter
            fillMode: Image.PreserveAspectFit
        }

        Text {
            text: "KOOMPI OS"
            color: "#ffffff"
            font.pixelSize: 32
            font.bold: true
            anchors.horizontalCenter: parent.horizontalCenter
        }

        TextField {
            id: username
            width: 300
            height: 40
            placeholderText: "Username"
            font.pixelSize: 16
            anchors.horizontalCenter: parent.horizontalCenter
            background: Rectangle {
                color: "#ffffff22"
                border.color: "#33ccff"
                border.width: 1
                radius: 5
            }
            color: "#ffffff"
        }

        TextField {
            id: password
            width: 300
            height: 40
            placeholderText: "Password"
            echoMode: TextInput.Password
            font.pixelSize: 16
            anchors.horizontalCenter: parent.horizontalCenter
            background: Rectangle {
                color: "#ffffff22"
                border.color: "#33ccff"
                border.width: 1
                radius: 5
            }
            color: "#ffffff"
            
            Keys.onReturnPressed: sddm.login(username.text, password.text, sessionModel.lastIndex)
        }

        Button {
            id: loginButton
            text: "Login"
            width: 300
            height: 45
            anchors.horizontalCenter: parent.horizontalCenter
            
            background: Rectangle {
                color: loginButton.hovered ? "#33ccff" : "#1e90ff"
                radius: 5
            }
            
            contentItem: Text {
                text: loginButton.text
                color: "#ffffff"
                font.pixelSize: 16
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            
            onClicked: sddm.login(username.text, password.text, sessionModel.lastIndex)
        }
    }

    Text {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 20
        text: "KOOMPI OS • Powered by KDE Plasma"
        color: "#ffffff88"
        font.pixelSize: 14
    }
}
