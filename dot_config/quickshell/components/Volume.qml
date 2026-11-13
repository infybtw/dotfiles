import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import "../Theme.js" as Theme

Item {
  id: root

  property var panelWindow

  readonly property var sink: Pipewire.defaultAudioSink
  readonly property var audio: sink ? sink.audio : null
  readonly property int percent: audio ? Math.round(audio.volume * 100) : 0
  readonly property bool muted: audio ? audio.muted : false

  readonly property bool isBluetooth: {
    if (!sink)
      return false
    const bus = sink.properties ? (sink.properties["device.bus"] || "") : ""
    const name = (sink.name || "").toLowerCase()
    return bus === "bluetooth" || name.indexOf("bluez") !== -1
  }

  readonly property bool isHeadset: {
    if (!sink || !sink.properties)
      return false
    const iconName = (sink.properties["device.icon-name"] || "").toLowerCase()
    return iconName.indexOf("headset") !== -1 || iconName.indexOf("headphone") !== -1
  }

  readonly property string displayText: {
    if (!sink)
      return Theme.iconVolumeMuted
    if (muted)
      return isBluetooth ? Theme.iconVolumeMuted + " " + Theme.iconBluetooth : Theme.iconVolumeMuted

    let icon = Theme.iconVolumeHigh
    if (isHeadset)
      icon = Theme.iconHeadset
    else if (percent <= 33)
      icon = Theme.iconVolumeLow
    else if (percent <= 66)
      icon = Theme.iconVolumeMedium

    if (isBluetooth)
      return icon + " " + Theme.iconBluetooth + " " + percent + "%"
    return icon + " " + percent + "%"
  }

  readonly property string tooltipText: {
    if (!sink)
      return "No output device"
    let text = sink.description || sink.name || "Audio output"
    text += "\nVolume: " + percent + "%"
    if (muted)
      text += "\nMuted"
    if (isBluetooth)
      text += "\nBluetooth"
    return text
  }

  implicitWidth: label.implicitWidth
  implicitHeight: 22

  PwObjectTracker {
    objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
  }

  Text {
    id: label

    anchors.centerIn: parent
    text: root.displayText
    color: Theme.volumeColor
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    font.weight: Font.ExtraBold
  }

  HoverHandler {
    id: hover

    onHoveredChanged: tip.shown = hovered
  }

  WheelHandler {
    acceptedDevices: PointerDevice.Mouse
    onWheel: event => {
      if (!root.audio)
        return
      const step = event.angleDelta.y > 0 ? 0.05 : -0.05
      root.audio.volume = Math.max(0, Math.min(1, root.audio.volume + step))
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: Quickshell.execDetached(["pavucontrol"])
  }

  Tooltip {
    id: tip

    panelWindow: root.panelWindow
    target: label
    text: root.tooltipText
  }
}
