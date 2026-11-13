import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../Theme.js" as Theme

Item {
  id: root

  property string mainKeyboard: ""
  property string currentLayout: ""

  implicitWidth: label.implicitWidth
  implicitHeight: 22

  function displayForLayout(layout, index) {
    if (!layout)
      return ""
    const parts = layout.split(",")
    return displayForCode(parts[index] || parts[0] || "")
  }

  function displayForCode(code) {
    const normalized = (code || "").trim().toLowerCase()
    if (normalized === "ru")
      return "RUS"
    if (normalized === "us" || normalized === "gb")
      return "ENG"
    return normalized.toUpperCase()
  }

  function displayForKeymap(keymap) {
    const normalized = (keymap || "").trim().toLowerCase()
    if (normalized.indexOf("russian") !== -1)
      return "RUS"
    if (normalized.indexOf("english") !== -1)
      return "ENG"
    return (keymap || "").trim().toUpperCase()
  }

  Process {
    id: initProcess

    running: true
    command: ["hyprctl", "-j", "devices"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const data = JSON.parse(this.text)
          const keyboards = data.keyboards || []
          const main = keyboards.find(keyboard => keyboard.main) || keyboards[0]
          if (!main)
            return
          root.mainKeyboard = main.name || ""
          root.currentLayout = root.displayForLayout(main.layout, main.active_layout_index || 0)
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

      const parts = event.data.split(",")
      if (parts.length < 2)
        return

      const keyboardName = parts[0]
      if (root.mainKeyboard.length > 0 && keyboardName !== root.mainKeyboard)
        return

      root.currentLayout = root.displayForKeymap(parts.slice(1).join(","))
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
