import QtQuick
import Quickshell
import Quickshell.Io

// One poll of shipyard.py, relayed to the bar and the panel.
//
// The collector caches per repo on the mtimes of .git refs, so a warm poll of
// ~200 repos is under 100 ms. Only the first poll of the day walks every log.
Item {
  id: root

  property var settings: ({})
  readonly property string pluginDir: decodeURIComponent(String(Qt.resolvedUrl(".")).replace(/^file:\/\/(localhost)?/, ""))

  property bool ready: false
  property bool ok: true
  property string error: ""
  property var data: ({})
  readonly property int today: data.today || 0
  readonly property int streak: data.streak || 0

  readonly property int refreshSec: {
    var n = parseInt(String(settings && settings.refreshSec !== undefined ? settings.refreshSec : 60), 10)
    return isFinite(n) ? Math.max(15, Math.min(900, n)) : 60
  }

  function apply(text) {
    var d
    try { d = JSON.parse(text) } catch (e) { ok = false; error = "bad JSON from shipyard.py"; return }
    ok = !!d.ok
    error = d.error || ""
    if (d.ok) data = d
    ready = true
  }

  Process {
    id: poll
    command: ["python3", root.pluginDir + "shipyard.py"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.apply(text)
    }
  }

  Process { id: clip }

  function refresh() { if (!poll.running) poll.running = true }
  function copy(s) { clip.command = ["wl-copy", String(s)]; clip.running = true }

  Timer {
    interval: root.refreshSec * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }
}
