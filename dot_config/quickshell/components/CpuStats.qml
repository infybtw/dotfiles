import QtQuick
import Quickshell
import Quickshell.Io
import "../Theme.js" as Theme

Item {
  id: root

  property var panelWindow
  property real usage: 0
  property real temperature: -1
  property var coreUsages: []
  property var previousSample: null
  property string tempPath: ""
  property string tooltipText: ""

  implicitWidth: label.implicitWidth
  implicitHeight: 22

  function usageBetween(previous, current) {
    const totalDelta = current.total - previous.total
    if (totalDelta <= 0)
      return 0
    const idleDelta = current.idle - previous.idle
    return Math.max(0, Math.min(100, (totalDelta - idleDelta) * 100 / totalDelta))
  }

  function sample(raw) {
    const lines = raw.split("\n")
    let totalSample = null
    const cores = []

    for (let i = 0; i < lines.length; i++) {
      const match = lines[i].match(/^cpu(\d*)\s+(.+)$/)
      if (!match)
        continue

      const values = match[2].trim().split(/\s+/).map(Number)
      const total = values.reduce((sum, value) => sum + (isNaN(value) ? 0 : value), 0)
      const idle = (values[3] || 0) + (values[4] || 0)
      const entry = { index: match[1] === "" ? -1 : Number(match[1]), total: total, idle: idle }

      if (entry.index === -1)
        totalSample = entry
      else
        cores.push(entry)
    }

    if (!totalSample)
      return

    const previous = root.previousSample
    root.usage = previous ? usageBetween(previous.total, totalSample) : 0

    const usages = []
    for (let i = 0; i < cores.length; i++) {
      const core = cores[i]
      let previousCore = null
      if (previous) {
        for (let j = 0; j < previous.cores.length; j++) {
          if (previous.cores[j].index === core.index) {
            previousCore = previous.cores[j]
            break
          }
        }
      }
      usages.push({
        index: core.index,
        usage: previousCore ? usageBetween(previousCore, core) : 0
      })
    }

    root.coreUsages = usages
    root.previousSample = { total: totalSample, cores: cores }
    rebuildTooltip()
  }

  function updateTemperature(raw) {
    const value = parseFloat(raw)
    root.temperature = isFinite(value) ? value / 1000 : -1
    rebuildTooltip()
  }

  function rebuildTooltip() {
    const lines = [
      "Total: " + root.usage.toFixed(1) + "%",
      "Temp: " + (root.temperature > 0 ? root.temperature.toFixed(1) + " C" : "N/A"),
      "",
      "Per-core usage:"
    ]

    const chunks = []
    for (let i = 0; i < root.coreUsages.length; i++) {
      const core = root.coreUsages[i]
      chunks.push("C" + core.index + ":" + core.usage.toFixed(1).padStart(4) + "%")
    }
    for (let i = 0; i < chunks.length; i += 4)
      lines.push(chunks.slice(i, i + 4).join("  "))

    root.tooltipText = lines.join("\n")
  }

  FileView {
    id: statFile

    path: "/proc/stat"
    blockLoading: true
    onTextChanged: root.sample(statFile.text())
  }

  Process {
    id: tempPathProcess

    running: true
    command: ["sh", "-c", "for d in /sys/class/hwmon/hwmon*; do n=$(cat \"$d/name\" 2>/dev/null); case \"$n\" in coretemp|k10temp|zenpower) f=$(ls \"$d\"/temp*_input 2>/dev/null | head -n 1); if [ -n \"$f\" ]; then echo \"$f\"; exit 0; fi;; esac; done"]
    stdout: StdioCollector {
      onStreamFinished: root.tempPath = this.text.trim()
    }
  }

  FileView {
    id: tempFile

    path: root.tempPath
    blockLoading: true
    onTextChanged: root.updateTemperature(tempFile.text())
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      statFile.reload()
      if (root.tempPath.length > 0)
        tempFile.reload()
    }
  }

  Text {
    id: label

    anchors.centerIn: parent
    text: Theme.iconCpu + " " + Math.round(root.usage) + "%"
    color: Theme.cpuColor
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
