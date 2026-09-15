import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import qs.Commons
import qs.Ui
import "TrayModel.js" as TrayModel

// macOS-style control center. One bar button opens a card holding the six
// manual indicators as always-visible tiles plus the system tray, replacing
// the hover-to-reveal Indicators widget and the sliding tray drawer that used
// to occupy the right of the bar.
Panel {
  id: root
  moduleName: "techmessiah.control-center"
  ipcTarget: "techmessiah.control-center"

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color accent: Color.accent
  readonly property color urgent: bar ? bar.urgent : Color.urgent

  // ---------------------------------------------------------------- tiles --
  // Each entry names a file in indicators/. Those files are the same
  // BarIndicator subclasses the bar used to render, so all state reads and
  // toggle actions come from them unchanged; this panel only replaces the
  // chrome. `closesPanel` marks the three that hand off to another surface
  // (a config window, the capture menu, the reminder flow) rather than
  // flipping a value in place.
  readonly property var tileDefs: [
    { key: "Dnd",             label: "Do Not Disturb", closesPanel: false },
    { key: "NightLight",      label: "Night Light",    closesPanel: false },
    { key: "StayAwake",       label: "Stay Awake",     closesPanel: false },
    { key: "Dictation",       label: "Dictation",      closesPanel: true  },
    { key: "ScreenRecording", label: "Record",         closesPanel: true  },
    { key: "Reminder",        label: "Reminders",      closesPanel: true  }
  ]
  readonly property int tileColumns: 3

  // indicatorHost contract, as injected by the bar's Indicators widget.
  // Reminder and ScreenRecording poll external commands and refresh on this
  // signal; the rest ignore it.
  signal refreshRequested()
  property bool revealInactiveIndicators: true
  function setIndicatorItemHovered(hovered) {}
  function setIndicatorAreaHovered(hovered) {}

  property int cursorIndex: 0
  property bool cursorActive: false

  function moveCursor(dx, dy) {
    var count = root.tileDefs.length
    var next = root.cursorIndex + dx + dy * root.tileColumns
    if (next < 0 || next >= count) return
    root.cursorIndex = next
  }

  function activateTile(index) {
    var slot = tileRepeater.itemAt(index)
    if (!slot) return
    slot.trigger()
  }

  // ------------------------------------------------------------ ai usage --
  // Agent rate limits, moved in from the standalone agents bar widget. Main
  // and Agent are that plugin's headless data model, copied verbatim: this
  // panel only renders a compact meter per provider.
  readonly property var aiProviders: usage.enabledProviders

  // Countdowns read this instead of Date.now() so a card left open keeps
  // telling the truth.
  property double nowMs: Date.now()

  function windowIsLong(text) {
    return text.indexOf("week") >= 0 || text.indexOf("7-day") >= 0 || text.indexOf("seven") >= 0
      || text.indexOf("month") >= 0 || text.indexOf("30-day") >= 0
  }

  function windowSpanMs(label) {
    var text = String(label || "").toLowerCase()
    if (text.indexOf("month") >= 0 || text.indexOf("30-day") >= 0) return 30 * 24 * 3600 * 1000
    if (windowIsLong(text)) return 7 * 24 * 3600 * 1000
    var hours = text.match(/(\d+)\s*-?\s*h(?:our)?\b/)
    if (hours) return Number(hours[1]) * 3600 * 1000
    var minutes = text.match(/(\d+)\s*-?\s*m(?:in(?:ute)?s?)?\b/)
    if (minutes) return Number(minutes[1]) * 60 * 1000
    return 0
  }

  function windowTitle(label) {
    var text = String(label || "").toLowerCase()
    if (text.indexOf("month") >= 0) return "Monthly"
    if (windowIsLong(text)) return "Weekly"
    if (text.indexOf("session") >= 0 || windowSpanMs(label) > 0) return "Session"
    var plain = String(label || "").replace(/\s*\(.*\)\s*/, "").trim()
    return plain === "" ? "Limit" : plain
  }

  // A collector that already knows which window a limit belongs to says so,
  // and that beats reading it back out of the label.
  function limitWindow(label, percent, resetAt, title) {
    return {
      title: String(title || "") !== "" ? String(title) : windowTitle(label),
      percent: Number(percent),
      resetAt: String(resetAt || "")
    }
  }

  function limitWindows(p) {
    if (!p) return []
    var out = []
    var list = p.limits || []
    for (var i = 0; i < list.length; i++) {
      var entry = list[i] || {}
      var percent = Number(entry.percent)
      if (percent >= 0) out.push(limitWindow(entry.label, percent, entry.resetsAt, entry.title))
    }
    return out
  }

  // The window that decides how much room is left — the fullest one, since
  // that is what stops the next prompt.
  function bindingWindow(p) {
    var windows = limitWindows(p)
    var best = null
    for (var i = 0; i < windows.length; i++) {
      if (!best || windows[i].percent > best.percent) best = windows[i]
    }
    return best
  }

  function resetMsFor(w) {
    if (!w || w.resetAt === "") return -1
    var ms = new Date(w.resetAt).getTime()
    return isFinite(ms) ? ms - root.nowMs : -1
  }

  function formatDuration(ms) {
    if (!(ms > 0)) return "now"
    var minutes = Math.floor(ms / 60000)
    var hours = Math.floor(minutes / 60)
    var days = Math.floor(hours / 24)
    if (days > 0) return days + "d " + (hours % 24) + "h"
    if (hours > 0) return hours + "h " + (minutes % 60) + "m"
    return Math.max(1, minutes) + "m"
  }

  function colorChannelLuminance(channel) {
    if (!isFinite(channel)) return 0
    return channel <= 0.03928 ? channel / 12.92 : Math.pow((channel + 0.055) / 1.055, 2.4)
  }

  function colorLuminance(color) {
    return 0.2126 * colorChannelLuminance(color.r)
      + 0.7152 * colorChannelLuminance(color.g)
      + 0.0722 * colorChannelLuminance(color.b)
  }

  // Marks resolve by convention, so a new agent's data file needs nothing
  // from this panel: assets/<id>.svg if it ships one, its initial if not.
  function iconCandidatesForProvider(p) {
    if (!p) return []
    var candidates = []
    if (colorLuminance(Color.popups.background) >= 0.5)
      candidates.push(Qt.resolvedUrl("assets/" + p.providerId + "-light.svg"))
    candidates.push(Qt.resolvedUrl("assets/" + p.providerId + ".svg"))
    return candidates
  }

  Main {
    id: usage
    settings: root.settings
  }

  // Cheap enough to keep running while the card is open: it only re-evaluates
  // text bindings, and a stale "resets in 2h" is worse than a timer.
  Timer {
    interval: 30000
    running: root.opened
    repeat: true
    onTriggered: root.nowMs = Date.now()
  }

  // ----------------------------------------------------------------- tray --
  property bool menuMode: false
  property var activeTrayItem: null
  property var submenuStack: []
  property bool menuLevelSettling: false

  readonly property int submenuDepth: submenuStack.length
  readonly property string currentTitle: submenuDepth > 0
    ? submenuStack[submenuDepth - 1].title
    : (activeTrayItem ? String(activeTrayItem.title || activeTrayItem.id || "") : "")
  readonly property var currentChildren: submenuDepth > 0
    ? submenuStack[submenuDepth - 1].opener.children
    : trayMenuOpener.children

  readonly property var trayItems: {
    var values = SystemTray.items.values
    var result = []
    for (var i = 0; i < values.length; i++) {
      var item = values[i]
      if (item.status === Status.Passive) continue
      if (root.ownedByOmarchy(item)) continue
      result.push(item)
    }
    return result
  }

  function ownedByOmarchy(item) {
    var layout = root.bar && root.bar.layoutConfig ? root.bar.layoutConfig : null
    return TrayModel.ownedByOmarchy(item, layout)
  }

  // Quickshell already resolves a tray icon into a ready-to-use image:// URL,
  // including the "?path=" fallback search dir some apps need.
  function trayIconSource(icon) {
    return String(icon || "")
  }

  // Symbolic icons ship a fixed near-white fill the host is meant to recolor;
  // detect them by the freedesktop "-symbolic" suffix and tint instead.
  function iconIsSymbolic(icon) {
    var name = String(icon || "").split("?")[0]
    return name.slice(-9) === "-symbolic"
  }

  function trayTooltip(item) {
    return item.tooltipTitle || item.title || item.id || ""
  }

  Component {
    id: submenuOpenerComponent
    QsMenuOpener {}
  }

  QsMenuOpener {
    id: trayMenuOpener
    menu: root.activeTrayItem ? root.activeTrayItem.menu : null
  }

  Timer {
    id: menuLevelSettleTimer
    interval: 250
    onTriggered: root.menuLevelSettling = false
  }

  // Changing level rebuilds the row delegates synchronously, so the next row
  // lands under a cursor that hasn't moved. Ignore row clicks for a beat after
  // each level change; a deliberate follow-up click is slower than that.
  function settleMenuLevel() {
    menuLevelSettling = true
    menuLevelSettleTimer.restart()
  }

  function resetTrayMenu() {
    menuLevelSettling = false
    menuLevelSettleTimer.stop()
    menuFlick.contentY = 0
    // Clear the reactive stack before tearing anything down, then destroy
    // deepest first: an inner opener's menu entry is owned by its parent's
    // children model, so destroying a parent first would invalidate an entry a
    // still-live child opener references.
    var openers = submenuStack
    submenuStack = []
    for (var i = openers.length - 1; i >= 0; i--) openers[i].opener.destroy()
  }

  function enterSubmenu(entry, title) {
    var opener = submenuOpenerComponent.createObject(root, { menu: entry })
    if (!opener) return
    var stack = submenuStack.slice()
    stack.push({ opener: opener, title: title })
    submenuStack = stack
    settleMenuLevel()
  }

  function leaveSubmenu() {
    if (submenuStack.length === 0) {
      root.closeTrayMenu()
      return
    }
    var stack = submenuStack.slice()
    var top = stack.pop()
    submenuStack = stack
    top.opener.destroy()
    settleMenuLevel()
  }

  function openTrayMenu(item) {
    if (!item || !item.menu) return
    // Reset before switching items: trayMenuOpener.menu binds to
    // activeTrayItem.menu, so assigning a new item invalidates the old root's
    // children immediately.
    resetTrayMenu()
    activeTrayItem = item
    menuMode = true
  }

  function closeTrayMenu() {
    menuMode = false
    resetTrayMenu()
    activeTrayItem = null
  }

  // Poll-backed indicators go stale while the card is shut; refresh on open.
  // Closing drops any menu drill-down so the card always reopens on the tiles.
  onOpenedChanged: {
    if (opened) {
      cursorActive = false
      cursorIndex = 0
      nowMs = Date.now()
      root.refreshRequested()
      usage.refreshLimits()
    } else {
      closeTrayMenu()
    }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    iconComponent: Component {
      Item {
        Image {
          anchors.centerIn: parent
          width: Style.space(11)
          height: Style.space(11)
          source: Qt.resolvedUrl("assets/control-center.svg")
          // Rasterize at physical pixels: the logical size leaves the SVG
          // soft on a HiDPI display.
          sourceSize.width: Math.round(width * Screen.devicePixelRatio)
          sourceSize.height: Math.round(height * Screen.devicePixelRatio)
          fillMode: Image.PreserveAspectFit
        }
      }
    }
    tooltipText: "Control Center"
    active: root.opened
    onPressed: function(b) { root.toggle() }
  }

  TopRightPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(330))
    contentHeight: panel.fittedContentHeight(
      root.menuMode ? menuView.implicitHeight : tilesView.implicitHeight,
      Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent

      onMoveRequested: function(dx, dy) {
        if (root.menuMode) return
        if (!root.cursorActive) { root.cursorActive = true; return }
        root.moveCursor(dx, dy)
      }
      onActivateRequested: {
        if (root.menuMode) return
        if (root.cursorActive) root.activateTile(root.cursorIndex)
      }
      onCloseRequested: {
        if (root.menuMode) root.leaveSubmenu()
        else root.close()
      }
      onTabRequested: function(direction) { root.switchPanel(direction) }

      // ------------------------------------------------------- tiles view --
      Column {
        id: tilesView
        visible: !root.menuMode
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(14)

        Grid {
          id: tileGrid
          width: parent.width
          columns: root.tileColumns
          spacing: Style.space(8)

          readonly property real cellWidth:
            (width - spacing * (columns - 1)) / columns

          Repeater {
            id: tileRepeater
            model: root.tileDefs

            delegate: Item {
              id: tile
              required property var modelData
              required property int index

              readonly property var indicator: indicatorLoader.item
              readonly property bool tileActive: indicator ? indicator.active === true : false
              readonly property bool hasCursor: root.cursorActive && root.cursorIndex === tile.index
              readonly property string glyph: indicator
                ? (tile.tileActive
                    ? (indicator.activeText !== "" ? indicator.activeText : indicator.inactiveText)
                    : indicator.inactiveText)
                : ""
              readonly property string detail: indicator
                ? String(tile.tileActive ? indicator.activeTooltipText : indicator.inactiveTooltipText)
                : ""

              function trigger() {
                if (!tile.indicator) return
                tile.indicator.pressed(Qt.LeftButton)
                if (tile.modelData.closesPanel) root.close()
              }

              width: tileGrid.cellWidth
              height: Style.space(78)

              // The indicator itself is hosted headless: it owns the service
              // reads, the polling processes and the toggle action, and this
              // tile only paints it. Zero-sized and invisible so it contributes
              // nothing to layout or input.
              Loader {
                id: indicatorLoader
                width: 0
                height: 0
                visible: false
                source: Qt.resolvedUrl("indicators/" + tile.modelData.key + ".qml")
                onLoaded: {
                  item.moduleName = root.moduleName
                  item.indicatorBlock = "single"
                  item.indicatorHost = root
                }
              }

              // The bar injects `bar` into this panel after construction, so
              // bind rather than assigning once in onLoaded.
              Binding {
                target: indicatorLoader.item
                property: "bar"
                value: root.bar
                when: indicatorLoader.item !== null
              }

              Rectangle {
                id: tileSurface
                anchors.fill: parent
                radius: Style.cornerRadius
                color: tile.tileActive
                  ? root.accent
                  : (tileMouse.containsMouse || tile.hasCursor
                      ? Style.hoverFillFor(root.foreground, root.accent)
                      : Style.normalFillFor(root.foreground, root.accent))
                border.width: tile.hasCursor ? 1 : 0
                border.color: Style.focusBorderFor(root.foreground, root.accent)

                Behavior on color {
                  ColorAnimation { duration: 140; easing.type: Easing.OutCubic }
                }
              }

              Column {
                anchors.centerIn: parent
                width: parent.width - Style.space(12)
                spacing: Style.space(4)

                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: tile.glyph
                  color: tile.tileActive ? Color.background : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.iconLarge
                }

                Text {
                  width: parent.width
                  horizontalAlignment: Text.AlignHCenter
                  text: tile.modelData.label
                  textFormat: Text.PlainText
                  color: tile.tileActive ? Color.background : root.foreground
                  opacity: tile.tileActive ? 1.0 : 0.75
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  // Two-word labels ("Do Not Disturb", "Night Light") do not
                  // fit a third of the card on one line; wrap rather than
                  // elide so the tile still says what it toggles.
                  wrapMode: Text.WordWrap
                  maximumLineCount: 2
                  elide: Text.ElideRight
                }
              }

              MouseArea {
                id: tileMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: if (root.bar && tile.detail !== "") root.bar.showTooltip(tile, tile.detail)
                onExited: if (root.bar) root.bar.hideTooltip(tile)
                onClicked: {
                  if (root.bar) root.bar.hideTooltip(tile)
                  root.cursorActive = true
                  root.cursorIndex = tile.index
                  tile.trigger()
                }
              }
            }
          }
        }

        PanelSeparator {
          visible: root.aiProviders.length > 0
          width: parent.width
          foreground: root.foreground
        }

        PanelSectionHeader {
          visible: root.aiProviders.length > 0
          text: "AI USAGE"
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        Column {
          id: aiColumn
          visible: root.aiProviders.length > 0
          width: parent.width
          spacing: Style.space(10)

          Repeater {
            model: root.aiProviders

            delegate: Item {
              id: aiRow
              required property var modelData

              readonly property var window: root.bindingWindow(aiRow.modelData)
              readonly property real percent: window ? Math.max(0, Math.min(1, window.percent)) : 0
              readonly property bool alarming: percent >= 0.9
              readonly property real resetMs: root.resetMsFor(aiRow.window)
              readonly property var candidates: root.iconCandidatesForProvider(aiRow.modelData)

              width: parent.width
              implicitHeight: aiRowLayout.implicitHeight

              Column {
                id: aiRowLayout
                width: parent.width
                spacing: Style.space(4)

                Item {
                  width: parent.width
                  implicitHeight: Math.max(aiMark.height, aiName.implicitHeight, aiPercent.implicitHeight)

                  Item {
                    id: aiMark
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    width: Style.font.body
                    height: Style.font.body

                    // Provider objects are rebuilt on every refresh, which
                    // churns the array's identity without changing its
                    // content. Restart the fallback walk only when the URLs
                    // change: re-pointing source at a URL whose load already
                    // failed emits no statusChanged.
                    property string candidatesKey: aiRow.candidates.join("\n")
                    property int candidateIndex: 0
                    onCandidatesKeyChanged: candidateIndex = 0

                    Image {
                      id: aiMarkImage
                      anchors.fill: parent
                      source: aiMark.candidateIndex < aiRow.candidates.length
                        ? aiRow.candidates[aiMark.candidateIndex]
                        : ""
                      sourceSize.width: Style.font.body * 2
                      sourceSize.height: Style.font.body * 2
                      fillMode: Image.PreserveAspectFit
                      onStatusChanged: if (status === Image.Error) aiMark.candidateIndex++
                    }
                  }

                  Text {
                    id: aiName
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: aiMark.right
                    anchors.leftMargin: Style.space(8)
                    anchors.right: aiPercent.left
                    anchors.rightMargin: Style.space(8)
                    text: aiRow.window
                      ? aiRow.modelData.providerName + " · " + aiRow.window.title
                      : aiRow.modelData.providerName
                    textFormat: Text.PlainText
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                    elide: Text.ElideRight
                  }

                  Text {
                    id: aiPercent
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    text: aiRow.window ? Math.round(aiRow.percent * 100) + "%" : "—"
                    color: aiRow.alarming ? root.urgent : root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                  }
                }

                Rectangle {
                  id: aiTrack
                  visible: !!aiRow.window
                  width: parent.width
                  height: Style.space(4)
                  radius: Style.cornerRadius
                  color: Style.selectedFillFor(root.foreground, root.accent)

                  Rectangle {
                    width: Math.round(aiTrack.width * aiRow.percent)
                    height: parent.height
                    radius: parent.radius
                    color: aiRow.alarming ? root.urgent : root.accent

                    Behavior on width {
                      NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                    }
                  }
                }

                Text {
                  visible: aiRow.resetMs > 0
                  width: parent.width
                  text: "Resets in " + root.formatDuration(aiRow.resetMs)
                  textFormat: Text.PlainText
                  color: Qt.darker(root.foreground, 1.4)
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                }
              }
            }
          }
        }

        PanelSeparator {
          visible: root.trayItems.length > 0
          width: parent.width
          foreground: root.foreground
        }

        PanelSectionHeader {
          visible: root.trayItems.length > 0
          text: "TRAY"
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        Grid {
          id: trayGrid
          visible: root.trayItems.length > 0
          width: parent.width
          columns: 6
          spacing: Style.space(6)

          readonly property real cellWidth:
            (width - spacing * (columns - 1)) / columns

          Repeater {
            model: root.trayItems

            delegate: Item {
              id: trayTile
              required property var modelData

              width: trayGrid.cellWidth
              height: trayGrid.cellWidth

              Rectangle {
                anchors.fill: parent
                radius: Style.cornerRadius
                color: trayMouse.containsMouse
                  ? Style.hoverFillFor(root.foreground, root.accent)
                  : Style.normalFillFor(root.foreground, root.accent)
              }

              TrayIcon {
                anchors.centerIn: parent
                width: Style.space(18)
                height: Style.space(18)
                icon: trayTile.modelData.icon
              }

              MouseArea {
                id: trayMouse
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: if (root.bar) root.bar.showTooltip(trayTile, root.trayTooltip(trayTile.modelData))
                onExited: if (root.bar) root.bar.hideTooltip(trayTile)
                onClicked: function(mouse) {
                  if (root.bar) root.bar.hideTooltip(trayTile)
                  if (mouse.button === Qt.RightButton || trayTile.modelData.onlyMenu) {
                    root.openTrayMenu(trayTile.modelData)
                  } else if (mouse.button === Qt.MiddleButton) {
                    trayTile.modelData.secondaryActivate()
                    root.close()
                  } else {
                    trayTile.modelData.activate()
                    root.close()
                  }
                }
                onWheel: function(wheel) {
                  trayTile.modelData.scroll(wheel.angleDelta.y, false)
                }
              }
            }
          }
        }
      }

      // -------------------------------------------------------- menu view --
      // A tray item's menu takes over the card rather than opening a nested
      // popup. QsMenuEntry.display() renders a *platform* menu, which
      // Quickshell refuses without `pragma UseQApplication` — the shell root
      // does not set it — so submenus are drilled into in place instead.
      Column {
        id: menuView
        visible: root.menuMode
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        spacing: 0

        Item {
          id: menuBackRow
          width: parent.width
          implicitHeight: Style.space(30)

          Rectangle {
            anchors.fill: parent
            radius: Math.max(2, Style.cornerRadius)
            color: backMouse.containsMouse
              ? Style.hoverFillFor(root.foreground, root.accent)
              : "transparent"
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            width: Style.space(22)
            horizontalAlignment: Text.AlignHCenter
            text: "\u2039"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: Style.space(28)
            anchors.right: parent.right
            anchors.rightMargin: Style.space(10)
            text: root.currentTitle
            textFormat: Text.PlainText
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
          }

          MouseArea {
            id: backMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (root.menuLevelSettling) return
              // Reset scroll before the model swap so the parent level shows
              // from the top.
              menuFlick.contentY = 0
              root.leaveSubmenu()
            }
          }
        }

        Item {
          width: parent.width
          implicitHeight: Style.space(11)

          Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: Style.space(10)
            anchors.right: parent.right
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            height: 1
            color: Color.popups.border
            opacity: 0.45
          }
        }

        Flickable {
          id: menuFlick
          width: parent.width
          height: Math.max(0, menuView.height - menuBackRow.implicitHeight - Style.space(11))
          implicitHeight: menuColumn.implicitHeight
          contentWidth: width
          contentHeight: menuColumn.implicitHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          flickableDirection: Flickable.VerticalFlick
          interactive: contentHeight > height

          ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

          Column {
            id: menuColumn
            width: menuFlick.width
            spacing: 0

            Repeater {
              model: root.currentChildren

              delegate: Item {
                id: menuRow
                required property var modelData
                required property int index

                readonly property string rowText: String(modelData.text || "")
                readonly property string activeTitle: root.activeTrayItem
                  ? String(root.activeTrayItem.title || root.activeTrayItem.id || "")
                  : ""
                // Both only ever describe the root menu; inside a submenu the
                // first rows are real entries and must not be swallowed.
                readonly property bool atRoot: root.submenuDepth === 0
                readonly property bool rootTitleEntry: atRoot && index === 0 && modelData.hasChildren
                  && rowText.toLowerCase() === activeTitle.toLowerCase()
                readonly property bool leadingSeparator: atRoot && modelData.isSeparator && index <= 1
                readonly property bool hiddenRow: rootTitleEntry || leadingSeparator

                visible: !hiddenRow
                width: menuColumn.width
                implicitHeight: hiddenRow ? 0 : (modelData.isSeparator ? Style.space(11) : Style.space(30))
                opacity: modelData.enabled ? 1.0 : 0.45

                Rectangle {
                  visible: menuRow.modelData.isSeparator
                  anchors.left: parent.left
                  anchors.leftMargin: Style.space(10)
                  anchors.right: parent.right
                  anchors.rightMargin: Style.space(10)
                  anchors.verticalCenter: parent.verticalCenter
                  height: 1
                  color: Color.popups.border
                  opacity: 0.45
                }

                Rectangle {
                  visible: !menuRow.modelData.isSeparator
                  anchors.fill: parent
                  radius: Math.max(2, Style.cornerRadius)
                  color: rowMouse.containsMouse && menuRow.modelData.enabled
                    ? Style.hoverFillFor(root.foreground, root.accent)
                    : "transparent"
                }

                Text {
                  visible: !menuRow.modelData.isSeparator && menuRow.modelData.buttonType !== QsMenuButtonType.None
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.left: parent.left
                  width: Style.space(22)
                  horizontalAlignment: Text.AlignHCenter
                  text: menuRow.modelData.checkState === Qt.Checked ? "" : ""
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }

                Image {
                  id: menuIcon
                  visible: !menuRow.modelData.isSeparator && String(menuRow.modelData.icon || "") !== ""
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.left: parent.left
                  anchors.leftMargin: Style.space(24)
                  width: Style.space(16)
                  height: Style.space(16)
                  fillMode: Image.PreserveAspectFit
                  // Decode at physical pixels: the logical size leaves PNG
                  // icons upscaled and blurry on HiDPI displays.
                  sourceSize.width: width * Screen.devicePixelRatio
                  sourceSize.height: height * Screen.devicePixelRatio
                  source: menuRow.modelData.icon
                }

                Text {
                  visible: !menuRow.modelData.isSeparator
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.left: parent.left
                  anchors.leftMargin: menuIcon.visible ? Style.space(46) : Style.space(28)
                  anchors.right: submenuGlyph.left
                  anchors.rightMargin: Style.space(8)
                  text: menuRow.rowText
                  textFormat: Text.PlainText
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  elide: Text.ElideRight
                }

                Text {
                  id: submenuGlyph
                  visible: !menuRow.modelData.isSeparator && menuRow.modelData.hasChildren
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.right: parent.right
                  anchors.rightMargin: Style.space(10)
                  text: "\u203a"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }

                MouseArea {
                  id: rowMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  enabled: !menuRow.modelData.isSeparator && menuRow.modelData.enabled
                  cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                  onClicked: {
                    if (root.menuLevelSettling) return
                    if (menuRow.modelData.hasChildren) {
                      // Reset scroll BEFORE swapping the model: the swap
                      // destroys this delegate synchronously and ids stop
                      // resolving after.
                      menuFlick.contentY = 0
                      root.enterSubmenu(menuRow.modelData, menuRow.rowText)
                    } else {
                      menuRow.modelData.triggered()
                      root.close()
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  // Renders a tray icon, recoloring symbolic icons to the panel foreground so
  // they stay visible on any theme (a raw symbolic icon keeps its baked-in
  // fill and disappears against a matching background).
  component TrayIcon: Item {
    id: trayIconRoot
    required property var icon
    readonly property bool symbolic: root.iconIsSymbolic(icon)

    Image {
      id: trayIconImage
      anchors.fill: parent
      fillMode: Image.PreserveAspectFit
      sourceSize.width: Math.round(Math.min(width, height) * Screen.devicePixelRatio)
      sourceSize.height: Math.round(Math.min(width, height) * Screen.devicePixelRatio)
      source: root.trayIconSource(trayIconRoot.icon)
      // Kept as a hidden layer so the effect can sample it as a texture.
      visible: !trayIconRoot.symbolic
      layer.enabled: trayIconRoot.symbolic
    }

    MultiEffect {
      anchors.fill: trayIconImage
      source: trayIconImage
      visible: trayIconRoot.symbolic
      colorization: 1.0
      colorizationColor: root.foreground
    }
  }

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
