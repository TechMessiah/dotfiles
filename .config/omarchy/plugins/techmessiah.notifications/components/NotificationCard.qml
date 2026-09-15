// Notification card. Pure presentational — no service, Notification, or
// ListModel references. The popup container drives lifetime; the history
// panel drives static rendering. Both use the same component.

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import qs.Commons
import qs.Ui
import "../NotificationLogic.js" as NotificationLogic

BorderSurface {
  id: root

  property string app: ""
  property string appIcon: ""
  property string summary: ""
  property string body: ""
  property string image: ""
  // Nerd Font glyph rendered in the icon slot when no real icon is set.
  // Used by omarchy-notification-send so user-action toasts (`Silenced
  // notifications` etc.) show their bell/lock/etc. glyph without leaking
  // into the summary text.
  property string glyph: ""
  // NotificationUrgency: Low=0, Normal=1, Critical=2 (upstream).
  property int urgency: 1
  property double timestamp: 0

  // Shape and metrics mirror the OSD pill (techmessiah.osd/Osd.qml) so a toast
  // and a "Launching …" pill read as the same object in the same spot. Keep the
  // two in step if either is retuned.
  // Even padding on all four sides — the right side adds the close button's
  // own footprint on top so the text never runs under it.
  readonly property int pad: Style.space(14)
  // Fallback size for the compact-glyph path only — the real icon tile
  // stretches to match the text stack's height instead (see smallIconSlot).
  readonly property int iconSize: Style.space(32)
  readonly property int textSize: Style.font.body
  // The OSD's messageGap: a glyph beside text reads airier than it measures.
  readonly property int iconGap: Math.round(Style.space(16) * 2 / 3)
  readonly property int closeButtonSize: Style.space(22)
  // Fixed, and the same for every toast and the OSD pill, so the deck reads as
  // one stack of identical cards. Overridden by the container. Text elides.
  property int cardWidth: Style.space(300)

  // System monospace font injected by the container.
  property string fontFamily: ""

  readonly property bool hovered: hoverTracker.hovered

  signal closeRequested()
  signal cardClicked()
  // Prefer per-notification media/avatar data, then fall back to the app icon.
  // The `check` flag avoids Qt's missing-texture placeholder for unknown names.
  readonly property string smallIconSource: image.length > 0 ? image : iconSource(appIcon)
  readonly property bool hasGlyph: glyph.length > 0
  // Every toast is one elided line now, so the compact-glyph path is always on
  // the table.
  readonly property bool compactGlyph: NotificationLogic.shouldRenderCompactGlyph(glyph, smallIconSource, true)
  readonly property bool hasSmallIcon: smallIconSource.length > 0
  readonly property bool summaryStartsWithGlyph: NotificationLogic.summaryStartsWithGlyph(summary)
  // Only meaningful while the summary is what's on screen — a body pushes the
  // summary (and its leading glyph) out of view entirely.
  readonly property bool collapseRedundantIcon: !hasGlyph && !showsBody && summaryStartsWithGlyph
  readonly property string sanitizedBody: sanitizeBody(body)

  readonly property bool showsBody: sanitizedBody.length > 0
  // macOS-style layout: title (summary) and body render as separate rows.
  // Body is clamped to one line, so a multi-line body collapses onto it
  // (space-joined) instead of an embedded <br> getting cut mid-break.
  readonly property string displayBody: sanitizedBody
    .replace(/\r\n|\r|\n/g, " ")

  readonly property color dimColor: Qt.darker(Color.notifications.text, 1.4)
  readonly property color accentColor: urgency === 2 ? Color.urgent : (urgency === 0 ? dimColor : Color.notifications.countdown)
  // Faint, see-through white, matching the icon tile's ring.
  readonly property var cardBorderSpec: Border.flat(Qt.rgba(1, 1, 1, 0.12), 1)

  function sanitizeBody(s) {
    return NotificationLogic.sanitizeBody(s, app, appIcon)
  }

  function iconSource(icon) {
    var value = String(icon || "")
    if (value.length === 0) return ""
    if (value.indexOf("file://") === 0 || value.indexOf("image://") === 0) return value
    if (value.charAt(0) === "/") return Util.fileUrl(value)
    return Quickshell.iconPath(value, true)
  }

  implicitWidth: root.cardWidth
  // Add vertical border insets so mainColumn (inset by border on top/left/right)
  // doesn't push content under the bottom edge.
  implicitHeight: mainColumn.implicitHeight + borderTop + borderBottom
  // Rounded, solid card — translucent looked messy once cards started
  // overlapping in the Sonner-style stack (one card showing through another).
  radius: Style.space(14)
  color: Color.notifications.background
  borderSpec: cardBorderSpec
  clip: true

  HoverHandler { id: hoverTracker }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: function(mouse) {
      if (mouse.button === Qt.RightButton) {
        root.closeRequested()
      } else {
        root.cardClicked()
      }
    }
  }

  ColumnLayout {
    id: mainColumn
    // Inset by the card border so the content doesn't paint over the card's
    // outer border.
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.topMargin: root.borderTop
    anchors.leftMargin: root.borderLeft
    anchors.rightMargin: root.borderRight
    spacing: 0

    // Text content.
    RowLayout {
      Layout.fillWidth: true
      Layout.leftMargin: root.pad
      Layout.rightMargin: root.pad + root.closeButtonSize
      Layout.topMargin: root.pad
      Layout.bottomMargin: root.pad
      spacing: root.collapseRedundantIcon ? 0 : root.iconGap

      Item {
        id: smallIconSlot
        // Fills the row's full height (driven by the text stack beside it)
        // while staying square, instead of a fixed icon size.
        Layout.fillHeight: visible
        Layout.preferredWidth: visible ? height : 0
        Layout.alignment: Qt.AlignTop
        // Hide the slot when the icon failed to resolve (themed-icon name
        // not in the user's icon theme) AND we don't have a glyph fallback
        // — prevents rendering Qt's pink broken-image placeholder.
        visible: !root.collapseRedundantIcon && !root.compactGlyph && (root.hasSmallIcon || root.hasGlyph) && (root.hasGlyph || smallIconImage.status !== Image.Error)

        // Rounded-square icon tile, flatter than a typical macOS icon so its
        // curvature reads as an echo of the card's own radius, not a
        // separate rounder shape sitting inside it.
        readonly property real iconRadius: width * 0.18

        Rectangle {
          id: iconMask
          anchors.fill: parent
          radius: smallIconSlot.iconRadius
          color: "white"
          visible: false
          layer.enabled: true
        }

        Item {
          id: maskedIcon
          anchors.fill: parent
          layer.enabled: true
          layer.smooth: true
          layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: iconMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 0.02
          }

          Rectangle {
            anchors.fill: parent
            color: Color.notifications.background
          }

          Image {
            id: smallIconImage
            anchors.fill: parent
            source: root.smallIconSource
            sourceSize.width: smallIconSlot.width * Screen.devicePixelRatio
            sourceSize.height: smallIconSlot.height * Screen.devicePixelRatio
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            smooth: true
            visible: !root.hasGlyph || smallIconImage.status === Image.Ready
          }

          // Glyph fallback (Nerd Font character) when no image icon is
          // available. Used by omarchy-notification-send's `-g` flag.
          Text {
            anchors.centerIn: parent
            visible: root.hasGlyph && smallIconImage.status !== Image.Ready
            text: root.glyph
            color: Color.notifications.text
            font.family: root.fontFamily
            font.pixelSize: Math.round(smallIconSlot.height * 0.62)
          }
        }
      }

      Text {
        Layout.alignment: Qt.AlignTop
        visible: root.compactGlyph
        text: root.glyph
        color: Color.notifications.text
        font.family: root.fontFamily
        font.pixelSize: root.iconSize
      }

      // Title (summary), then body — the macOS notification stack. Title
      // holds to one line; body wraps up to two and ellipsizes past that.
      ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        spacing: Style.space(2)

        Text {
          Layout.fillWidth: true
          visible: root.summary.length > 0
          text: root.summary
          textFormat: Text.PlainText
          font.family: "Liberation Sans"
          color: Color.notifications.text
          font.pixelSize: root.textSize
          font.bold: true
          wrapMode: Text.NoWrap
          elide: Text.ElideRight
          maximumLineCount: 1
        }

        Text {
          Layout.fillWidth: true
          visible: root.showsBody
          text: root.displayBody
          // Sanitized bodies may carry markup; keep it interpreted.
          textFormat: Text.StyledText
          font.family: "Liberation Sans"
          color: Color.notifications.text
          font.pixelSize: root.textSize
          wrapMode: Text.NoWrap
          elide: Text.ElideRight
          maximumLineCount: 1
        }
      }
    }
  }

  // Faint close affordance, top-right — mirrors macOS's dismiss X. Right-click
  // on the card still closes it too; this just makes that discoverable.
  PanelActionButton {
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.topMargin: root.borderTop + Style.space(7)
    anchors.rightMargin: root.borderRight + Style.space(7)
    size: root.closeButtonSize
    radius: size / 2
    fontSize: Style.font.bodySmall
    iconText: "✕"
    foreground: root.dimColor
    hoverColor: Color.notifications.text
    fontFamily: "Liberation Sans"
    onClicked: root.closeRequested()
  }

}
