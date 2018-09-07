import QtQuick 2.11
import QtQuick.Window 2.11
import QtQuick.Controls 2.3
import QtQuick.Extras 1.4
import QtQuick.Layouts 1.3
import QtQuick.Controls.Styles 1.4
import QtQuick.Dialogs 1.3

Window {

	signal checkErrorCodes()
    signal clearErrorCodes()

    function checkErrorCodesDone(text) {
        console.log("checkEngineDone: " + text)
        errorCodeResponseText.text = text
        errorCodeResponseText.visible = true
        
        if(text != "") {
			clearErrorCodesButton.visible = true
        }
    }

    function clearErrorCodesDone(text) {
        console.log("clearEngineDone: " + text)
        errorCodeResponseText.text = text
        errorCodeResponseText.visible = true
    }

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
    title: qsTr("Dashboard")

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
            text: applicationData.speed
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
            maximumValue: 8
            anchors.right: parent.right
            anchors.left: parent.left
            
            Behavior on value{
                NumberAnimation { duration: 250; easing.type: Easing.Linear }
            }

            style: CircularGaugeStyle {
                tickmarkStepSize: 1
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
            text: applicationData.ic.toFixed(2) + " L/100km"
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

                ScrollView {
                    id: statusScroll
                    clip: true
                    anchors.fill: parent

                    Column {
                        id: statusColumn
                        width: 500
                        spacing: 5

                        Text {
                            id: checkCodeTitle
                            color: "#c4c4c4"
                            text: qsTr("Engine status")
                            visible: true
                            padding: 10
                            font.pixelSize: 16
                        }

                        Text {
                            id: cannotCheckCodes
                            color: "#c4c4c4"
							text: qsTr("On board diagnostics are only available when the car is stopped")
							horizontalAlignment: Text.AlignHCenter
							font.pixelSize: 24
							anchors.left: parent.left
							anchors.right: parent.right
							wrapMode: Text.WordWrap
                            visible: speed.text != 0
                        }

                        Column {
                            id: canCheckCodes
                            width: 500
                            visible: speed.text == 0
                            
                            Button {
                                id: checkErrorCodeButton
                                text: qsTr("Check for error codes")
                                visible: true
                                anchors.horizontalCenter: parent.horizontalCenter
                                
                                onClicked: {
									checkErrorCodes()
								}
                            }

                            Text {
                                id: errorCodeResponseText
                                color: "#c4c4c4"
                                text: qsTr("Check engine is ON\nError code(s):\n\nC1600")
                                horizontalAlignment: Text.AlignHCenter
                                padding: 5
                                anchors.left: parent.left
								anchors.right: parent.right
                                font.pixelSize: 12
                                visible: false
                            }

                            Button {
                                id: clearErrorCodesButton
                                anchors.horizontalCenter: parent.horizontalCenter
								text: qsTr("Clear error codes")
								visible: false

								onClicked: {
									messageDialog.open()
								}
                            }
                            
                            MessageDialog {
								id: messageDialog
								title: "Confirm error code removal"
								text: "If you erase the error codes, you will not be able to query them anymore. Confirm removal?"
								standardButtons: StandardButton.Yes | StandardButton.No
								onYes: {
									clearErrorCodes()
								}
							}
                        }
                    }
                }
            }
        }
    }
}
