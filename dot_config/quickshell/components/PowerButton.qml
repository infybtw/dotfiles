import QtQuick
import Quickshell
import "../Theme.js" as Theme

Item {
  id: root

  implicitWidth: label.implicitWidth
  implicitHeight: 22

  Text {
    id: label

    anchors.centerIn: parent
    text: Theme.iconPower
    color: Theme.fg
    font.family: Theme.fontFamily
    font.pixelSize: 10
    font.weight: Font.ExtraBold
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: Quickshell.execDetached(["wlogout"])
  }
}
