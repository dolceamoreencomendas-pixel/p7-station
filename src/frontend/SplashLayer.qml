// P7 Station - tela de carregamento (baseada na SplashLayer do Pegasus Frontend, GPLv3)
import QtQuick 2.15


Rectangle {
    id: root
    color: "#08061c"
    anchors.fill: parent

    property real progress: 0
    property bool showDataProgressText: true
    property alias stage: gameCounter.text

    Behavior on progress { NumberAnimation { duration: 300 } }

    Rectangle {
        anchors.centerIn: logo
        width: logo.width * 1.9
        height: width
        radius: width / 2
        color: "#3a2cff"
        opacity: 0.10
    }

    Image {
        id: logo
        source: "assets/p7-icon.png"
        width: Math.min(parent.width, parent.height) * 0.26
        height: width
        fillMode: Image.PreserveAspectFit
        smooth: true
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.verticalCenter
        anchors.bottomMargin: vpx(10)

        // só pulsa enquanto a tela de carregamento aparece (escondida, não pode pedir quadros)
        SequentialAnimation on scale {
            loops: Animation.Infinite
            running: root.visible
            NumberAnimation { from: 1.0; to: 1.04; duration: 1400; easing.type: Easing.InOutSine }
            NumberAnimation { from: 1.04; to: 1.0; duration: 1400; easing.type: Easing.InOutSine }
        }
    }

    Text {
        id: title
        text: "P7  STATION"
        color: "#ffffff"
        opacity: 0.9
        font.pixelSize: vpx(26)
        font.letterSpacing: vpx(8)
        font.weight: Font.Light
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.verticalCenter
        anchors.topMargin: vpx(28)
    }

    Rectangle {
        id: progressRoot
        width: Math.min(parent.width * 0.32, vpx(420))
        height: vpx(4)
        radius: height / 2
        color: "#22ffffff"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: title.bottom
        anchors.topMargin: vpx(36)

        Rectangle {
            height: parent.height
            radius: parent.radius
            width: parent.width * Math.max(0.04, root.progress)
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#3fa9ff" }
                GradientStop { position: 0.6; color: "#8b5cff" }
                GradientStop { position: 1.0; color: "#ff5fa0" }
            }
        }
    }

    Text {
        id: gameCounter
        visible: showDataProgressText
        color: "#80ffffff"
        font.pixelSize: vpx(14)
        anchors.top: progressRoot.bottom
        anchors.topMargin: vpx(14)
        anchors.horizontalCenter: progressRoot.horizontalCenter
    }
}
