import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "slowburnaz.omaslang"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null

  readonly property int resultLimit: 8

  property var results: []
  property bool loading: false
  property bool hasResults: results.length > 0
  property string statusText: "Type to search Urban Dictionary"
  property string pendingQuery: ""
  property string activeQuery: ""

  property var wotd: null

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.hostWidget || root, direction)
    return false
  }

  function open() {
    root.controller.show()
    root.refreshWotd()
    Qt.callLater(function() {
      input.forceActiveFocus()
      input.selectAll()
    })
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function search(term) {
    var q = (term || "").trim()
    if (q === "") {
      pendingQuery = ""
      activeQuery = ""
      loading = false
      results = []
      statusText = "Type to search Urban Dictionary"
      return
    }
    pendingQuery = q
    if (!searchProc.running) startSearch()
  }

  function startSearch() {
    activeQuery = pendingQuery
    loading = true
    statusText = "Searching \u201C" + activeQuery + "\u201D\u2026"
    searchProc.command = ["curl", "-fsS", "--max-time", "8", Model.searchUrl(activeQuery, root.resultLimit)]
    searchProc.running = true
  }

  function randomWord() {
    pendingQuery = ""
    activeQuery = ""
    loading = true
    statusText = "Rolling the dice\u2026"
    randomProc.running = true
  }

  function applyResponse(response) {
    if (response.ok && response.found && response.results.length > 0) {
      results = response.results
      statusText = ""
    } else if (response.ok && !response.found) {
      results = []
      statusText = "No definitions for \u201C" + activeQuery + "\u201D"
    } else {
      results = []
      statusText = response.error || "Something went wrong"
    }
    loading = false
    if (pendingQuery !== activeQuery) Qt.callLater(startSearch)
  }

  function loadWotd(raw) {
    var record = null
    try { record = JSON.parse(raw || "null") } catch (e) { record = null }
    if (record && record.date === Model.todayString()) {
      wotd = record
      return
    }
    fetchWotd()
  }

  function refreshWotd() {
    if (wotd && wotd.date === Model.todayString()) return
    fetchWotd()
  }

  function fetchWotd() {
    if (wotdProc.running) return
    wotdProc.running = true
  }

  Process {
    id: wotdProc
    command: ["curl", "-fsS", "--max-time", "8", Model.randomUrl()]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var response = Model.parseResponse(text)
        if (!response.ok || response.results.length === 0) return
        var entry = response.results[0]
        var record = {
          date: Model.todayString(),
          word: entry.word,
          meaning: entry.meaning,
          example: entry.example
        }
        root.wotd = record
        wotdStore.setText(JSON.stringify(record))
      }
    }
  }

  FileView {
    id: wotdStore
    path: Quickshell.env("HOME") + "/.local/state/omarchy/omaslang-wotd.json"
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadWotd(text())
    onLoadFailed: root.fetchWotd()
    onFileChanged: reload()
  }

  Process {
    id: searchProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyResponse(Model.parseResponse(text))
    }
  }

  Process {
    id: randomProc
    command: ["curl", "-fsS", "--max-time", "8", Model.randomUrl()]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var response = Model.parseResponse(text)
        if (response.ok && response.results.length > 0) {
          root.results = response.results
          root.statusText = ""
        } else {
          root.results = []
          root.statusText = response.error || "Could not fetch a random word"
        }
        root.loading = false
      }
    }
  }

  Timer {
    id: debounce
    interval: 400
    onTriggered: root.search(input.text)
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(480))
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: input.activeFocus
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      ScrollView {
        id: scrollArea
        anchors.fill: parent
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: panelColumn.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

        Column {
          id: panelColumn
          width: scrollArea.availableWidth
          spacing: Style.space(14)

          Item {
            width: parent.width
            implicitHeight: heroIcon.implicitHeight
            Text {
              id: heroIcon
              text: "\uf02d"
              color: root.barForeground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.display
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }
            Text {
              text: "OmaSlang"
              color: root.barForeground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.title
              font.bold: true
              anchors.left: heroIcon.right
              anchors.leftMargin: Style.space(14)
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          Column {
            width: parent.width
            spacing: Style.space(4)
            visible: root.wotd !== null

            PanelSectionHeader {
              text: "WORD OF THE DAY"
              foreground: root.barForeground
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            }

            Text {
              width: parent.width
              visible: root.wotd !== null
              text: root.wotd ? root.wotd.word : ""
              color: root.barForeground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.subtitle
              font.bold: true
              wrapMode: Text.WordWrap
            }

            Text {
              width: parent.width
              visible: root.wotd !== null && root.wotd.meaning !== ""
              text: root.wotd ? root.wotd.meaning : ""
              color: root.barForeground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.body
              wrapMode: Text.WordWrap
            }

            Text {
              width: parent.width
              visible: root.wotd !== null && root.wotd.example !== ""
              text: root.wotd ? "\u201C" + root.wotd.example + "\u201D" : ""
              color: Qt.darker(root.barForeground, 1.4)
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.bodySmall
              font.italic: true
              wrapMode: Text.WordWrap
            }
          }

          PanelSeparator { foreground: root.barForeground }

          Row {
            width: parent.width
            spacing: Style.spacing.controlGap

            TextField {
              id: input
              width: parent.width - randomButton.implicitWidth - parent.spacing
              placeholderText: "Search a word or phrase\u2026"
              foreground: root.barForeground
              accent: root.bar ? root.bar.urgent : Color.accent

              onTextChanged: debounce.restart()
              onAccepted: {
                debounce.stop()
                root.search(text)
              }
              Keys.onEscapePressed: root.close()
            }

            Button {
              id: randomButton
              text: "Random"
              tooltipText: "Fetch a random word"
              foreground: root.barForeground
              accent: root.bar ? root.bar.urgent : Color.accent
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
              onClicked: {
                input.text = ""
                root.randomWord()
              }
            }
          }

          Text {
            visible: root.statusText !== ""
            text: root.loading ? "Loading\u2026" : root.statusText
            color: Qt.darker(root.barForeground, 1.5)
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.bodySmall
            font.italic: true
          }

          Column {
            width: parent.width
            spacing: Style.space(12)

            Repeater {
              model: root.results

              Column {
                required property var modelData
                required property int index

                width: parent.width
                spacing: Style.space(4)

                Text {
                  width: parent.width
                  text: modelData.word
                  color: root.barForeground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.subtitle
                  font.bold: true
                  wrapMode: Text.WordWrap
                }

                Text {
                  width: parent.width
                  visible: modelData.meaning !== ""
                  text: modelData.meaning
                  color: root.barForeground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.body
                  wrapMode: Text.WordWrap
                }

                Text {
                  width: parent.width
                  visible: modelData.example !== ""
                  text: "\u201C" + modelData.example + "\u201D"
                  color: Qt.darker(root.barForeground, 1.4)
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  font.italic: true
                  wrapMode: Text.WordWrap
                }

                Rectangle {
                  visible: index < root.results.length - 1
                  width: parent.width
                  height: Style.spacing.hairline
                  color: root.barForeground
                  opacity: 0.12
                }
              }
            }
          }

          Text {
            visible: root.hasResults
            text: "via unofficialurbandictionaryapi.com"
            color: Qt.darker(root.barForeground, 1.6)
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
          }
        }
      }
    }
  }
}
