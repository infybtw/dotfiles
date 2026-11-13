import QtQuick
import Quickshell
import Quickshell.Io
import "../Theme.js" as Theme

Item {
  id: root

  property var panelWindow
  property int count: 0
  property string stateClass: "none"
  property string notificationTooltip: ""

  readonly property bool doNotDisturb: stateClass.indexOf("dnd") !== -1
    || stateClass.indexOf("inhibited") !== -1
  readonly property bool hasNotifications: stateClass.indexOf("notification") !== -1 || count > 0

  readonly property string tooltipText: {
    if (notificationTooltip.length > 0)
      return notificationTooltip
    let text = "Notifications: " + count
    if (doNotDisturb)
      text += "\nDo Not Disturb"
    return text
  }

  implicitWidth: 16
  implicitHeight: 22

  function applyState(raw) {
    try {
      const data = JSON.parse(raw)
      root.count = parseInt(data.text) || 0
      root.stateClass = data["class"] || "none"
      root.notificationTooltip = data.tooltip || ""
    } catch (error) {
      console.warn("quickshell: failed to parse swaync state:", error)
    }
  }

  Process {
    id: swayncProcess

    running: true
    command: ["swaync-client", "-swb"]
    stdout: SplitParser {
      onRead: data => root.applyState(data)
    }
    onExited: retryTimer.start()
  }

  Timer {
    id: retryTimer

    interval: 2000
    onTriggered: swayncProcess.running = true
  }

  Text {
    anchors.centerIn: parent
    text: root.doNotDisturb ? Theme.iconBellSlash : Theme.iconBell
    color: root.doNotDisturb ? Theme.tooltipForeground : Theme.fg
    font.family: Theme.fontFamily
    font.pixelSize: 10
    font.weight: Font.ExtraBold
  }

  Rectangle {
    visible: root.hasNotifications
    width: 4
    height: 4
    radius: 2
    color: "red"
    anchors.right: parent.right
    anchors.rightMargin: 1
    anchors.top: parent.top
    anchors.topMargin: 4
  }

  HoverHandler {
    id: hover

    onHoveredChanged: tip.shown = hovered
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    onClicked: mouse => {
      if (mouse.button === Qt.RightButton)
        Quickshell.execDetached(["swaync-client", "-d", "-sw"])
      else
        Quickshell.execDetached(["swaync-client", "-t", "-sw"])
    }
  }

  Tooltip {
    id: tip

    panelWindow: root.panelWindow
    target: root
    text: root.tooltipText
  }
}
