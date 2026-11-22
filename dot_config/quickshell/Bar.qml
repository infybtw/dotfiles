import QtQuick
import Quickshell
import Quickshell.Wayland
import "components"
import "Theme.js" as Theme

PanelWindow {
  id: root

  anchors {
    top: true
    left: true
    right: true
  }

  // Waybar used 3px top/bottom and 6px left/right margins, with a 28px bar.
  // 34px of exclusive zone reproduces the old reserved area exactly.
  margins {
    top: 3
    left: 6
    right: 6
  }

  implicitHeight: 28
  exclusiveZone: 31
  color: "transparent"

  Rectangle {
    anchors.fill: parent
    radius: 10
    color: Theme.barBackground
    border.width: 1
    border.color: Theme.barBorder
    antialiasing: true

    Row {
      anchors.left: parent.left
      anchors.leftMargin: 8
      anchors.verticalCenter: parent.verticalCenter
      spacing: 3

      Workspaces {
        panelWindow: root
      }
    }

    Clock {
      anchors.centerIn: parent
      panelWindow: root
    }

    Row {
      anchors.right: parent.right
      anchors.rightMargin: 12
      anchors.verticalCenter: parent.verticalCenter
      spacing: 8

      Language {}
      CpuStats { panelWindow: root }
      GpuStats { panelWindow: root }
      MemoryStats { panelWindow: root }
      DiskStats { panelWindow: root }
      Volume { panelWindow: root }
      Tray { panelWindow: root }
      Notifications { panelWindow: root }
      PowerButton {}
    }
  }
}
