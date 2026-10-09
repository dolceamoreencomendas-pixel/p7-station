import QtQuick 2.15
import QtGraphicalEffects 1.12
import "logic.js" as L

// Página do jogo (Quadrado): capa grande, tempo jogado, última vez, troféus,
// botões Jogar · Favoritar · Troféus e as últimas conquistas do RetroAchievements.
Item {
    id: page

    property var host: null
    property var backdrop: null
    property var stageItem: null
    property bool open: false

    readonly property var entry: host ? host.current : null
    readonly property var tinfo: host ? host.trophyInfo(entry) : ({ kind: "none", text: "" })
    readonly property var ach: host ? host.achFor(host.detailsGameId) : null
    readonly property var recent: ach && ach.state === "ok" ? L.recentEarned(ach.list, 8) : []
    readonly property var buttons: host ? host.detailButtons : []

    visible: opacity > 0
    opacity: open ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

    property real slide: open ? 0 : 40
    Behavior on slide { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }

    // fundo: o vidro cobre a tela toda (só o fundo desfocado do jogo aparece)
    Glass {
        anchors.fill: parent
        radius: 0
        refraction: 0
        backdrop: page.backdrop
        stageItem: page.stageItem
        tint: "#66080712"
        visible: page.visible
    }
    MouseArea { anchors.fill: parent; onClicked: {} }

    // ---------------------------------------------------- capa
    Item {
        id: coverBox
        x: 96 - page.slide
        width: 400
        height: 400
        y: Math.round((page.height - height) / 2) - 10
        RectangularGlow {
            anchors.fill: parent
            anchors.topMargin: 30
            glowRadius: 40
            spread: 0.1
            cornerRadius: 60 + glowRadius
            color: "#b3000000"
        }
        GameTile {
            anchors.fill: parent
            baseSize: 400
            entry: page.entry
            selected: false
            dimOpacity: 1
            showRing: false
            selScale: 1
            pixelRatio: page.host ? page.host.pixelRatio : 2
        }
    }

    // ---------------------------------------------------- informações
    Column {
        id: info
        x: 560 + page.slide
        width: page.width - x - 96
        anchors.verticalCenter: coverBox.verticalCenter
        spacing: 14

        Text {
            text: page.entry ? (page.entry.sysName + (page.entry.emuFull ? "  ·  " + page.entry.emuFull : "")).toUpperCase() : ""
            color: "#b3ffffff"
            font.family: "Manrope"
            font.weight: Font.Bold
            font.pixelSize: 14
            font.letterSpacing: 2.4
        }
        Text {
            width: parent.width
            text: page.entry ? page.entry.display : ""
            color: "#ffffff"
            font.family: "Sora"
            font.weight: Font.Light
            font.pixelSize: 60
            font.letterSpacing: -1.6
            lineHeight: 1.02
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
        Text {
            visible: page.entry !== null && !page.entry.emuOk
            text: page.entry ? "Falta instalar o " + page.entry.emuName + " neste tablet" : ""
            color: "#ffcc80"
            font.family: "Manrope"
            font.weight: Font.Medium
            font.pixelSize: 17
        }
        Item { width: 1; height: 6 }

        // números
        Row {
            spacing: 14
            Repeater {
                model: [
                    { label: "TEMPO JOGADO", value: page.entry ? L.formatPlayTime(page.entry.playTime) : "" },
                    { label: "ÚLTIMA VEZ", value: page.entry ? L.formatLastPlayed(page.entry.lastPlayed) : "" }
                ]
                delegate: Rectangle {
                    width: 210; height: 96; radius: 22
                    color: "#14ffffff"; border.width: 1; border.color: "#1fffffff"
                    Column {
                        x: 22; anchors.verticalCenter: parent.verticalCenter; spacing: 8
                        Text { text: modelData.label; color: "#80ffffff"; font.family: "Manrope"; font.weight: Font.Bold; font.pixelSize: 12; font.letterSpacing: 1.6 }
                        Text { text: modelData.value; color: "#ffffff"; font.family: "Sora"; font.pixelSize: 22 }
                    }
                }
            }
            Rectangle {
                width: 260; height: 96; radius: 22
                color: "#14ffffff"; border.width: 1; border.color: "#1fffffff"
                Ring {
                    id: tRing
                    visible: page.tinfo.kind === "progress"
                    x: 20; anchors.verticalCenter: parent.verticalCenter
                    width: 58; height: 58
                    lineWidth: 5
                    value: page.tinfo.kind === "progress" && page.tinfo.total > 0 ? page.tinfo.got / page.tinfo.total : 0
                    pixelRatio: page.host ? page.host.pixelRatio : 2
                    Text {
                        anchors.centerIn: parent
                        text: page.tinfo.kind === "progress" && page.tinfo.total > 0 ? Math.round(100 * page.tinfo.got / page.tinfo.total) + "%" : ""
                        color: "#ffffff"; font.family: "Manrope"; font.weight: Font.Bold; font.pixelSize: 13
                    }
                }
                Column {
                    x: tRing.visible ? 92 : 22
                    width: parent.width - x - 16
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Text { text: "TROFÉUS"; color: "#80ffffff"; font.family: "Manrope"; font.weight: Font.Bold; font.pixelSize: 12; font.letterSpacing: 1.6 }
                    Text {
                        width: parent.width
                        text: page.tinfo.kind === "progress" ? page.tinfo.got + " de " + page.tinfo.total : (page.tinfo.text || "")
                        color: page.tinfo.kind === "progress" ? "#ffffff" : "#b3ffffff"
                        font.family: page.tinfo.kind === "progress" ? "Sora" : "Manrope"
                        font.pixelSize: page.tinfo.kind === "progress" ? 22 : 14
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                }
            }
        }

        Item { width: 1; height: 8 }

        // botões
        Row {
            spacing: 14
            Repeater {
                model: page.buttons
                delegate: Item {
                    readonly property bool focused: page.host && index === page.host.detailsBtn
                    readonly property bool primary: modelData.id === "play"
                    width: btn.width
                    height: 62
                    Rectangle {
                        id: btn
                        width: btnRow.implicitWidth + (primary ? 64 : 48)
                        height: 62
                        radius: 31
                        color: primary ? "#ffffff" : (focused ? "#33ffffff" : "#17ffffff")
                        border.width: primary ? 0 : 1
                        border.color: "#33ffffff"
                        scale: focused ? 1.06 : 1
                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                        Behavior on color { ColorAnimation { duration: 160 } }
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -5
                            radius: height / 2
                            color: "transparent"
                            border.width: 3
                            border.color: "#f7ffffff"
                            visible: focused
                        }
                        Row {
                            id: btnRow
                            anchors.centerIn: parent
                            spacing: 12
                            Item {
                                width: 22; height: 22
                                anchors.verticalCenter: parent.verticalCenter
                                Canvas {
                                    anchors.centerIn: parent
                                    width: 66; height: 66
                                    scale: 1 / 3
                                    renderTarget: Canvas.Image
                                    onPaint: {
                                        var c = getContext("2d");
                                        c.reset();
                                        c.scale(3, 3);
                                        if (modelData.id === "play") {
                                            c.fillStyle = "#0b0a14";
                                            c.beginPath(); c.moveTo(5, 2.5); c.lineTo(19, 11); c.lineTo(5, 19.5); c.closePath(); c.fill();
                                        } else if (modelData.id === "fav") {
                                            c.fillStyle = modelData.on ? "#ff5c8a" : "rgba(0,0,0,0)";
                                            c.strokeStyle = modelData.on ? "#ff5c8a" : "#ffffff";
                                            c.lineWidth = 1.8;
                                            c.beginPath();
                                            c.moveTo(11, 19);
                                            c.bezierCurveTo(2, 13, 1, 5, 6.5, 3.6);
                                            c.bezierCurveTo(9, 3, 10.5, 4.6, 11, 6.2);
                                            c.bezierCurveTo(11.5, 4.6, 13, 3, 15.5, 3.6);
                                            c.bezierCurveTo(21, 5, 20, 13, 11, 19);
                                            c.closePath();
                                            c.fill(); c.stroke();
                                        } else {
                                            c.strokeStyle = "#ffd36a";
                                            c.lineWidth = 1.8;
                                            c.lineJoin = "round";
                                            c.beginPath();
                                            c.moveTo(6, 3); c.lineTo(16, 3); c.lineTo(16, 8);
                                            c.bezierCurveTo(16, 11, 14, 13, 11, 13);
                                            c.bezierCurveTo(8, 13, 6, 11, 6, 8); c.closePath();
                                            c.moveTo(11, 13); c.lineTo(11, 16);
                                            c.moveTo(7, 19.5); c.lineTo(15, 19.5);
                                            c.moveTo(6, 5); c.lineTo(3, 5); c.bezierCurveTo(3, 8, 4.5, 9.5, 6.5, 9.5);
                                            c.moveTo(16, 5); c.lineTo(19, 5); c.bezierCurveTo(19, 8, 17.5, 9.5, 15.5, 9.5);
                                            c.stroke();
                                        }
                                    }
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.label
                                color: primary ? "#0b0a14" : "#ffffff"
                                font.family: "Manrope"
                                font.weight: Font.Bold
                                font.pixelSize: primary ? 20 : 17
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: { page.host.detailsBtn = index; page.host.detailsActivate(); }
                        }
                    }
                }
            }
        }

        Item { width: 1; height: 14 }

        // últimas conquistas
        Text {
            visible: page.tinfo.kind === "progress"
            text: page.recent.length > 0 ? "CONQUISTAS RECENTES" : "CONQUISTAS"
            color: "#80ffffff"
            font.family: "Manrope"
            font.weight: Font.Bold
            font.pixelSize: 12
            font.letterSpacing: 1.8
        }
        Text {
            visible: page.tinfo.kind === "progress" && page.recent.length === 0
            text: !page.ach || page.ach.state === "loading" ? "Carregando…"
                : page.ach.state === "error" ? "Não foi possível carregar agora"
                : "Nenhuma ainda. Jogue para ganhar a primeira!"
            color: "#a6ffffff"
            font.family: "Manrope"
            font.pixelSize: 16
        }
        Row {
            visible: page.recent.length > 0
            spacing: 12
            Repeater {
                model: page.recent
                delegate: Item {
                    width: 64; height: 64
                    Image {
                        anchors.fill: parent
                        source: "https://media.retroachievements.org/Badge/" + modelData.badge + ".png"
                        asynchronous: true
                        cache: true
                        sourceSize.width: 128
                        layer.enabled: true
                        layer.textureSize: Qt.size(128, 128)
                        layer.effect: OpacityMask { maskSource: Rectangle { width: 64; height: 64; radius: 14 } }
                    }
                    Rectangle {
                        anchors.fill: parent; radius: 14; color: "transparent"
                        border.width: 1; border.color: "#33ffffff"
                    }
                }
            }
        }
    }
}
