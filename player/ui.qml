import QtQuick 6.5
import QtQuick.Controls 6.5
import QtQuick.Controls.Basic 6.5
import QtQuick.Layouts 6.5
import QtMultimedia 6.5

ApplicationWindow {
    id: root
    width: 900
    height: 520
    visible: true
    color: "#121212"
    title: "Music Player"

    property url iconPrev: Qt.resolvedUrl("assets/icons/prev.svg")
    property url iconPlay: Qt.resolvedUrl("assets/icons/play.svg")
    property url iconPause: Qt.resolvedUrl("assets/icons/pause.svg")
    property url iconNext: Qt.resolvedUrl("assets/icons/next.svg")
    property url iconRefresh: Qt.resolvedUrl("assets/icons/refresh.svg")

    MediaPlayer {
        id: player
        audioOutput: AudioOutput { }
        onPlaybackStateChanged: {
            playButtonIcon.source = playbackState === MediaPlayer.PlayingState
                ? iconPause
                : iconPlay
        }
        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.EndOfMedia && trackModel.count > 0) {
                var nextIndex = coverflow.currentIndex + 1
                if (nextIndex >= trackModel.count) {
                    nextIndex = 0
                }
                playAtIndex(nextIndex)
            }
        }
    }

    function formatTime(ms) {
        var total = Math.max(0, Math.floor(ms / 1000))
        var minutes = Math.floor(total / 60)
        var seconds = total % 60
        return minutes + ":" + (seconds < 10 ? "0" + seconds : seconds)
    }

    function playAtIndex(index) {
        if (trackModel.count === 0) {
            return
        }
        var safeIndex = Math.max(0, Math.min(index, trackModel.count - 1))
        coverflow.currentIndex = safeIndex
        var item = trackModel.get(safeIndex)
        if (item.path) {
            player.stop()
            player.source = item.path
            player.play()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 28
        spacing: 12

        Rectangle {
            anchors.fill: parent
            z: -1
            color: "#121212"
        }

        Rectangle {
            id: card
            Layout.fillWidth: true
            Layout.preferredHeight: 420
            radius: 18
            color: "#1c1f23"

            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 24

                PathView {
                    id: coverflow
                    Layout.preferredWidth: 520
                    Layout.preferredHeight: 320
                    Layout.alignment: Qt.AlignVCenter
                    clip: true
                    model: trackModel
                    preferredHighlightBegin: 0.5
                    preferredHighlightEnd: 0.5
                    highlightRangeMode: PathView.StrictlyEnforceRange
                    snapMode: PathView.SnapOneItem
                    interactive: true
                    pathItemCount: 9
                    flickDeceleration: 5200

                    path: Path {
                        startX: coverflow.width * 0.18
                        startY: coverflow.height / 2
                        PathAttribute { name: "itemScale"; value: 0.7 }
                        PathAttribute { name: "itemAngle"; value: 38 }
                        PathAttribute { name: "itemZ"; value: 0 }
                        PathLine {
                            x: coverflow.width / 2
                            y: coverflow.height / 2
                        }
                        PathAttribute { name: "itemScale"; value: 1.0 }
                        PathAttribute { name: "itemAngle"; value: 0 }
                        PathAttribute { name: "itemZ"; value: 10 }
                        PathLine {
                            x: coverflow.width * 0.82
                            y: coverflow.height / 2
                        }
                        PathAttribute { name: "itemScale"; value: 0.7 }
                        PathAttribute { name: "itemAngle"; value: -38 }
                        PathAttribute { name: "itemZ"; value: 0 }
                    }

                    delegate: Item {
                        width: 260
                        height: 260
                        property real scaleValue: PathView.itemScale
                        property real angleValue: PathView.itemAngle
                        property real depthValue: PathView.itemZ
                        z: depthValue

                        transform: [
                            Rotation { axis.y: 1; angle: angleValue },
                            Scale { xScale: scaleValue; yScale: scaleValue }
                        ]

                        Rectangle {
                            id: coverFrame
                            width: 220
                            height: 220
                            radius: 10
                            anchors.centerIn: parent
                            color: "#1c1c1c"
                            clip: true

                            Image {
                                id: coverImage
                                anchors.centerIn: parent
                                width: 220
                                height: 220
                                source: cover
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                mipmap: true
                                sourceSize.width: 220
                                sourceSize.height: 220
                            }
                        }

                        Image {
                            anchors.horizontalCenter: coverFrame.horizontalCenter
                            anchors.top: coverFrame.bottom
                            anchors.topMargin: 10
                            source: cover
                            width: 220
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            mipmap: true
                            opacity: 0.22
                            transform: Scale { yScale: -1 }
                            clip: true
                            height: 70
                            sourceSize.width: 220
                            sourceSize.height: 220
                        }
                    }

                    onCurrentIndexChanged: {
                        if (trackModel.count > 0) {
                            var item = trackModel.get(currentIndex)
                            titleLabel.text = item.title || "No tracks"
                            artistLabel.text = item.artist || ""
                        } else {
                            titleLabel.text = "No tracks"
                            artistLabel.text = ""
                        }
                    }

                    onMovementEnded: {
                        if (trackModel.count > 0) {
                            playAtIndex(currentIndex)
                        }
                    }

                    Component.onCompleted: {
                        if (trackModel.count > 0) {
                            var item = trackModel.get(currentIndex)
                            titleLabel.text = item.title || "No tracks"
                            artistLabel.text = item.artist || ""
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (player.playbackState === MediaPlayer.PlayingState) {
                                player.pause()
                            } else {
                                player.play()
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Label {
                        id: titleLabel
                        text: "No tracks"
                        color: "#f2f2f2"
                        font.pixelSize: 20
                        font.bold: true
                    }

                    Label {
                        id: artistLabel
                        text: ""
                        color: "#b0b0b0"
                        font.pixelSize: 12
                    }

                    RowLayout {
                        spacing: 8
                        Label {
                            text: formatTime(player.position)
                            color: "#b0b0b0"
                            font.pixelSize: 11
                        }
                        Item {
                            id: timeBar
                            Layout.fillWidth: true
                            height: 12
                            property bool seeking: false
                            property real progress: player.duration > 0 ? player.position / player.duration : 0

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                height: 6
                                radius: 3
                                color: "#3b3f44"
                            }

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width * timeBar.progress
                                height: 6
                                radius: 3
                                color: "#f2f2f2"
                            }

                            Rectangle {
                                width: 12
                                height: 12
                                radius: 6
                                color: "#f2f2f2"
                                x: (parent.width * timeBar.progress) - width / 2
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            MouseArea {
                                anchors.fill: parent
                                onPressed: {
                                    timeBar.seeking = true
                                    var ratio = Math.max(0, Math.min(mouse.x / timeBar.width, 1))
                                    player.position = ratio * player.duration
                                }
                                onPositionChanged: {
                                    if (!timeBar.seeking) {
                                        return
                                    }
                                    var ratio = Math.max(0, Math.min(mouse.x / timeBar.width, 1))
                                    player.position = ratio * player.duration
                                }
                                onReleased: timeBar.seeking = false
                            }
                        }
                        Label {
                            text: formatTime(player.duration)
                            color: "#b0b0b0"
                            font.pixelSize: 11
                        }
                    }

                    RowLayout {
                        spacing: 12
                        Button {
                            onClicked: {
                                if (trackModel.count > 0) {
                                    var prevIndex = coverflow.currentIndex - 1
                                    if (prevIndex < 0) {
                                        prevIndex = trackModel.count - 1
                                    }
                                    playAtIndex(prevIndex)
                                }
                            }
                            background: Rectangle { color: "#22262b"; radius: 18 }
                            contentItem: Image {
                                source: iconPrev
                                width: 22
                                height: 22
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                anchors.centerIn: parent
                            }
                            width: 44
                            height: 36
                        }
                        Button {
                            onClicked: {
                                if (player.playbackState === MediaPlayer.PlayingState) {
                                    player.pause()
                                } else {
                                    player.play()
                                }
                            }
                            background: Rectangle { color: "#22262b"; radius: 18 }
                            contentItem: Image {
                                id: playButtonIcon
                                source: iconPlay
                                width: 22
                                height: 22
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                anchors.centerIn: parent
                            }
                            width: 48
                            height: 36
                        }
                        Button {
                            onClicked: {
                                if (trackModel.count > 0) {
                                    var nextIndex = coverflow.currentIndex + 1
                                    if (nextIndex >= trackModel.count) {
                                        nextIndex = 0
                                    }
                                    playAtIndex(nextIndex)
                                }
                            }
                            background: Rectangle { color: "#22262b"; radius: 18 }
                            contentItem: Image {
                                source: iconNext
                                width: 22
                                height: 22
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                anchors.centerIn: parent
                            }
                            width: 44
                            height: 36
                        }
                        Button {
                            onClicked: trackStore.refresh()
                            background: Rectangle { color: "#22262b"; radius: 18 }
                            contentItem: Image {
                                source: iconRefresh
                                width: 20
                                height: 20
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                anchors.centerIn: parent
                            }
                            width: 40
                            height: 36
                        }
                    }
                }
            }
        }
    }
}
