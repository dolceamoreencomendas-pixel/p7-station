import QtQuick 2.15

// Painel de "vidro": translúcido, borda fina e um brilho sutil na parte de cima.
// O desfoque fica só no fundo da tela (feito uma vez), então este painel é leve.
Rectangle {
    id: glass
    color: "#14ffffff"
    border.width: 1
    border.color: "#1cffffff"
    radius: 24

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 1
        anchors.leftMargin: glass.radius * 0.6
        anchors.rightMargin: glass.radius * 0.6
        height: 1
        color: "#26ffffff"
    }
}
