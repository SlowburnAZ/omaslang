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
  property var history: []

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
    searchProc.command = ["curl", "-fsS", "--max-time", "8", Model.searchUrl(activeQuery)]
    searchProc.running = true
  }

  function randomWord() {
    debounce.stop()
    pendingQuery = ""
    activeQuery = ""
    loading = true
    statusText = "Rolling the dice\u2026"
    randomProc.running = true
  }

  function playAudio(url) {
    if (!url) return
    audioProc.command = Model.audioCommand(url)
    audioProc.running = true
  }

  function searchTerm(term) {
    input.text = term
    debounce.stop()
    root.search(term)
  }

  function copyText(text) {
    if (!text) return
    copyProc.command = Model.copyCommand(text)
    copyProc.running = true
  }

  function recordHistory(term) {
    var next = Model.addHistory(root.history, term)
    root.history = next
    historyStore.setText(JSON.stringify(next))
  }

  function loadHistory(raw) {
    root.history = Model.loadHistory(raw)
  }

  function applyResponse(response) {
    if (response.ok && response.found && response.results.length > 0) {
      results = response.results
      statusText = ""
      if (activeQuery) root.recordHistory(activeQuery)
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
    command: ["curl", "-fsS", "--max-time", "8", Model.wotdUrl()]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var response = Model.parseResponse(text)
        if (!response.ok || response.results.length === 0) return
        var entry = response.results[0]
        var record = {
          date: Model.todayString(),
          wotdDate: entry.wotdDate,
          word: entry.word,
          meaning: entry.meaning,
          example: entry.example,
          audio: entry.audio
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

  FileView {
    id: historyStore
    path: Model.historyPath(Quickshell.env("HOME"))
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadHistory(text())
    onLoadFailed: root.loadHistory("[]")
    onFileChanged: reload()
  }

  Process {
    id: searchProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyResponse(Model.parseResponse(text, root.resultLimit))
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
          root.recordHistory(response.results[0].word)
        } else {
          root.results = []
          root.statusText = response.error || "Could not fetch a random word"
        }
        root.loading = false
      }
    }
  }

  Process {
    id: audioProc
  }

  Process {
    id: copyProc
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

            Row {
              width: parent.width
              spacing: Style.space(10)

              PanelSectionHeader {
                text: "WORD OF THE DAY"
                foreground: root.barForeground
                fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                visible: root.wotd !== null && (root.wotd.wotdDate || "") !== ""
                text: root.wotd ? root.wotd.wotdDate : ""
                color: Qt.darker(root.barForeground, 1.5)
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.italic: true
                anchors.verticalCenter: parent.verticalCenter
              }

              Button {
                visible: root.wotd !== null && (root.wotd.audio || "") !== ""
                iconText: "\uf028"
                tooltipText: "Play pronunciation"
                foreground: root.barForeground
                accent: root.bar ? root.bar.urgent : Color.accent
                fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                onClicked: if (root.wotd) root.playAudio(root.wotd.audio)
              }

              Button {
                visible: root.wotd !== null
                iconText: "\uf0c5"
                tooltipText: "Copy definition"
                foreground: root.barForeground
                accent: root.bar ? root.bar.urgent : Color.accent
                fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                onClicked: if (root.wotd) root.copyText(root.wotd.word + "\n" + root.wotd.meaning)
              }

              Button {
                iconText: "\uf021"
                tooltipText: "New random word"
                foreground: root.barForeground
                accent: root.bar ? root.bar.urgent : Color.accent
                fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                onClicked: root.fetchWotd()
              }
            }

            Flickable {
              id: wotdScroll
              width: parent.width
              height: Math.min(wotdTexts.implicitHeight, Style.space(150))
              interactive: wotdTexts.implicitHeight > height
              clip: true
              boundsBehavior: Flickable.StopAtBounds
              contentWidth: width
              contentHeight: wotdTexts.implicitHeight

              Column {
                id: wotdTexts
                width: wotdScroll.width
                spacing: Style.space(4)

                Text {
                  width: parent.width
                  visible: root.wotd !== null
                  text: root.wotd ? root.wotd.word : ""
                  textFormat: Text.PlainText
                  color: root.barForeground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.subtitle
                  font.bold: true
                  wrapMode: Text.WordWrap
                }

                Text {
                  width: parent.width
                  visible: root.wotd !== null && root.wotd.meaning !== ""
                  text: root.wotd ? Model.linkifyMarkup(root.wotd.meaning, root.barForeground) : ""
                  textFormat: Text.RichText
                  color: root.barForeground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.body
                  wrapMode: Text.WordWrap
                  onLinkActivated: function(link) { root.searchTerm(link) }
                }

                Text {
                  width: parent.width
                  visible: root.wotd !== null && root.wotd.example !== ""
                  text: root.wotd ? "\u201C" + Model.linkifyMarkup(root.wotd.example, Qt.darker(root.barForeground, 1.4)) + "\u201D" : ""
                  textFormat: Text.RichText
                  color: Qt.darker(root.barForeground, 1.4)
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  font.italic: true
                  wrapMode: Text.WordWrap
                  onLinkActivated: function(link) { root.searchTerm(link) }
                }
              }
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
            spacing: Style.space(6)
            visible: input.text === "" && !root.loading && !root.hasResults && root.history.length > 0

            PanelSectionHeader {
              text: "RECENT"
              foreground: root.barForeground
              fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
            }

            Flow {
              width: parent.width
              spacing: Style.space(6)

              Repeater {
                model: root.history

                Button {
                  required property string modelData
                  text: modelData
                  foreground: root.barForeground
                  accent: root.bar ? root.bar.urgent : Color.accent
                  fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                  onClicked: root.searchTerm(modelData)
                }
              }
            }
          }

          Column {
            width: parent.width
            spacing: Style.space(12)

            Repeater {
              model: root.results

              Row {
                id: resultDelegate
                required property var modelData
                required property int index

                property string localThumb: ""

                width: parent.width
                spacing: Style.space(10)

                Component.onCompleted: {
                  var url = modelData.thumb || ""
                  var defid = modelData.defid || ""
                  if (url === "" || defid === "") return
                  var cachePath = Model.thumbCachePath(Quickshell.env("HOME"), defid)
                  thumbProc.command = Model.thumbCommand(url, cachePath)
                  thumbProc.running = true
                }

                Process {
                  id: thumbProc
                  onExited: function(exitCode) {
                    if (exitCode === 0)
                      resultDelegate.localThumb = "file://" + Model.thumbCachePath(Quickshell.env("HOME"), modelData.defid)
                  }
                }

                Rectangle {
                  id: resultThumbFrame
                  visible: resultDelegate.localThumb !== "" && resultThumb.status !== Image.Error
                  width: Style.space(120)
                  height: Style.space(68)
                  radius: Style.space(4)
                  color: "transparent"
                  clip: true

                  Image {
                    id: resultThumb
                    anchors.fill: parent
                    asynchronous: true
                    cache: true
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 240
                    source: resultDelegate.localThumb
                  }
                }

                Column {
                  width: parent.width - (resultThumbFrame.visible ? resultThumbFrame.width + parent.spacing : 0)
                  spacing: Style.space(4)

                  Row {
                    width: parent.width
                    spacing: Style.space(8)

                    Text {
                      width: parent.width - actionsRow.implicitWidth - parent.spacing
                      text: modelData.word
                      textFormat: Text.PlainText
                      color: root.barForeground
                      font.family: root.bar ? root.bar.fontFamily : Style.font.family
                      font.pixelSize: Style.font.subtitle
                      font.bold: true
                      wrapMode: Text.WordWrap
                    }

                    Row {
                      id: actionsRow
                      spacing: Style.space(4)

                      Button {
                        id: soundBtn
                        visible: (modelData.audio || "") !== ""
                        iconText: "\uf028"
                        tooltipText: "Play pronunciation"
                        foreground: root.barForeground
                        accent: root.bar ? root.bar.urgent : Color.accent
                        fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                        onClicked: root.playAudio(modelData.audio)
                      }

                      Button {
                        id: copyBtn
                        iconText: "\uf0c5"
                        tooltipText: "Copy definition"
                        foreground: root.barForeground
                        accent: root.bar ? root.bar.urgent : Color.accent
                        fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
                        onClicked: root.copyText(modelData.word + "\n" + modelData.meaning)
                      }
                    }
                  }

                  Text {
                    width: parent.width
                    visible: modelData.meaning !== ""
                    text: Model.linkifyMarkup(modelData.meaning, root.barForeground)
                    textFormat: Text.RichText
                    color: root.barForeground
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.body
                    wrapMode: Text.WordWrap
                    onLinkActivated: function(link) { root.searchTerm(link) }
                  }

                  Text {
                    width: parent.width
                    visible: modelData.example !== ""
                    text: "\u201C" + Model.linkifyMarkup(modelData.example, Qt.darker(root.barForeground, 1.4)) + "\u201D"
                    textFormat: Text.RichText
                    color: Qt.darker(root.barForeground, 1.4)
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    font.italic: true
                    wrapMode: Text.WordWrap
                    onLinkActivated: function(link) { root.searchTerm(link) }
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
          }

          Text {
            visible: root.hasResults
            text: "via api.urbandictionary.com"
            color: Qt.darker(root.barForeground, 1.6)
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
          }
        }
      }
    }
  }
}
