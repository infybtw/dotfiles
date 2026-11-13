import QtQuick
import Quickshell
import Quickshell.Io
import "../Theme.js" as Theme

Item {
  id: root

  property var panelWindow
  property real percent: 0
  property string tooltipText: ""

  implicitWidth: label.implicitWidth
  implicitHeight: 22

  function gib(kib) {
    return (kib / 1024.0 / 1024.0).toFixed(1) + " GiB"
  }

  function sample(raw) {
    const data = {}
    const lines = raw.split("\n")

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i]
      const separator = line.indexOf(":")
      if (separator === -1)
        continue
      const key = line.substring(0, separator)
      const value = parseInt(line.substring(separator + 1).trim())
      if (!isNaN(value))
        data[key] = value
    }

    const total = data.MemTotal || 0
    const available = data.MemAvailable || 0
    const used = Math.max(0, total - available)
    root.percent = total > 0 ? used * 100 / total : 0
    root.tooltipText = [
      "Used: " + gib(used) + " (" + root.percent.toFixed(1) + "%)",
      "Available: " + gib(available),
      "Total: " + gib(total)
    ].join("\n")
  }

  FileView {
    id: memFile

    path: "/proc/meminfo"
    blockLoading: true
    onTextChanged: root.sample(memFile.text())
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: memFile.reload()
  }

  Text {
    id: label

    anchors.centerIn: parent
    text: Theme.iconMemory + " " + Math.round(root.percent) + "%"
    color: Theme.memoryColor
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    font.weight: Font.ExtraBold
  }

  HoverHandler {
    id: hover

    onHoveredChanged: tip.shown = hovered
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: Quickshell.execDetached(["ghostty", "-e", "btop"])
  }

  Tooltip {
    id: tip

    panelWindow: root.panelWindow
    target: label
    text: root.tooltipText
  }
}
