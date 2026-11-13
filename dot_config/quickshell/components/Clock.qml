import QtQuick
import "../Theme.js" as Theme

Item {
  id: root

  property var panelWindow

  property date currentTime: new Date()

  implicitWidth: label.implicitWidth
  implicitHeight: 22

  Timer {
    interval: 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.currentTime = new Date()
  }

  Text {
    id: label

    anchors.centerIn: parent
    text: Qt.formatDateTime(root.currentTime, "dd.MM - HH:mm:ss")
    color: Theme.fg
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    font.weight: Font.ExtraBold
  }

  HoverHandler {
    id: hover

    onHoveredChanged: {
      if (hovered) {
        calendar.monthDate = new Date()
        calendar.visible = true
      } else {
        calendar.visible = false
      }
    }
  }

  CalendarPopup {
    id: calendar

    panelWindow: root.panelWindow
    target: label
  }
}
