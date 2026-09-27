import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui

// The cockpit. Law 17: no page scroller. Two columns; only the commit feed
// scrolls, inside its own fixed box.
Panel {
  id: panel
  moduleName: "nixfred.shipyard"
  manageIpc: false

  required property var widget
  readonly property var svc: widget.svc
  readonly property var d: svc ? svc.data : ({})

  readonly property color foreground: widget.bar ? widget.bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.5)
  readonly property color faint: Util.alpha(foreground, 0.10)
  readonly property color accent: Color.accent
  readonly property string fontFamily: widget.bar ? widget.bar.fontFamily : Style.font.family
  readonly property int panelWidth: Style.space(1120)
  readonly property int best: Math.max(1, d.best || 1)

  function heatColor(n) {
    if (!n) return Util.alpha(foreground, 0.07)
    var r = Math.min(1, Math.sqrt(n / best))
    return Util.alpha(accent, 0.25 + 0.75 * r)
  }
  function fmt(n) { return n >= 10000 ? (n / 1000).toFixed(1) + "k" : String(n || 0) }

  component Stat: Rectangle {
    property string label: ""
    property string value: ""
    property string tip: ""
    property color valueColor: panel.foreground
    Layout.fillWidth: true
    implicitHeight: Style.space(62)
    radius: Style.space(6)
    color: panel.faint
    border.width: 1
    border.color: Util.alpha(panel.accent, 0.35)
    Column {
      anchors.centerIn: parent
      spacing: Style.space(2)
      Text { anchors.horizontalCenter: parent.horizontalCenter; text: parent.parent.value
             color: parent.parent.valueColor; font.family: panel.fontFamily
             font.pixelSize: Style.font.subtitle * 1.3; font.bold: true }
      Text { anchors.horizontalCenter: parent.horizontalCenter; text: parent.parent.label
             color: panel.dim; font.family: panel.fontFamily; font.pixelSize: Style.font.bodySmall
             font.letterSpacing: 1.5 }
    }
    MouseArea { id: sm; anchors.fill: parent; hoverEnabled: true }
    ToolTip.visible: sm.containsMouse && tip !== ""
    ToolTip.text: tip
  }

  component Caption: Text {
    color: panel.dim
    font.family: panel.fontFamily
    font.pixelSize: Style.font.bodySmall
    font.letterSpacing: 2
  }

  KeyboardPanel {
    id: kpanel
    anchorItem: panel.widget.anchorItem
    owner: panel.widget
    bar: panel.widget.bar
    open: panel.opened
    focusTarget: keyCatcher
    contentWidth: kpanel.fittedContentWidth(panel.panelWidth)
    contentHeight: kpanel.fittedContentHeight(content.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: panel.widget.close()

      ColumnLayout {
        id: content
        width: parent.width
        spacing: Style.space(12)

        // header
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(10)
          Text { text: String.fromCodePoint(0xF0031); color: panel.accent
                 font.family: panel.fontFamily; font.pixelSize: Style.font.subtitle }
          Text { text: "SHIPYARD"; color: panel.foreground; font.family: panel.fontFamily
                 font.pixelSize: Style.font.subtitle; font.bold: true; font.letterSpacing: 3 }
          Text {
            text: svc && !svc.ok ? ("error: " + svc.error)
                  : (d.scanned || 0) + " repos scanned  //  " + (d.generated || "--")
            color: svc && !svc.ok ? Color.urgent : panel.dim
            font.family: panel.fontFamily; font.pixelSize: Style.font.bodySmall
          }
          Item { Layout.fillWidth: true }
          Button {
            text: "Rescan"
            onClicked: if (svc) svc.refresh()
            ToolTip.visible: hovered; ToolTip.text: "Rescan now. Unchanged repos come from cache."
          }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: panel.faint; border.width: 0 }

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(16)

          // ---------------- left: numbers, heatmap, hours
          ColumnLayout {
            Layout.preferredWidth: panel.panelWidth * 0.46; Layout.maximumWidth: panel.panelWidth * 0.46
            Layout.alignment: Qt.AlignTop
            spacing: Style.space(12)

            RowLayout {
              Layout.fillWidth: true
              spacing: Style.space(8)
              Stat { label: "TODAY"; value: String(d.today || 0); valueColor: panel.accent
                     tip: "Commits you authored since midnight, all branches, no merges" }
              Stat { label: "STREAK"; value: (d.streak || 0) + "d"
                     tip: "Consecutive days with at least one commit. Today counts once you ship." }
              Stat { label: "REPOS"; value: String(d.repos || 0); tip: "Repos touched today" }
              Stat { label: "+ / -"; value: "+" + panel.fmt(d.add) + " -" + panel.fmt(d.del)
                     tip: "Lines added / removed today" }
              Stat { label: "7 DAYS"; value: String(d.week || 0); tip: "Commits in the last 7 days" }
            }

            Caption { text: "16 WEEKS  //  best day " + (d.best || 0) }
            Grid {
              id: heat
              Layout.fillWidth: true
              rows: 7
              flow: Grid.TopToBottom
              spacing: Style.space(3)
              readonly property real cell: Math.floor((width - 15 * spacing) / 16)
              Repeater {
                model: d.heat || []
                delegate: Rectangle {
                  required property int modelData
                  required property int index
                  width: heat.cell; height: Style.space(16)
                  radius: 2; border.width: 0
                  color: panel.heatColor(modelData)
                  MouseArea { id: hm; anchors.fill: parent; hoverEnabled: true }
                  ToolTip.visible: hm.containsMouse
                  ToolTip.text: {
                    var dt = new Date(); dt.setHours(0, 0, 0, 0)
                    dt.setDate(dt.getDate() - ((d.heat || []).length - 1 - index))
                    return Qt.formatDate(dt, "ddd MMM d") + ": " + modelData + " commits"
                  }
                }
              }
            }

            Caption { text: "TODAY BY HOUR" }
            Row {
              id: hrs
              Layout.fillWidth: true
              height: Style.space(56)
              spacing: Style.space(2)
              readonly property int peak: Math.max(1, Math.max.apply(null, d.hours || [1]))
              readonly property real bw: (width - 23 * spacing) / 24
              Repeater {
                model: d.hours || []
                delegate: Item {
                  required property int modelData
                  required property int index
                  width: hrs.bw; height: hrs.height
                  Rectangle {
                    anchors.bottom: lbl.top; anchors.bottomMargin: 2
                    width: parent.width; radius: 1; border.width: 0
                    height: Math.max(2, (parent.height - lbl.height - 2) * modelData / hrs.peak)
                    color: modelData ? panel.accent : panel.faint
                  }
                  Text { id: lbl; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
                         text: index % 3 === 0 ? String(index) : ""; color: panel.dim
                         font.family: panel.fontFamily; font.pixelSize: Style.font.bodySmall * 0.8 }
                  MouseArea { id: bm; anchors.fill: parent; hoverEnabled: true }
                  ToolTip.visible: bm.containsMouse
                  ToolTip.text: index + ":00  " + modelData + " commits"
                }
              }
            }
          }

          // ---------------- right: top repos + feed
          ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: Style.space(8)

            Caption { text: "TOP REPOS TODAY" }
            Repeater {
              model: (d.top || []).slice(0, 4)
              delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: Style.space(8)
                Text { Layout.preferredWidth: Style.space(150); text: modelData.repo; elide: Text.ElideMiddle
                       color: panel.foreground; font.family: panel.fontFamily; font.pixelSize: Style.font.bodySmall }
                Rectangle {
                  Layout.fillWidth: true; height: Style.space(8); radius: 2; color: panel.faint; border.width: 0
                  Rectangle { height: parent.height; radius: 2; border.width: 0; color: panel.accent
                              width: parent.width * modelData.n / Math.max(1, d.today || 1) }
                }
                Text { text: String(modelData.n); color: panel.dim; font.family: panel.fontFamily
                       font.pixelSize: Style.font.bodySmall }
              }
            }

            Caption { text: "FEED  //  click copies SHA" }
            Rectangle {
              Layout.fillWidth: true
              Layout.preferredHeight: Style.space(250)
              radius: Style.space(6); color: panel.faint; border.width: 0
              clip: true
              ListView {
                id: feed
                anchors.fill: parent; anchors.margins: Style.space(6)
                model: d.feed || []
                spacing: Style.space(2)
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}
                Text { anchors.centerIn: parent; visible: feed.count === 0
                       text: "Nothing shipped yet today. Go make something."
                       color: panel.dim; font.family: panel.fontFamily; font.pixelSize: Style.font.bodySmall }
                delegate: Rectangle {
                  required property var modelData
                  width: feed.width - Style.space(10)
                  height: Style.space(24)
                  radius: 3; border.width: 0
                  color: rm.containsMouse ? Util.alpha(panel.accent, 0.18) : "transparent"
                  RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 4; anchors.rightMargin: 4
                    spacing: Style.space(8)
                    Text { text: modelData.time; color: panel.accent; font.family: panel.fontFamily
                           font.pixelSize: Style.font.bodySmall }
                    Text { Layout.preferredWidth: Style.space(78); Layout.maximumWidth: Style.space(78); text: modelData.repo; elide: Text.ElideRight
                           color: panel.dim; font.family: panel.fontFamily; font.pixelSize: Style.font.bodySmall }
                    Text { Layout.fillWidth: true; Layout.preferredWidth: 100; text: modelData.subject; elide: Text.ElideRight
                           color: panel.foreground; font.family: panel.fontFamily; font.pixelSize: Style.font.bodySmall }
                    Text { text: "+" + modelData.add + " -" + modelData.del; color: panel.dim
                           font.family: panel.fontFamily; font.pixelSize: Style.font.bodySmall * 0.9 }
                  }
                  MouseArea { id: rm; anchors.fill: parent; hoverEnabled: true
                              cursorShape: Qt.PointingHandCursor
                              onClicked: if (svc) svc.copy(modelData.sha) }
                  ToolTip.visible: rm.containsMouse
                  ToolTip.text: modelData.sha + "  " + modelData.path + "\n" + modelData.subject
                }
              }
            }
          }
        }
      }
    }
  }
}
