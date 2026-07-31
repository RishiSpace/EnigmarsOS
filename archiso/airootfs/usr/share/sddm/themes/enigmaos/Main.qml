import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import SddmComponents 2.0

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "#000000"

    property string accent: config.accentColor || "#00E5FF"
    property string secondary: config.secondaryColor || "#7B2FFF"

    Image {
        anchors.fill: parent
        source: config.background || "backgrounds/wallpaper.png"
        fillMode: Image.PreserveAspectCrop
        opacity: 0.55
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#000000cc" }
            GradientStop { position: 1.0; color: "#000000ee" }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 24
        width: 360

        Image {
            Layout.alignment: Qt.AlignHCenter
            source: config.logo || "assets/logo.png"
            width: 96
            height: 96
            fillMode: Image.PreserveAspectFit
            sourceSize: Qt.size(192, 192)
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "EnigmaOS"
            color: "white"
            font.pixelSize: 28
            font.weight: Font.DemiBold
            font.family: config.fontFamily || "Inter"
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Privacy first · Secure by default"
            color: "#88FFFFFF"
            font.pixelSize: 13
            font.family: config.fontFamily || "Inter"
        }

        TextField {
            id: userField
            Layout.fillWidth: true
            placeholderText: "Username"
            text: userModel.lastUser
            color: "white"
            placeholderTextColor: "#66FFFFFF"
            background: Rectangle {
                radius: 12
                color: "#121212"
                border.color: userField.activeFocus ? root.accent : "#2A2A2A"
                border.width: 1
            }
            leftPadding: 16
            rightPadding: 16
            topPadding: 12
            bottomPadding: 12
            KeyNavigation.tab: passwordField
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                    passwordField.forceActiveFocus()
            }
        }

        TextField {
            id: passwordField
            Layout.fillWidth: true
            placeholderText: "Password"
            echoMode: TextInput.Password
            color: "white"
            placeholderTextColor: "#66FFFFFF"
            background: Rectangle {
                radius: 12
                color: "#121212"
                border.color: passwordField.activeFocus ? root.accent : "#2A2A2A"
                border.width: 1
            }
            leftPadding: 16
            rightPadding: 16
            topPadding: 12
            bottomPadding: 12
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                    loginButton.clicked()
            }
        }

        Button {
            id: loginButton
            Layout.fillWidth: true
            text: "Sign in"
            contentItem: Text {
                text: loginButton.text
                color: "#000000"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }
            background: Rectangle {
                radius: 12
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: root.accent }
                    GradientStop { position: 1.0; color: root.secondary }
                }
            }
            onClicked: sddm.login(userField.text, passwordField.text, sessionModel.lastIndex)
        }
    }

    Text {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 28
        text: "EnigmaOS"
        color: "#44FFFFFF"
        font.pixelSize: 12
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            passwordField.text = ""
            passwordField.forceActiveFocus()
        }
    }

    Component.onCompleted: {
        if (userField.text.length > 0)
            passwordField.forceActiveFocus()
        else
            userField.forceActiveFocus()
    }
}
