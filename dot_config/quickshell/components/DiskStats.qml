import QtQuick
import Quickshell
import Quickshell.Io
import "../Theme.js" as Theme

Item {
  id: root

  property var panelWindow
  property int freePercent: 0
  property string tooltipText: ""

  implicitWidth: label.implicitWidth
  implicitHeight: 22

  function sample(raw) {
    const lines = raw.trim().split("\n")
    if (lines.length < 2)
      return

    const fields = lines[1].trim().split(/\s+/)
    if (fields.length < 6)
      return

    const usedPercent = parseInt(fields[4].replace("%", ""))
    if (isNaN(usedPercent))
      return

    root.freePercent = Math.max(0, 100 - usedPercent)
    root.tooltipText = [
      "Filesystem: " + fields[0],
      "Size: " + fields[1],
      "Used: " + fields[2],
      "Available: " + fields[3],
      "Usage: " + fields[4]
    ].join("\n")
  }

  Process {
    id: dfProcess

    command: ["df", "-h", "/"]
    stdout: StdioCollector {
      onStreamFinished: root.sample(this.text)
    }
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: dfProcess.running = true
  }

  Text {
    id: label

    anchors.centerIn: parent
    text: root.freePercent + "% " + Theme.iconDisk
    color: Theme.diskColor
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    font.weight: Font.ExtraBold
  }

  HoverHandler {
    id: hover

    onHoveredChanged: tip.shown = hovered
  }

  Tooltip {
    id: tip

    panelWindow: root.panelWindow
    target: label
    text: root.tooltipText
  }
}
