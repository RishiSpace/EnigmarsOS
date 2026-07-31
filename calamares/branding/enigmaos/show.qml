import QtQuick
import calamares.slideshow

Presentation {
    id: presentation
    Rectangle {
        anchors.fill: parent
        color: "#000000"
    }

    Slide {
        anchors.fill: parent
        Image {
            id: background1
            source: "wallpaper.png"
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            opacity: 0.35
        }
        Column {
            anchors.centerIn: parent
            spacing: 16
            Image {
                source: "logo.png"
                width: 120; height: 120
                anchors.horizontalCenter: parent.horizontalCenter
                fillMode: Image.PreserveAspectFit
            }
            Text {
                text: "Welcome to EnigmaOS"
                color: "white"
                font.pixelSize: 32
                font.bold: true
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
                text: "Privacy first · Secure by default · Ready immediately"
                color: "#00E5FF"
                font.pixelSize: 16
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    Slide {
        anchors.fill: parent
        Column {
            anchors.centerIn: parent
            spacing: 12
            width: parent.width * 0.7
            Text { text: "Gaming Ready"; color: "#00E5FF"; font.pixelSize: 28; font.bold: true }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: "Steam, Lutris, Heroic, Proton tooling, GameMode, MangoHud and Gamescope ship out of the box. Multilib and Vulkan are enabled."
                color: "white"; font.pixelSize: 16
            }
        }
    }

    Slide {
        anchors.fill: parent
        Column {
            anchors.centerIn: parent
            spacing: 12
            width: parent.width * 0.7
            Text { text: "Developer Friendly"; color: "#7B2FFF"; font.pixelSize: 28; font.bold: true }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: "Rust, Go, Node, Python, C/C++, Java, Docker, Podman, QEMU/KVM and VSCodium are ready the moment you log in."
                color: "white"; font.pixelSize: 16
            }
        }
    }

    Slide {
        anchors.fill: parent
        Column {
            anchors.centerIn: parent
            spacing: 12
            width: parent.width * 0.7
            Text { text: "Secure & Private"; color: "#00E5FF"; font.pixelSize: 28; font.bold: true }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: "No telemetry. AppArmor and UFW enabled. LUKS encryption, fwupd, Secure Boot friendly boot, and privacy-hardened NetworkManager defaults."
                color: "white"; font.pixelSize: 16
            }
        }
    }

    function onActivate() { presentation.currentSlide = 0 }
    Timer {
        interval: 6000; running: true; repeat: true
        onTriggered: presentation.goToNextSlide()
    }
}
