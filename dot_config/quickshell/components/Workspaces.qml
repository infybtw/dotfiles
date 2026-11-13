import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../Theme.js" as Theme

Row {
  id: root

  property var panelWindow

  readonly property var persistentWorkspaces: ({
    "DP-1": [1, 2, 3, 4, 5, 6],
    "HDMI-A-1": [7, 8, 9, 10]
  })

  readonly property var workspaceIds: {
    const screenName = panelWindow && panelWindow.screen ? panelWindow.screen.name : ""
    return persistentWorkspaces[screenName] || [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
  }

  readonly property var hyprMonitor: panelWindow && panelWindow.screen
    ? Hyprland.monitorFor(panelWindow.screen)
    : null

  spacing: 3

  function dispatchWorkspace(id) {
    if (Hyprland.usingLua)
      Hyprland.dispatch(`hl.dsp.focus({ workspace = "${id}" })`)
    else
      Hyprland.dispatch("workspace " + id)
  }

  function dispatchRelative(direction) {
    const workspace = direction > 0 ? "e+1" : "e-1"
    if (Hyprland.usingLua)
      Hyprland.dispatch(`hl.dsp.focus({ workspace = "${workspace}" })`)
    else
      Hyprland.dispatch("workspace " + workspace)
  }

  Repeater {
    model: root.workspaceIds

    delegate: Item {
      id: workspaceButton

      required property int modelData

      width: 14
      height: 22

      readonly property var workspace: Hyprland.workspaces.values.find(ws => ws.id === modelData)
      readonly property bool active: root.hyprMonitor !== null
        && root.hyprMonitor.activeWorkspace !== null
        && root.hyprMonitor.activeWorkspace === workspace
      readonly property bool onThisMonitor: workspace !== undefined
        && workspace.monitor === root.hyprMonitor

      Text {
        anchors.centerIn: parent
        text: workspaceButton.active
          ? Theme.iconWorkspaceActive
          : (workspaceButton.onThisMonitor ? Theme.iconWorkspaceOccupied : Theme.iconWorkspaceEmpty)
        color: Theme.fg
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        font.weight: Font.ExtraBold
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          if (workspaceButton.workspace)
            workspaceButton.workspace.activate()
          else
            root.dispatchWorkspace(workspaceButton.modelData)
        }
      }
    }
  }

  WheelHandler {
    acceptedDevices: PointerDevice.Mouse
    onWheel: event => {
      if (event.angleDelta.y > 0)
        root.dispatchRelative(1)
      else if (event.angleDelta.y < 0)
        root.dispatchRelative(-1)
    }
  }
}
