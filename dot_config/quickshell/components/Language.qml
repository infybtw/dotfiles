import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../Theme.js" as Theme

Item {
  id: root

  property string currentLayout: ""
  property bool hasLiveUpdate: false

  implicitWidth: label.implicitWidth
  implicitHeight: 22

  function layoutLabel(value) {
    const normalized = (value || "").trim().toLowerCase()
    if (normalized === "ru" || normalized.indexOf("russian") !== -1)
      return "RUS"
    if (normalized === "us" || normalized === "gb" || normalized === "en"
        || normalized.indexOf("english") !== -1)
      return "ENG"
    return (value || "").trim().toUpperCase()
  }

  function applyKeymap(keymap) {
    const label = layoutLabel(keymap)
    if (!label || label === "ERROR")
      return
    root.currentLayout = label
  }

  // Initial state only. Once a live event arrives it must not overwrite it
  // with the stale result of this one-shot query.
  Process {
    id: initProcess

    running: true
    command: ["hyprctl", "-j", "devices"]
    stdout: StdioCollector {
      onStreamFinished: {
        if (root.hasLiveUpdate)
          return
        try {
          const data = JSON.parse(this.text)
          const keyboards = data.keyboards || []
          const main = keyboards.find(keyboard => keyboard.main) || keyboards[0]
          if (!main)
            return
          if (main.active_keymap)
            root.applyKeymap(main.active_keymap)
          else {
            const parts = (main.layout || "").split(",")
            root.applyKeymap(parts[main.active_layout_index || 0] || parts[0] || "")
          }
        } catch (error) {
          console.warn("quickshell: failed to read keyboard layout:", error)
        }
      }
    }
  }

  Connections {
    target: Hyprland

    function onRawEvent(event) {
      if (event.name !== "activelayout")
        return

      // Hyprland sends the name of the device that performed the switch,
      // which is not necessarily the one flagged "main" in `hyprctl devices`
      // (e.g. by-tech-gaming-keyboard-1). Filtering by device name would drop
      // those events, so use the keymap from the event itself.
      const parts = event.data.split(",")
      if (parts.length < 2)
        return

      root.applyKeymap(parts.slice(1).join(","))
      root.hasLiveUpdate = true
    }
  }

  Text {
    id: label

    anchors.centerIn: parent
    text: root.currentLayout
    color: Theme.fg
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    font.weight: Font.ExtraBold
  }
}
