import QtQuick 2.15

// Bolha de seleção "líquida": desliza com mola até a opção nova e se estica no caminho.
Item {
    id: pill

    property var target: null        // item selecionado (botão da aba/filtro)
    property bool light: false       // bolha clara (texto escuro por cima) ou de vidro
    property real inset: 4

    readonly property real goalX: target ? target.x : 0
    readonly property real goalW: target ? target.width : 0

    x: goalX
    width: goalW
    y: inset
    height: parent ? parent.height - inset * 2 : 0
    visible: target !== null

    Behavior on x { SpringAnimation { spring: 4.2; damping: 0.32; epsilon: 0.25 } }
    Behavior on width { SpringAnimation { spring: 4.2; damping: 0.32; epsilon: 0.25 } }

    // estica durante o deslize
    property real stretch: 1
    onGoalXChanged: stretchAnim.restart()
    SequentialAnimation {
        id: stretchAnim
        NumberAnimation { target: pill; property: "stretch"; to: 1.10; duration: 110; easing.type: Easing.OutQuad }
        NumberAnimation { target: pill; property: "stretch"; to: 1.0; duration: 320; easing.type: Easing.OutBack }
    }

    Rectangle {
        anchors.centerIn: parent
        width: parent.width * pill.stretch
        height: parent.height * (2 - pill.stretch)
        radius: height / 2
        gradient: Gradient {
            GradientStop { position: 0.0; color: pill.light ? "#f7f8fb" : "#42ffffff" }
            GradientStop { position: 1.0; color: pill.light ? "#e4e7ee" : "#1fffffff" }
        }
        border.width: 1
        border.color: pill.light ? "#ffffff" : "#40ffffff"

        Rectangle {
            anchors.top: parent.top
            anchors.topMargin: 1
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - parent.radius
            height: 1
            color: pill.light ? "#ffffff" : "#66ffffff"
        }
    }
}
