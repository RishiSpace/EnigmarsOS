/*
 * EnigmarsOS SDDM theme
 *
 * Uses pure QtQuick + SddmComponents only.
 * Do NOT import QtQuick.Controls here: SddmComponents also exports Button,
 * which shadows Controls.Button and has no "background" property — that
 * caused "Cannot assign to non-existent property background" on login.
 */
import QtQuick 2.15
import QtQuick.Layouts 1.15
import SddmComponents 2.0

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "#000000"

    readonly property color accent: (typeof config !== "undefined" && config.accentColor)
                                    ? config.accentColor : "#00E5FF"
    readonly property color secondary: (typeof config !== "undefined" && config.secondaryColor)
                                       ? config.secondaryColor : "#7B2FFF"
    readonly property string fontName: (typeof config !== "undefined" && config.fontFamily)
                                       ? config.fontFamily : "sans-serif"

    function conf(key, fallback) {
        if (typeof config === "undefined")
            return fallback
        var v = config[key]
        return (v !== undefined && v !== null && v !== "") ? v : fallback
    }

    // Wallpaper (relative paths must be resolved against the theme dir)
    Image {
        id: wallpaper
        anchors.fill: parent
        source: Qt.resolvedUrl(conf("background", "backgrounds/wallpaper.png"))
        fillMode: Image.PreserveAspectCrop
        opacity: 0.55
        asynchronous: true
        onStatusChanged: {
            if (status === Image.Error)
                source = ""
        }
    }

    // Dim overlay
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#cc000000" }
            GradientStop { position: 1.0; color: "#ee000000" }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 20
        width: 360

        Image {
            Layout.alignment: Qt.AlignHCenter
            source: Qt.resolvedUrl(conf("logo", "assets/logo.png"))
            sourceSize.width: 192
            sourceSize.height: 192
            Layout.preferredWidth: 96
            Layout.preferredHeight: 96
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            onStatusChanged: {
                if (status === Image.Error)
                    visible = false
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "EnigmarsOS"
            color: "#FFFFFF"
            font.pixelSize: 28
            font.weight: Font.DemiBold
            font.family: root.fontName
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Privacy first · Secure by default"
            color: "#88FFFFFF"
            font.pixelSize: 13
            font.family: root.fontName
        }

        // Username
        Rectangle {
            id: userChrome
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            radius: 12
            color: "#121212"
            border.width: 1
            border.color: userField.activeFocus ? root.accent : "#2A2A2A"

            TextInput {
                id: userField
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                verticalAlignment: TextInput.AlignVCenter
                color: "#FFFFFF"
                font.pixelSize: 14
                font.family: root.fontName
                clip: true
                selectByMouse: true
                text: (typeof userModel !== "undefined") ? userModel.lastUser : ""
                KeyNavigation.tab: passwordField
                KeyNavigation.backtab: loginButton
                Keys.onPressed: function (event) {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        passwordField.forceActiveFocus()
                        event.accepted = true
                    }
                }
            }

            Text {
                anchors.fill: userField
                verticalAlignment: Text.AlignVCenter
                text: "Username"
                color: "#66FFFFFF"
                font.pixelSize: 14
                font.family: root.fontName
                visible: userField.text.length === 0 && !userField.activeFocus
            }
        }

        // Password
        Rectangle {
            id: passChrome
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            radius: 12
            color: "#121212"
            border.width: 1
            border.color: passwordField.activeFocus ? root.accent : "#2A2A2A"

            TextInput {
                id: passwordField
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                verticalAlignment: TextInput.AlignVCenter
                color: "#FFFFFF"
                font.pixelSize: 14
                font.family: root.fontName
                echoMode: TextInput.Password
                clip: true
                selectByMouse: true
                KeyNavigation.tab: loginButton
                KeyNavigation.backtab: userField
                Keys.onPressed: function (event) {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.doLogin()
                        event.accepted = true
                    }
                }
            }

            Text {
                anchors.fill: passwordField
                verticalAlignment: Text.AlignVCenter
                text: "Password"
                color: "#66FFFFFF"
                font.pixelSize: 14
                font.family: root.fontName
                visible: passwordField.text.length === 0 && !passwordField.activeFocus
            }
        }

        // Sign in
        Rectangle {
            id: loginButton
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            radius: 12
            focus: true
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: mouseArea.containsPress ? Qt.darker(root.accent, 1.15) : root.accent }
                GradientStop { position: 1.0; color: mouseArea.containsPress ? Qt.darker(root.secondary, 1.15) : root.secondary }
            }

            Text {
                anchors.centerIn: parent
                text: "Sign in"
                color: "#000000"
                font.pixelSize: 15
                font.weight: Font.DemiBold
                font.family: root.fontName
            }

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.doLogin()
            }

            Keys.onPressed: function (event) {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                        || event.key === Qt.Key_Space) {
                    root.doLogin()
                    event.accepted = true
                }
            }
            KeyNavigation.tab: userField
            KeyNavigation.backtab: passwordField
        }

        Text {
            id: errorText
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            color: "#FF6B6B"
            font.pixelSize: 12
            font.family: root.fontName
            wrapMode: Text.WordWrap
            visible: text.length > 0
            text: ""
        }
    }

    // Session selector (bottom-left)
    Row {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 24
        spacing: 8
        visible: typeof sessionModel !== "undefined" && sessionModel.count > 0

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Session"
            color: "#66FFFFFF"
            font.pixelSize: 12
            font.family: root.fontName
        }

        ComboBox {
            id: sessionCombo
            width: 200
            height: 28
            model: (typeof sessionModel !== "undefined") ? sessionModel : null
            index: (typeof sessionModel !== "undefined") ? sessionModel.lastIndex : 0
            color: "#121212"
            borderColor: "#2A2A2A"
            focusColor: root.accent
            hoverColor: root.accent
            textColor: "#FFFFFF"
            menuColor: "#121212"
            arrowColor: "#FFFFFF"
            font.pixelSize: 12
        }
    }

    // Power actions (bottom-right)
    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 24
        spacing: 12

        Rectangle {
            width: 88; height: 32; radius: 8
            color: rebootArea.containsMouse ? "#2A2A2A" : "#121212"
            border.color: "#2A2A2A"; border.width: 1
            Text {
                anchors.centerIn: parent
                text: "Reboot"
                color: "#CCFFFFFF"
                font.pixelSize: 12
                font.family: root.fontName
            }
            MouseArea {
                id: rebootArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: sddm.reboot()
            }
        }
        Rectangle {
            width: 88; height: 32; radius: 8
            color: powerArea.containsMouse ? "#2A2A2A" : "#121212"
            border.color: "#2A2A2A"; border.width: 1
            Text {
                anchors.centerIn: parent
                text: "Shutdown"
                color: "#CCFFFFFF"
                font.pixelSize: 12
                font.family: root.fontName
            }
            MouseArea {
                id: powerArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: sddm.powerOff()
            }
        }
    }

    Text {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 28
        text: "EnigmarsOS"
        color: "#44FFFFFF"
        font.pixelSize: 12
        font.family: root.fontName
    }

    function doLogin() {
        errorText.text = ""
        var user = userField.text
        var pass = passwordField.text
        var session = 0
        if (typeof sessionCombo !== "undefined" && sessionCombo.index >= 0)
            session = sessionCombo.index
        else if (typeof sessionModel !== "undefined")
            session = sessionModel.lastIndex
        sddm.login(user, pass, session)
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            errorText.text = "Login failed"
            passwordField.text = ""
            passwordField.forceActiveFocus()
        }
        function onLoginSucceeded() {
            errorText.text = ""
        }
    }

    Component.onCompleted: {
        if (userField.text.length > 0)
            passwordField.forceActiveFocus()
        else
            userField.forceActiveFocus()
    }
}
