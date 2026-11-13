import QtQuick
import Quickshell
import "../Theme.js" as Theme

PopupWindow {
  id: root

  property var panelWindow
  property Item target
  property date monthDate: new Date()
  property var cells: []

  visible: false
  color: "transparent"
  implicitWidth: 238
  implicitHeight: 214
  anchor.window: panelWindow

  function rebuild() {
    const year = monthDate.getFullYear()
    const month = monthDate.getMonth()
    const firstDay = new Date(year, month, 1)
    const offset = (firstDay.getDay() + 6) % 7 // Monday = 0
    const dayCount = new Date(year, month + 1, 0).getDate()
    const today = new Date()
    const todayYear = today.getFullYear()
    const todayMonth = today.getMonth()
    const todayDate = today.getDate()

    const result = []
    for (let i = 0; i < offset; i++)
      result.push({ day: "", today: false })
    for (let day = 1; day <= dayCount; day++)
      result.push({
        day: String(day),
        today: day === todayDate && month === todayMonth && year === todayYear
      })
    while (result.length % 7 !== 0)
      result.push({ day: "", today: false })

    cells = result
  }

  onMonthDateChanged: rebuild()
  Component.onCompleted: rebuild()

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
    anchors.fill: parent
    color: Theme.tooltipBackground
    radius: 8
    border.width: 1
    border.color: Theme.barBorder

    Column {
      anchors.fill: parent
      anchors.margins: 10
      spacing: 6

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatDateTime(root.monthDate, "MMMM yyyy")
        color: Theme.tooltipForeground
        font.family: Theme.fontFamily
        font.pixelSize: 12
        font.weight: Font.ExtraBold
      }

      Grid {
        anchors.horizontalCenter: parent.horizontalCenter
        columns: 7
        columnSpacing: 2
        rowSpacing: 1

        Repeater {
          model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

          delegate: Text {
            required property string modelData

            width: 29
            text: modelData
            color: "#9399b2"
            horizontalAlignment: Text.AlignHCenter
            font.family: Theme.fontFamily
            font.pixelSize: 10
            font.weight: Font.Bold
          }
        }

        Repeater {
          model: root.cells

          delegate: Text {
            required property var modelData

            width: 29
            height: 18
            text: modelData.day
            color: modelData.today ? Theme.red : Theme.fg
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.weight: modelData.today ? Font.ExtraBold : Font.Bold
          }
        }
      }
    }
  }
}
