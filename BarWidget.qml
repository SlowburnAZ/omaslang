import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "SlowburnAZ.omaslang"

  readonly property var panel: panelLoader.item

  readonly property bool opened: root.panel
    ? root.panel.opened === true
    : false
  readonly property bool popoutSwitchClosing: root.panel
    ? root.panel.popoutSwitchClosing === true
    : false

  function open() {
    if (root.panel) root.panel.open()
  }

  function close() {
    if (root.panel) root.panel.close()
  }

  function toggle() {
    if (root.panel) root.panel.toggle()
  }

  function closeForPopoutSwitch() {
    if (root.panel) root.panel.closeForPopoutSwitch()
  }

  function injectPanel() {
    if (!root.panel) return
    root.panel.bar = root.bar
    root.panel.anchorItem = button
    root.panel.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\uf02d"
    dimmed: !root.panel || !root.panel.hasResults
    active: root.opened
    tooltipText: !root.panel || !root.panel.wotd
      ? "OmaSlang"
      : "OmaSlang \u2014 WOTD: " + root.panel.wotd.word
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.toggle()
      else if (buttonCode === Qt.MiddleButton && root.panel) root.panel.randomWord()
    }
  }
}
