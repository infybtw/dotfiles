import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "../Theme.js" as Theme

Row {
  id: root

  property var panelWindow

  spacing: 6

  Repeater {
    model: SystemTray.items

    delegate: Item {
      id: trayItem

      required property var modelData

      width: 16
      height: 22

      Image {
        anchors.centerIn: parent
        width: 15
        height: 15
        source: trayItem.modelData.icon
        sourceSize.width: 15
        sourceSize.height: 15
        fillMode: Image.PreserveAspectFit
        smooth: true
        asynchronous: true
      }

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
          if (!root.panelWindow)
            return

          if (mouse.button === Qt.RightButton) {
            trayItem.modelData.secondaryActivate()
            return
          }

          if (trayItem.modelData.hasMenu) {
            const point = mapToItem(root.panelWindow.contentItem, mouse.x, mouse.y)
            trayItem.modelData.display(root.panelWindow, Math.round(point.x), Math.round(point.y))
          } else {
            trayItem.modelData.activate()
          }
        }
      }
    }
  }
}
