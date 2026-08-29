import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "../Model.js" as Model

BorderSurface {
  id: root

  property var razerData: ({})
  property int globalBrightness: 100
  property string fontFamily: ""
  property color fg: Color.foreground
  property color dim: Qt.darker(fg, 1.45)
  property int dataVersion: 0
  property var bar: null

  signal setEffect(serial: string, effect: string, color: string, color2: string, param: string)
  signal setBrightness(serial: string, value: real)

  visible: root.razerData.daemon_running && root.razerData.devices.length > 0
  Layout.fillWidth: true
  color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.03)
  borderSpec: Border.flat(Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.06), 1)
  radius: Style.cornerRadius
  padding: Style.space(8)
  implicitHeight: globalControlsLayout.implicitHeight + contentTopInset + contentBottomInset

  ColumnLayout {
    id: globalControlsLayout
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
      spacing: Style.space(6)

      Text {
        text: "All Devices:"
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }

      Item { Layout.fillWidth: true }

      Button {
        text: "Spectrum"
        foreground: root.fg
        fontFamily: root.fontFamily
        fontSize: Style.font.caption
        bordered: true
        horizontalPadding: Style.space(6)
        verticalPadding: Style.space(3)
        onClicked: root.setEffect("all", "spectrum", "", "", "")
      }

      Button {
        text: "Wave"
        foreground: root.fg
        fontFamily: root.fontFamily
        fontSize: Style.font.caption
        bordered: true
        horizontalPadding: Style.space(6)
        verticalPadding: Style.space(3)
        onClicked: root.setEffect("all", "wave", "", "", "1")
      }

      Button {
        text: "Green"
        foreground: root.fg
        fontFamily: root.fontFamily
        fontSize: Style.font.caption
        bordered: true
        horizontalPadding: Style.space(6)
        verticalPadding: Style.space(3)
        onClicked: root.setEffect("all", "static", "#00ff00", "", "")
      }

      Button {
        text: "Off"
        foreground: root.fg
        fontFamily: root.fontFamily
        fontSize: Style.font.caption
        bordered: true
        horizontalPadding: Style.space(6)
        verticalPadding: Style.space(3)
        onClicked: root.setEffect("all", "none", "", "", "")
      }
    }

    // Global Brightness Slider (All Devices)
    RowLayout {
      visible: root.dataVersion >= 0 && Model.hasBrightnessSupport(root.razerData.devices)
      Layout.fillWidth: true
      spacing: Style.space(8)

      Text {
        text: "Brightness"
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        Layout.alignment: Qt.AlignVCenter
      }

      PanelSlider {
        id: globalBrightnessSlider
        bar: root.bar
        Layout.fillWidth: true
        minimum: 0
        maximum: 100
        step: 5
        integer: true
        value: root.globalBrightness
        onReleased: function(v) {
          root.setBrightness("all", v)
        }
      }

      Text {
        text: Model.formatBrightness(globalBrightnessSlider.liveValue)
        color: root.fg
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        horizontalAlignment: Text.AlignRight
        Layout.minimumWidth: Style.space(36)
        Layout.alignment: Qt.AlignVCenter
      }
    }
  }
}
