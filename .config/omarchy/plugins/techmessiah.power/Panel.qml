import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.UPower
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "omarchy.power"
  ipcTarget: "omarchy.power"
  // manageIpc: false so this panel can own the single IpcHandler the target
  // permits — needed for the togglePercentage method below.
  manageIpc: false
  property var batteryInfo: ({})
  property var systemInfo: ({})
  property var profiles: []
  property string activeProfile: ""
  property int profileIndex: 0
  property bool cursorActive: false
  readonly property bool showPercentage: setting("showPercentage", false) === true
  // With the percentage shown the button paints a text block wider than an
  // icon, so the open-panel mark takes the painted width instead of the
  // icon-sized fraction of the slot the fallback assumes.
  readonly property real openPanelIndicatorWidth: showPercentage && !button.vertical ? button.glyphPaintedWidth : 0
  readonly property bool batteryPresent: {
    var device = UPower.displayDevice
    return !!(device && device.isPresent)
  }

  function upowerStates() {
    return {
      Charging: UPowerDeviceState.Charging,
      Discharging: UPowerDeviceState.Discharging,
      FullyCharged: UPowerDeviceState.FullyCharged,
      PendingCharge: UPowerDeviceState.PendingCharge
    }
  }

  function selectProfileByDelta(delta) {
    profileIndex = Model.selectProfileIndex(profileIndex, delta, profiles)
  }

  function activateSelectedProfile() {
    if (profileIndex < 0 || profileIndex >= profiles.length) return
    setProfile(profiles[profileIndex])
  }

  function batteryIcon() {
    var device = UPower.displayDevice
    return Model.batteryIcon(device, root.discharging, upowerStates())
  }

  function modeLabel() {
    var device = UPower.displayDevice
    return Model.modeLabel(device, root.discharging, upowerStates())
  }

  function profileIcon(name) {
    return Model.profileIcon(name)
  }

  readonly property bool fullyCharged: {
    var device = UPower.displayDevice
    return device && device.isPresent && device.state === UPowerDeviceState.FullyCharged && !root.chargeThresholdActive
  }
  readonly property bool discharging: {
    var device = UPower.displayDevice
    return !!(device && device.isPresent && UPower.onBattery)
  }
  readonly property bool chargeThresholdActive: {
    var device = UPower.displayDevice
    return Model.chargeThresholdActive(device, root.discharging, upowerStates())
  }
  readonly property bool batteryFull: fullyCharged || (!root.discharging && batteryFraction >= 1)
  readonly property bool batteryFlowIdle: batteryFull || chargeThresholdActive

  // 0..1 charge level, used by the visual progress bar.
  readonly property real batteryFraction: {
    var d = UPower.displayDevice
    return Model.batteryFraction(d)
  }

  readonly property bool charging: {
    var d = UPower.displayDevice
    return d && d.isPresent && !UPower.onBattery && !root.batteryFlowIdle
  }

  readonly property color batteryFillColor: {
    return root.bar ? root.bar.foreground : Color.foreground
  }

  // Cute agent-flavored phrases shown in the hero status line, rotated on a
  // timer so the panel feels alive when current is flowing (either direction).
  readonly property var chargingPhrases: [
    "Pumping power",
    "Injecting electrons",
    "Pouring juice",
    "Amassing watts",
    "Hoarding joules",
    "Sucking volts",
    "Topping reserves",
    "Soaking amps",
    "Inhaling kilowatts"
  ]
  readonly property var onBatteryPhrases: [
    "Slurping power",
    "Spending joules",
    "Draining watts",
    "Burning electrons",
    "Sipping juice",
    "Spending coulombs",
    "Bleeding amps",
    "Guzzling volts",
    "Munching reserves"
  ]
  property int phraseIndex: 0

  // Whichever list is "active" given the current power state.
  readonly property var activePhrases: {
    if (fullyCharged) return []
    if (charging) return chargingPhrases
    if (discharging) return onBatteryPhrases
    return []
  }
  readonly property bool rotatingPhrases: activePhrases.length > 0

  readonly property string heroStatusText: {
    if (fullyCharged) return "Fully charged"
    if (rotatingPhrases) return activePhrases[phraseIndex % activePhrases.length]
    return modeLabel()
  }

  function refresh() {
    if (!batteryPresent) return

    if (!batteryProc.running) batteryProc.running = true
    if (!profilesProc.running) profilesProc.running = true
    if (!systemProc.running) systemProc.running = true
  }

  function updateKeyValue(raw, targetName) {
    var next = Model.parseKeyValue(raw)
    // Keep last known good data if a refresh briefly returns nothing — happens
    // around AC plug/unplug events. Avoids the section collapsing mid-transition.
    if (Object.keys(next).length === 0) return
    if (targetName === "battery") batteryInfo = next
    else systemInfo = next
  }

  function updateProfiles(raw) {
    var parsed = Model.parseProfiles(raw, profileIndex)
    // Same guard as battery: preserve the last known profile list across
    // transient empty payloads so the buttons don't blink out.
    if (parsed.profiles.length === 0) return
    profiles = parsed.profiles
    activeProfile = parsed.activeProfile
    profileIndex = parsed.profileIndex
    if (opened && !cursorActive) {
      var idx = profiles.indexOf(activeProfile)
      if (idx >= 0) profileIndex = idx
    }
  }

  function setProfile(profile) {
    if (!profile || actionProc.running) return
    actionProc.command = ["omarchy-powerprofiles-set", root.discharging ? "battery" : "ac", profile]
    actionProc.running = true
  }

  function togglePercentage() {
    root.settings = Object.assign({}, root.settings, { showPercentage: !root.showPercentage })
    if (root.bar && root.bar.shell) root.bar.shell.updateEntryInline(root.moduleName, root.settings)
  }

  IpcHandler {
    target: "omarchy.power"

    function open() { root.open() }
    function close() { root.close() }
    function show() { root.open() }
    function hide() { root.close() }
    function toggle() { root.toggle() }
    function togglePercentage() { root.togglePercentage() }
  }

  onOpenedChanged: {
    if (opened) {
      if (!batteryPresent) {
        close()
        return
      }

      refresh()
      var idx = profiles.indexOf(activeProfile)
      profileIndex = idx >= 0 ? idx : 0
      cursorActive = false
    }
  }

  onBatteryPresentChanged: if (!batteryPresent) close()

  visible: batteryPresent
  implicitWidth: batteryPresent ? button.implicitWidth : 0
  implicitHeight: batteryPresent ? button.implicitHeight : 0

  Process {
    id: batteryProc
    command: ["omarchy-battery-status", "--shell"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.updateKeyValue(text, "battery") }
  }

  Process {
    id: profilesProc
    command: ["omarchy-powerprofiles-list", "--active-state"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.updateProfiles(text) }
  }

  Process {
    id: systemProc
    command: ["omarchy-system-stats"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.updateKeyValue(text, "system") }
  }

  Process {
    id: actionProc
    onExited: root.refresh()
  }

  Timer { interval: 5000; running: root.opened; repeat: true; onTriggered: root.refresh() }

  // Rotate the status phrase while the panel is open and we're in a
  // rotating state (charging or on battery). The text swap is wrapped in a
  // fade so the changeover reads as one organism rather than a hard cut.
  Timer {
    id: phraseTimer
    interval: 2800
    running: root.opened && root.rotatingPhrases
    repeat: true
    triggeredOnStart: false
    onTriggered: phraseSwap.restart()
  }

  SequentialAnimation {
    id: phraseSwap
    PropertyAnimation {
      target: heroStatus; property: "opacity"
      to: 0.0; duration: 180; easing.type: Easing.OutQuad
    }
    ScriptAction {
      script: {
        var n = root.activePhrases.length
        if (n > 0) root.phraseIndex = (root.phraseIndex + 1) % n
      }
    }
    PropertyAnimation {
      target: heroStatus; property: "opacity"
      to: 1.0; duration: 260; easing.type: Easing.InQuad
    }
  }

  // If we leave a rotating state mid-swap, halt the animation and snap back
  // to full opacity so "FULLY CHARGED" is legible immediately rather than
  // appearing dimmed.
  Connections {
    target: root
    function onRotatingPhrasesChanged() {
      if (!root.rotatingPhrases) {
        phraseSwap.stop()
        heroStatus.opacity = 1.0
      }
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.showPercentage && !vertical
      ? Math.round(root.batteryFraction * 100) + "% " + root.batteryIcon()
      : root.batteryIcon()
    slotSize: Style.bar.iconSlot * (root.showPercentage && !vertical ? 2 : 1)
    tooltipText: ""
    onPressed: function(b) {
      if (!root.batteryPresent) return
      if (b === Qt.RightButton) root.togglePercentage()
      else root.toggle()
    }
  }

  TopRightPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened && root.batteryPresent
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        if (dx !== 0) root.selectProfileByDelta(dx)
        else if (dy !== 0) root.selectProfileByDelta(dy)
      }
      onActivateRequested: if (root.cursorActive) root.activateSelectedProfile()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(14)

        // ---------- Hero: battery icon · title/status · percentage ----------
        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, heroPercent.implicitHeight)

          Text {
            id: heroIcon
            text: root.batteryIcon()
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.display
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            Behavior on color { ColorAnimation { duration: 200 } }
          }

          Column {
            id: heroLabels
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(14)
            anchors.right: heroPercent.left
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              text: "Battery"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              id: heroStatus
              text: root.heroStatusText.toUpperCase()
              color: Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
              elide: Text.ElideRight
              width: parent.width
            }
          }

          Text {
            id: heroPercent
            text: root.batteryInfo.percentage || "—"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.displayLarge
            font.bold: true
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            Behavior on color { ColorAnimation { duration: 200 } }
          }
        }

        // ---------- Battery progress bar ----------
        Item {
          width: parent.width
          implicitHeight: Style.space(8)

          Rectangle {
            id: barTrack
            anchors.fill: parent
            radius: height / 2
            color: Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.12)
          }

          Rectangle {
            id: barFill
            anchors.left: barTrack.left
            anchors.verticalCenter: barTrack.verticalCenter
            height: barTrack.height
            radius: barTrack.radius
            color: root.batteryFillColor
            width: Math.max(barTrack.height, barTrack.width * root.batteryFraction)

            Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 220 } }

            // Subtle pulse while charging — visible signal that energy is flowing in.
            SequentialAnimation on opacity {
              running: root.charging && !root.fullyCharged && root.opened
              loops: Animation.Infinite
              alwaysRunToEnd: true
              NumberAnimation { from: 1.0; to: 0.55; duration: 950; easing.type: Easing.InOutSine }
              NumberAnimation { from: 0.55; to: 1.0; duration: 950; easing.type: Easing.InOutSine }
            }
          }
        }

        // ---------- Stats ----------
        // Visibility is intentionally only gated by "we've ever loaded data" so
        // the section never collapses mid-transition. fullyCharged is *not* part
        // of the condition: UPower briefly reports FullyCharged on plug-in when
        // the battery sits above the charge-control start threshold, and we
        // refuse to flicker the whole panel for that ~1s window.
        Row {
          visible: root.batteryInfo.percentage !== undefined
          width: parent.width
          spacing: Style.space(20)

          Column {
            width: (parent.width - parent.spacing) / 2
            spacing: Style.spacing.labelGap
            InfoPair { label: "Battery size"; value: root.batteryInfo.size || "" }
            InfoPair { label: "Charge cycles"; value: root.batteryInfo.cycles || "—" }
          }

          Column {
            width: (parent.width - parent.spacing) / 2
            spacing: Style.spacing.labelGap
            InfoPair {
              label: root.chargeThresholdActive ? "Charge limit" : (root.discharging ? "Time left" : "Time to full")
              value: root.chargeThresholdActive ? (root.batteryInfo.threshold || "-") : (root.batteryFlowIdle ? "-" : (root.batteryInfo.time || "—"))
            }
            InfoPair {
              label: root.chargeThresholdActive ? "Battery state" : (root.discharging ? "Discharging" : "Charging")
              value: root.chargeThresholdActive ? "Holding" : (root.batteryFull ? "-" : (root.batteryInfo.rate || ""))
            }
          }
        }

        // ---------- Power profile picker ----------
        PanelSeparator {
          foreground: root.bar.foreground
        }

        Column {
          width: parent.width
          spacing: Style.space(10)

          PanelSectionHeader {
            text: "POWER PROFILE"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
          }

          Row {
            id: profileRow
            width: parent.width
            spacing: Style.space(6)

            readonly property real cellWidth: root.profiles.length > 0
              ? (width - spacing * (root.profiles.length - 1)) / root.profiles.length
              : 0

            Repeater {
              model: root.profiles
              Button {
                required property var modelData
                required property int index
                width: profileRow.cellWidth
                iconText: root.profileIcon(String(modelData))
                iconSize: Style.font.title
                text: String(modelData).charAt(0).toUpperCase() + String(modelData).slice(1)
                fontSize: Style.font.bodySmall
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                horizontalPadding: Style.spacing.controlPaddingX
                verticalPadding: Style.spacing.controlPaddingY + Style.space(2)
                bordered: true
                active: root.activeProfile === modelData
                hasCursor: root.cursorActive && root.profileIndex === index
                onClicked: root.setProfile(modelData)
                onHovered: function(h) {
                  if (h) {
                    root.cursorActive = true
                    root.profileIndex = index
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  component InfoPair: Row {
    property string label: ""
    property string value: ""

    width: parent.width
    spacing: Style.space(8)

    InfoLabel { text: label }
    Item { width: Math.max(0, parent.width - parent.children[0].implicitWidth - parent.children[2].implicitWidth - parent.spacing * 2); height: 1 }
    InfoValue { text: value }
  }

  component InfoLabel: Text {
    color: root.bar.foreground
    opacity: 0.6
    font.family: root.bar.fontFamily
    font.pixelSize: Style.font.bodySmall
  }

  component InfoValue: Text {
    color: root.bar.foreground
    font.family: root.bar.fontFamily
    font.pixelSize: Style.font.bodySmall
  }

  // Local variant of qs.Ui's KeyboardPanel: same layer-shell scaffolding,
  // focus-priming, and outside-click dismissal, but the card always pins to
  // the top-right screen corner (matching the notification toast position)
  // instead of anchoring under the triggering bar icon.
  component TopRightPanel: PanelWindow {
    id: trpRoot

    required property Item anchorItem
    required property QtObject bar
    property var owner: null
    property int margin: Style.gapsOut
    property int padding: Style.spacing.popupPadding
    property int contentWidth: Style.space(280)
    property int contentHeight: Style.space(200)
    property var borderSpec: Border.flat(Util.alpha(Color.popups.border, 0.35), 3)
    property bool centerOnBar: false
    property bool open: false
    property int gap: Style.gapsOut
    property bool popoutSwitching: false
    property bool popoutSwitchClosing: false
    property bool focusPrimed: false
    property Item focusTarget: null

    default property alias contentItem: trpContentHolder.children

    readonly property var coordinatorKey: owner || trpRoot
    readonly property var anchorWindow: anchorItem ? anchorItem.QsWindow.window : null
    readonly property string barPos: bar ? bar.position : "top"

    function close() {
      if (owner && "close" in owner) owner.close()
      else trpRoot.open = false
    }

    function beginFocusPrime() {
      if (open && backingWindowVisible) focusPrimeTimer.restart()
    }

    screen: anchorWindow ? anchorWindow.screen : null
    visible: open || card.opacity > 0 || popoutSwitching
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.namespace: "omarchy-keyboard-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open
      ? (focusPrimed ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive)
      : WlrKeyboardFocus.None

    onBackingWindowVisibleChanged: beginFocusPrime()

    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }

    readonly property real _barStripSize: {
      if (!bar) return 0
      var actual = (trpRoot.barPos === "top" || trpRoot.barPos === "bottom") ? trpRoot.barH : trpRoot.barW
      return Math.max(bar.barSize, actual) + trpRoot.gap
    }
    mask: Region {
      width: trpRoot.screenW
      height: trpRoot.screenH
    }

    TransformWatcher {
      id: trpAnchorWatcher
      a: anchorWindow ? anchorWindow.contentItem : null
      b: anchorItem
    }

    readonly property point anchorScreenPos: {
      trpAnchorWatcher.transform
      if (!anchorItem || !anchorWindow) return Qt.point(0, 0)
      return anchorItem.mapToItem(anchorWindow.contentItem, 0, 0)
    }
    readonly property real anchorW: anchorItem ? anchorItem.width : 0
    readonly property real anchorH: anchorItem ? anchorItem.height : 0
    readonly property real screenW: screen ? screen.width : 0
    readonly property real screenH: screen ? screen.height : 0
    readonly property real availableCardWidth: screenW > 0
      ? Math.max(120, screenW - ((barPos === "left" || barPos === "right") ? barW + gap + margin : margin * 2))
      : 0
    readonly property real availableCardHeight: screenH > 0
      ? Math.max(120, screenH - ((barPos === "top" || barPos === "bottom") ? barH + gap + margin : margin * 2))
      : 0
    readonly property real verticalContentInset: padding * 2 + Border.top(borderSpec) + Border.bottom(borderSpec)

    function fittedContentWidth(width, cap) {
      var desired = Math.max(1, Number(width) || 1)
      var maxWidth = trpRoot.availableCardWidth > 0 ? trpRoot.availableCardWidth : desired
      if (cap !== undefined && Number(cap) > 0) maxWidth = Math.min(maxWidth, Number(cap))
      return Math.round(Math.min(desired, maxWidth))
    }

    function fittedContentHeight(implicitHeight, cap) {
      var desired = Math.max(trpRoot.verticalContentInset, (Number(implicitHeight) || 0) + trpRoot.verticalContentInset)
      var maxHeight = trpRoot.availableCardHeight > 0 ? trpRoot.availableCardHeight : desired
      if (cap !== undefined && Number(cap) > 0) maxHeight = Math.min(maxHeight, Number(cap))
      return Math.round(Math.min(desired, maxHeight))
    }

    function cappedContentHeight(height) {
      var desired = Math.max(trpRoot.padding * 2, Number(height) || trpRoot.padding * 2)
      var maxHeight = trpRoot.availableCardHeight > 0 ? trpRoot.availableCardHeight : desired
      return Math.round(Math.min(desired, maxHeight))
    }

    readonly property real barW: anchorWindow ? anchorWindow.width : screenW
    readonly property real barH: anchorWindow ? anchorWindow.height : 0
    // Hyprland's own gaps_out, which is what insets tiled windows from the
    // screen edge. Style.gapsOut is that value halved (Commons/Style.qml
    // applyGapsOutJson), so a card laid out on `margin` alone overhangs the
    // window borders it is meant to line up with by half a gap.
    readonly property int windowGap: Style.gapsOut * 2

    // Centered on screen. windowGap keeps the clamp on the same inset the
    // window borders use, so a card too large to centre still lands flush
    // with them rather than half a gap over.
    readonly property point cardOrigin: {
      if (!bar) return Qt.point(windowGap, windowGap)
      var x = (screenW - contentWidth) / 2
      var y = (screenH - contentHeight) / 2
      x = Math.max(windowGap, Math.min(x, screenW - contentWidth - windowGap))
      y = Math.max(windowGap, Math.min(y, screenH - contentHeight - windowGap))
      return Qt.point(Math.round(x), Math.round(y))
    }

    onOpenChanged: {
      if (open) {
        focusPrimed = false
        beginFocusPrime()
        if (focusTarget) Qt.callLater(function() {
          if (trpRoot.open && trpRoot.focusTarget) trpRoot.focusTarget.forceActiveFocus()
        })
      } else {
        focusPrimeTimer.stop()
        focusPrimed = false
      }
      if (!bar) return
      if (open) {
        popoutSwitchClosing = false
        popoutSwitching = bar.activePopout && bar.activePopout !== coordinatorKey
        bar.requestPopout(coordinatorKey)
        if (popoutSwitching) popoutSwitchTimer.restart()
      } else {
        popoutSwitchClosing = !!(owner && owner.popoutSwitchClosing)
        popoutSwitching = false
        if (bar.activePopout === coordinatorKey) bar.releasePopout(coordinatorKey)
        if (popoutSwitchClosing) closeSwitchTimer.restart()
      }
    }

    Timer {
      id: focusPrimeTimer
      interval: 75
      onTriggered: if (trpRoot.open) trpRoot.focusPrimed = true
    }

    Timer {
      id: popoutSwitchTimer
      interval: 150
      onTriggered: trpRoot.popoutSwitching = false
    }

    Timer {
      id: closeSwitchTimer
      interval: 1
      onTriggered: trpRoot.popoutSwitchClosing = false
    }

    MouseArea {
      id: trpDismissArea
      anchors.fill: parent
      enabled: trpRoot.open
      acceptedButtons: Qt.AllButtons
      hoverEnabled: true
      property bool hoveringBar: false
      cursorShape: hoveringBar ? Qt.PointingHandCursor : Qt.ArrowCursor

      function inBarRegion(px, py) {
        if (trpRoot.barPos === "bottom") return py >= trpRoot.screenH - trpRoot._barStripSize
        if (trpRoot.barPos === "left") return px <= trpRoot._barStripSize
        if (trpRoot.barPos === "right") return px >= trpRoot.screenW - trpRoot._barStripSize
        return py <= trpRoot._barStripSize
      }

      function barPoint(px, py) {
        if (trpRoot.barPos === "bottom") return Qt.point(px, py - (trpRoot.screenH - trpRoot.barH))
        if (trpRoot.barPos === "right") return Qt.point(px - (trpRoot.screenW - trpRoot.barW), py)
        return Qt.point(px, py)
      }

      function pressTargetAt(px, py) {
        if (!trpRoot.anchorWindow || !trpRoot.anchorWindow.contentItem || !trpRoot.bar || !trpRoot.bar.clickTargets) return null
        var p = barPoint(px, py)
        var targets = trpRoot.bar.clickTargets
        for (var i = targets.length - 1; i >= 0; i--) {
          var target = targets[i]
          if (!target || !target.triggerPress || target.visible === false || target.opacity === 0 || !target.mapToItem) continue
          if (trpRoot.bar.targetBelongsToWindow && !trpRoot.bar.targetBelongsToWindow(target, trpRoot.anchorWindow)) continue
          var pos = trpRoot.anchorWindow.itemPosition(target)
          if (p.x >= pos.x && p.x <= pos.x + target.width && p.y >= pos.y && p.y <= pos.y + target.height) return target
        }
        return null
      }

      function forwardBarClick(px, py, button) {
        if (button !== Qt.LeftButton && button !== Qt.RightButton && button !== Qt.MiddleButton) return false
        var target = pressTargetAt(px, py)
        if (!target) return false
        target.triggerPress(button)
        return true
      }

      onPositionChanged: function(mouse) { hoveringBar = inBarRegion(mouse.x, mouse.y) }
      onExited: hoveringBar = false
      onClicked: function(mouse) {
        if (trpRoot.focusPrimed && inBarRegion(mouse.x, mouse.y) && forwardBarClick(mouse.x, mouse.y, mouse.button)) return
        trpRoot.close()
      }
    }

    Variants {
      model: trpRoot.open ? Quickshell.screens : []

      delegate: Component {
        PanelWindow {
          required property var modelData

          screen: modelData
          visible: trpRoot.open && !!trpRoot.screen && modelData.name !== trpRoot.screen.name
          color: "transparent"
          exclusionMode: ExclusionMode.Ignore

          WlrLayershell.namespace: "omarchy-keyboard-panel-dismiss"
          WlrLayershell.layer: WlrLayer.Overlay
          WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

          anchors {
            top: true
            bottom: true
            left: true
            right: true
          }

          MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onPressed: trpRoot.close()
          }
        }
      }
    }

    BorderSurface {
      id: card
      x: trpRoot.cardOrigin.x
      y: trpRoot.cardOrigin.y
      width: trpRoot.contentWidth
      height: trpRoot.contentHeight
      color: Color.popups.background
      borderSpec: trpRoot.borderSpec
      padding: trpRoot.padding
      radius: Style.cornerRadius
      opacity: trpRoot.open || trpRoot.popoutSwitching ? 1.0 : 0

      Behavior on opacity {
        enabled: !trpRoot.popoutSwitching && !trpRoot.popoutSwitchClosing
        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
      }

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
      }

      Item {
        id: trpContentHolder
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        opacity: trpRoot.popoutSwitching ? (trpRoot.open ? 1.0 : 0) : 1.0

        Behavior on opacity {
          enabled: trpRoot.popoutSwitching
          NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
        }
      }
    }
  }
}
