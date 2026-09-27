import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// Anchor glyph, today's commit count, and the day streak.
BarWidget {
  id: root
  moduleName: "nixfred.shipyard"
  property var anchorItem: button

  readonly property var svc: bar && bar.shell ? bar.shell.serviceFor(moduleName) : null
  readonly property int today: svc ? svc.today : 0
  readonly property int streak: svc ? svc.streak : 0

  function setting(name, fallback) {
    var v = settings ? settings[name] : undefined
    return v === undefined ? fallback : v
  }
  readonly property bool showStreak: String(setting("showStreak", true)) !== "false"
  readonly property color foreground: bar ? bar.foreground : Color.foreground

  readonly property string label: String.fromCodePoint(0xF0031) + " " + today + (showStreak ? "  " + String.fromCodePoint(0xF0238) + streak : "")

  implicitWidth: vertical ? barSize : Math.max(Style.space(40), txt.implicitWidth + Style.space(16))
  implicitHeight: vertical ? Style.space(40) : barSize

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    labelVisible: false
    hasVisualContent: true
    active: false
    useActiveColor: false
    tooltipText: svc && !svc.ok
      ? "Shipyard: " + svc.error
      : "Shipyard: " + root.today + " commits today, " + root.streak + "-day streak"

    Text {
      id: txt
      anchors.centerIn: parent
      text: root.label
      color: root.today > 0 ? root.foreground : Util.alpha(root.foreground, 0.45)
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.bodySmall
    }

    onPressed: function(code) {
      if (root.bar) root.bar.hideTooltip(root)
      root.toggle()
    }
  }

  readonly property bool opened: panel.opened
  function open() { panel.controller.show(); if (svc) svc.refresh() }
  function close() { panel.controller.hide() }
  function toggle() { opened ? close() : open() }
  function closeForPopoutSwitch() { close() }
  readonly property bool popoutSwitchClosing: false

  ShipPanel {
    id: panel
    widget: root
  }
}
