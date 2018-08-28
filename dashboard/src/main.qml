import QtQuick 2.11
import QtQuick.Window 2.11
import QtQuick.Controls 2.3
import QtQuick.Extras 1.4
import QtQuick.Layouts 1.3
import QtQuick.Controls.Styles 1.4

Window {
    id: window
    visible: true
    width: 800
    height: 480
    maximumHeight: height
    maximumWidth: width
    minimumHeight: height
    minimumWidth: width
    //visibility: Window.FullScreen

    Shortcut {
        sequence: "Escape"
        onActivated: visibility = Window.Windowed
    }

    color: "#363636"
    title: qsTr("Hello World")

    Column {
        id: column
        width: 300
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.bottom: parent.bottom

        Text {
            id: speed
            height: 120
            color: "#c4c4c4"
            text: qsTr("110")
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            anchors.right: parent.right
            anchors.left: parent.left
            font.pixelSize: 72
        }

        CircularGauge {
            id: rpm
            height: 240
            stepSize: 0
            value: applicationData.rpm
            maximumValue: 8000
            anchors.right: parent.right
            anchors.left: parent.left

            style: CircularGaugeStyle {
                tickmarkStepSize: 1000
                background: Canvas {
                    Text {
                        id: gearText
                        font.pixelSize: 24
                        text: "2"
                        color: "#c4c4c4"
                        horizontalAlignment: Text.AlignRight
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.verticalCenter
                        anchors.topMargin: 40
                    }
                }
            }
        }

        Text {
            id: cons
            height: 120
            color: "#c4c4c4"
            text: qsTr("5.4 L/100km")
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            anchors.right: parent.right
            anchors.left: parent.left
            font.pixelSize: 36
        }

    }

    Item {
        id: item1
        x: 300
        y: 0
        width: 500
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.top: parent.top

        TabBar {
            id: tabBar
            x: 0
            y: 0
            currentIndex: 2
            anchors.left: parent.left
            anchors.right: parent.right

            TabButton {
                id: music
                text: qsTr("Music")
            }

            TabButton {
                id: gps
                text: qsTr("GPS")
            }

            TabButton {
                id: carstatus
                text: "Status"
            }
        }

        StackLayout {
            id: stackLayout
            x: 0
            y: 40
            anchors.top: parent.top
            anchors.topMargin: 40
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.left: parent.left
            currentIndex: tabBar.currentIndex

            Item {
                Layout.fillHeight: true
                Layout.fillWidth: true
                Text {
                    id: musicText
                    color: "#c4c4c4"
                    text: qsTr("Not implemented yet :(")
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                    anchors.fill: parent
                    font.pixelSize: 12
                }
            }

            Item {
                Layout.fillHeight: true
                Layout.fillWidth: true
                Text {
                    id: gpsText
                    color: "#c4c4c4"
                    text: qsTr("Not implemented yet :(")
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                    anchors.fill: parent
                    font.pixelSize: 12
                }
            }

            Item {
                Layout.fillHeight: true
                Layout.fillWidth: true

                Button {
                    id: errorCodeButton
                    x: -75
                    y: -20
                    width: 150
                    text: qsTr("Check for error codes")
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    font.weight: Font.Thin
                }
            }
        }
    }
}
