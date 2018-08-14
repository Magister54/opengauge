import QtQuick 2.7
import QtQuick.Window 2.2
import QtQuick.Layouts 1.3
import QtQuick.Extras 1.4
import QtQuick.Controls.Styles 1.4

Window {
    visible: true
    title: "Hello World"
    //visibility: Window.FullScreen
    
    Shortcut {
		sequence: "Escape"
		onActivated: visibility = Window.Windowed
	}

    ColumnLayout {

        CircularGauge {
            value: applicationData.rpm
            maximumValue: 8000

            style: CircularGaugeStyle {
                tickmarkStepSize: 1000
                tickmarkLabel: Text {
                    text: styleData.value
                }
            }
        }
    }
}
