import QtQuick
import Quickshell
import "../Theme.js" as Theme

PopupWindow {
  id: root

  property var panelWindow
  property Item target
  property string text
  property bool shown: false

  visible: shown && text.length > 0
  color: "transparent"
  implicitWidth: bubble.width
  implicitHeight: bubble.height
  anchor.window: panelWindow

  anchor.rect.x: {
    if (!target || !panelWindow)
      return 0
    const point = target.mapToItem(panelWindow.contentItem, target.width / 2, 0)
    const desired = point.x - width / 2
    return Math.round(Math.max(6, Math.min(panelWindow.width - width - 6, desired)))
  }

  anchor.rect.y: {
    if (!target)
      return 34
    return Math.round(target.mapToItem(panelWindow.contentItem, 0, target.height).y + 6)
  }

  Rectangle {
    id: bubble

    width: label.implicitWidth + 18
    height: label.implicitHeight + 10
    color: Theme.tooltipBackground
    radius: 6
    border.width: 1
    border.color: Theme.barBorder

    Text {
      id: label

      anchors.centerIn: parent
      text: root.text
      color: Theme.tooltipForeground
      textFormat: Text.PlainText
      font.family: Theme.fontFamily
      font.pixelSize: 11
      font.weight: Font.Medium
    }
  }
}
