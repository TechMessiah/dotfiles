import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "OsdModel.js" as OsdModel

Item {
  id: root

  property bool opened: false
  property string icon: ""
  property string message: ""
  property string iconKey: ""
  property int value: 0
  property int maxValue: 100
  property bool hasProgress: true
  property int duration: 1200

  // Injected by omarchy-shell's panel loader.
  property var shell: null

  readonly property bool mediaOsd: iconKey.indexOf("media") === 0 || iconKey.indexOf("player") === 0

  // Every OSD — progress (volume/brightness) or message (media next/prev,
  // "Launching …") — shares one bottom-centre spot.
  readonly property int edgeInset: Style.space(22)

  // The card is a fixed width shared with the notification toasts
  // (techmessiah.notifications/Service.qml cardWidth) so the whole
  // bottom-centre column reads as one stack of identical cards. Content is
  // still measured column by column, but the slack now lands in the message
  // (which elides) or the progress bar (which stretches) rather than in the
  // card's own width.
  // Vertical padding is pinned: the card height (border + pad + iconSize + pad
  // + border) is the pitch the toast stack is measured off. Horizontal padding
  // is free to breathe — keep both in step with the toast card.
  readonly property int pad: Style.space(10)
  readonly property int padX: Style.space(18)
  readonly property int cardWidth: Style.space(240)
  readonly property int innerWidth: root.cardWidth - card.borderLeft - card.borderRight - root.padX * 2
  readonly property int gap: Style.space(16)
  // Icon and label pinned smaller than the shared display/title tokens. The
  // card height derives from iconSize, so both must read the same value.
  readonly property int iconSize: Style.font.iconLarge
  readonly property int textSize: Style.font.body
  // A glyph next to a message reads airier than it measures: the icon outline
  // and the letterforms both fall away from their ink extremes, so the space
  // between them opens up well past the nominal gap. Text takes two thirds of
  // it; the progress bar's hard edge keeps the full gap.
  readonly property int messageGap: Math.round(root.gap * 2 / 3)
  // The bar takes whatever the icon and the readout leave; the message takes
  // whatever the icon leaves. Both are floored at 0 so a pathological font
  // can't hand a Row a negative width.
  readonly property int barWidth: Math.max(0, root.innerWidth - root.iconWidth - root.gap * 2 - root.valueWidth)
  readonly property int maxMessageWidth: Math.max(0, root.innerWidth - root.iconWidth - root.messageGap)

  // Nerd Font glyphs draw well outside their monospace cell, so the icon
  // column is measured by ink rather than by advance width. Progress OSDs pin
  // it to the widest glyph the model can return, so the bar doesn't shift when
  // volume crosses an icon threshold.
  readonly property int iconInkWidth: Math.ceil(iconMetrics.tightBoundingRect.width)
  readonly property int iconWidth: root.hasProgress
    ? Math.max(root.iconInkWidth, Math.ceil(widestIconMetrics.tightBoundingRect.width))
    : root.iconInkWidth
  // Same idea for the readout: it is as wide as the longest percentage so the
  // digits don't jitter between 9% and 100%.
  readonly property int valueWidth: Math.ceil(Math.max(valueMetrics.advanceWidth, messageMetrics.advanceWidth))
  // Always the full remaining width rather than the text's own, so a short
  // message leaves trailing slack instead of shunting the icon off centre —
  // the same way the toast cards lay their single line out.
  readonly property int messageWidth: root.maxMessageWidth

  function iconFor(name, percent) {
    return OsdModel.iconFor(name, percent)
  }

  function show(iconName, rawMessage, rawValue, rawMax, rawProgressText, rawDuration) {
    var next = OsdModel.stateForShow(iconName, rawMessage, rawValue, rawMax, rawProgressText, rawDuration)
    // Update before opening so a fresh OSD starts at its new value; only
    // subsequent updates while it remains open animate the progress bar.
    iconKey = next.iconKey
    maxValue = next.maxValue
    hasProgress = next.hasProgress
    value = next.value
    message = next.message
    icon = next.icon
    duration = next.duration
    opened = true
    if (duration > 0) hideTimer.restart()
    else hideTimer.stop()
  }

  function open(payloadJson) {
    try {
      var p = JSON.parse(payloadJson || "{}")
      show(p.icon || "", p.message || "", p.value === undefined ? "" : String(p.value), p.max === undefined ? "100" : String(p.max), p.progressText || "", p.duration === undefined ? "1200" : String(p.duration))
    } catch (e) {}
  }

  function close() { opened = false }

  // The panel surface has to stay mapped for the whole closing spring, not
  // just while `opened` is true — otherwise the layer vanishes the instant
  // `opened` flips and the shrink-back-down never gets to play.
  property bool stayMapped: false
  onOpenedChanged: if (opened) stayMapped = true

  Timer {
    id: hideTimer
    interval: root.duration
    onTriggered: root.opened = false
  }

  TextMetrics {
    id: messageMetrics
    font.family: Style.font.family
    font.bold: true
    font.pixelSize: root.textSize
    text: root.message
  }

  TextMetrics {
    id: valueMetrics
    font: messageMetrics.font
    text: "100%"
  }

  TextMetrics {
    id: iconMetrics
    font.family: Style.font.family
    font.pixelSize: root.iconSize
    text: root.icon
  }

  TextMetrics {
    id: widestIconMetrics
    font: iconMetrics.font
    text: OsdModel.widestIcon
  }

  IpcHandler {
    target: "osd"
    function show(payloadJson: string): string {
      root.open(payloadJson)
      return "ok"
    }
    function close(): string { root.close(); return "ok" }
    function state(): string { return root.opened ? "open" : "closed" }
    function ping(): string { return "ok" }
  }

  PanelWindow {
    id: panel
    visible: root.stayMapped
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    // Visual-only surface: keep the layer-shell input region empty so the OSD
    // never blocks clicks to the desktop below it.
    mask: Region {}

    BorderSurface {
      id: card
      width: root.cardWidth
      height: card.borderTop + root.pad + root.iconSize + root.pad + card.borderBottom
      // The message-style OSD — the "Launching …" card — shares the top-right
      // corner with the notification toasts, which hang beneath it. Progress
      // OSDs (volume, brightness, night light) keep their own bottom-centre
      // spot so a volume tap never shoves the toast stack around.
      anchors.top: parent.top
      anchors.right: parent.right
      anchors.topMargin: Math.max(0, panel.height - card.height - root.edgeInset)
      anchors.rightMargin: Math.round((panel.width - card.width) / 2)
      color: Util.alpha(Color.background, 0.97)
      // Faint see-through white, matching the notification cards' border.
      borderSpec: Border.flat(Qt.rgba(1, 1, 1, 0.12), 1)
      // Fully rounded (pill), matching volume/brightness style.
      radius: card.height / 2
      opacity: root.opened ? 1 : 0
      // Dynamic Island feel: the pill springs open from a squeezed-down
      // capsule rather than just fading in, and snaps shut the same way.
      // A real spring (not eased duration) gives the little overshoot
      // bounce that reads as "material", growing from the bottom edge
      // since that's the edge this pill lives against.
      transformOrigin: Item.Bottom
      scale: root.opened ? 1 : 0.6
      Behavior on scale {
        SpringAnimation {
          spring: 4
          damping: 0.4
          onRunningChanged: if (!running && !root.opened) root.stayMapped = false
        }
      }
      Behavior on opacity {
        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
      }

      Row {
        anchors.fill: parent
        anchors.topMargin: card.borderTop + root.pad
        anchors.rightMargin: card.borderRight + root.padX
        anchors.bottomMargin: card.borderBottom + root.pad
        anchors.leftMargin: card.borderLeft + root.padX
        spacing: root.hasProgress ? root.gap : root.messageGap
        Item {
          width: root.iconWidth
          height: parent.height
          Text {
            // Sit the glyph's ink flush in the column, centered when the
            // column is wider than this particular glyph.
            x: Math.round((root.iconWidth - root.iconInkWidth) / 2 - iconMetrics.tightBoundingRect.x)
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            font: iconMetrics.font
            color: Color.popups.text
          }
        }
        Rectangle {
          visible: root.hasProgress
          width: root.barWidth
          height: Math.max(Style.space(6), Style.spacing.sm)
          anchors.verticalCenter: parent.verticalCenter
          radius: height / 2
          color: Util.alpha(Color.popups.text, 0.45)
          clip: true
          Rectangle {
            height: parent.height
            width: parent.width * (root.hasProgress ? root.value / root.maxValue : 0)
            radius: parent.radius
            color: Color.accent

            Behavior on width {
              enabled: root.opened
              NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
            }
          }
        }
        Text {
          visible: root.message !== ""
          width: root.hasProgress ? root.valueWidth : root.messageWidth
          // The readout hugs the card edge so a short percentage doesn't leave
          // a hole in the padding; the slack lands in the gap after the bar.
          horizontalAlignment: root.hasProgress ? Text.AlignRight : Text.AlignLeft
          anchors.verticalCenter: parent.verticalCenter
          text: root.message
          font: messageMetrics.font
          color: Color.popups.text
          elide: Text.ElideRight
          maximumLineCount: 1
        }
      }
    }
  }
}
