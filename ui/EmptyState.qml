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

  visible: root.razerData.daemon_running && root.razerData.devices.length === 0 && !root.loading
  Layout.fillWidth: true
  color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.04)
  borderSpec: Border.flat(Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08), 1)
  radius: Style.cornerRadius
  padding: Style.space(16)
  implicitHeight: emptyLayout.implicitHeight + contentTopInset + contentBottomInset

  ColumnLayout {
    id: emptyLayout
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.topMargin: parent.contentTopInset
    anchors.rightMargin: parent.contentRightInset
    anchors.bottomMargin: parent.contentBottomInset
    anchors.leftMargin: parent.contentLeftInset
    spacing: Style.space(6)


    Text {
      text: "No Razer Devices Connected"
      color: root.fg
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      font.bold: true
      Layout.alignment: Qt.AlignHCenter
    }

    Text {
      text: "Connect your Razer peripherals to view and manage them."
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      Layout.alignment: Qt.AlignHCenter
    }
  }
}
