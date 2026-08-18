import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

BorderSurface {
  id: root

  property var razerData: ({})
  property bool loading: false
  property string fontFamily: ""
  property color fg: Color.foreground
  property color dim: Qt.darker(fg, 1.45)

  signal restartDaemon()
  signal refreshRequested()

  visible: !root.razerData.daemon_running && !root.loading
  Layout.fillWidth: true
  color: Qt.rgba(1, 0.3, 0.3, 0.08)
  borderSpec: Border.flat(Qt.rgba(1, 0.3, 0.3, 0.25), 1)
  radius: Style.cornerRadius
  padding: Style.space(12)
  implicitHeight: errorLayout.implicitHeight + contentTopInset + contentBottomInset

  ColumnLayout {
    id: errorLayout
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.topMargin: parent.contentTopInset
    anchors.rightMargin: parent.contentRightInset
    anchors.bottomMargin: parent.contentBottomInset
    anchors.leftMargin: parent.contentLeftInset
    spacing: Style.space(8)

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(8)

      Text {
        text: "󰅚"
        color: "#ef4444"
        font.family: root.fontFamily
        font.pixelSize: Style.font.title
      }

      Text {
        text: "Daemon Not Running"
        color: "#ef4444"
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
        Layout.fillWidth: true
      }
    }

    Text {
      text: root.razerData.error || "The OpenRazer daemon is not reachable."
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
      Layout.fillWidth: true
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(8)

      Button {
        text: "Start Daemon"
        iconText: "󰐊"
        foreground: root.fg
        fontFamily: root.fontFamily
        fontSize: Style.font.caption
        bordered: true
        onClicked: root.restartDaemon()
      }

      Button {
        text: "Retry"
        iconText: "󰑐"
        foreground: root.fg
        fontFamily: root.fontFamily
        fontSize: Style.font.caption
        bordered: true
        onClicked: root.refreshRequested()
      }
    }
  }
}
