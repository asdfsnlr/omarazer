import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.Commons
import qs.Ui
import "../Model.js" as Model

PanelWindow {
  id: root

  property string deviceSerial: ""
  property string deviceName: ""
  property string initialColor: "#00ff00"
  property bool isSecondary: false
  property string effectName: "static"

  property string currentColor: "#00ff00"
  property int rVal: 0
  property int gVal: 255
  property int bVal: 0
  property bool updatingInternals: false

  property color fg: Color.foreground
  property color dim: Color.muted
  property string fontFamily: Style.font.family

  signal closeRequested()
  signal applied(string serial, string color, bool isSecondary)

  visible: deviceSerial !== ""
  anchors { top: true; bottom: true; left: true; right: true }
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "omarchy-color-picker"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

  function setColorFromHex(hex) {
    if (!Model.isValidHex(hex)) return
    var norm = Model.normalizeHex(hex, "#00ff00")
    var rgb = Model.hexToRgb(norm)
    updatingInternals = true
    currentColor = norm
    rVal = rgb.r
    gVal = rgb.g
    bVal = rgb.b
    hexTextField.text = norm.toUpperCase()
    updatingInternals = false
  }

  function updateColorFromRgb() {
    if (updatingInternals) return
    var hex = Model.rgbToHex(rVal, gVal, bVal)
    currentColor = hex
    if (!hexTextField.activeFocus) {
      hexTextField.text = hex.toUpperCase()
    }
  }

  function applyColor() {
    if (!deviceSerial) return
    root.applied(deviceSerial, currentColor, isSecondary)
    root.closeRequested()
  }

  onDeviceSerialChanged: {
    if (deviceSerial) {
      setColorFromHex(initialColor)
    }
  }

  onInitialColorChanged: {
    if (deviceSerial) {
      setColorFromHex(initialColor)
    }
  }

  // ── Dark scrim ──
  Rectangle {
    anchors.fill: parent
    color: Color.menu.scrim
    MouseArea {
      anchors.fill: parent
      onClicked: root.closeRequested()
    }
  }

  // ── Centered Picker Card ──
  BorderSurface {
    id: card
    anchors.centerIn: parent
    width: Math.min(Style.space(480), parent.width - Style.space(40))
    implicitHeight: contentCol.implicitHeight + Style.space(32)
    color: Color.popups.background
    borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, 1)
    radius: Style.cornerRadius
    padding: Style.space(16)

    MouseArea {
      anchors.fill: parent
      onClicked: {} // swallow clicks
    }

    ColumnLayout {
      id: contentCol
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: card.padding
      spacing: Style.space(12)

      // ── Header ──
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(10)

        Button {
          text: "Back"
          foreground: Color.foreground
          fontFamily: root.fontFamily
          fontSize: Style.font.body
          bordered: true
          horizontalPadding: Style.space(8)
          verticalPadding: Style.space(4)
          onClicked: root.closeRequested()
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: Style.space(2)

          Text {
            text: (root.isSecondary ? "Custom Secondary Color" : "Custom Color Picker")
            color: Color.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
          }

          Text {
            text: root.deviceName + (root.effectName ? "  •  " + Model.effectDisplayName(root.effectName) : "")
            color: Color.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
            Layout.fillWidth: true
          }
        }

        Item { Layout.fillWidth: true }

        Button {
          text: "Apply"
          foreground: Color.accent
          fontFamily: root.fontFamily
          fontSize: Style.font.body
          bordered: true
          horizontalPadding: Style.space(10)
          verticalPadding: Style.space(4)
          onClicked: root.applyColor()
        }
      }

      PanelSeparator {
        Layout.fillWidth: true
        foreground: Color.foreground
      }

      // ── Live Color Preview Card ──
      BorderSurface {
        Layout.fillWidth: true
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.03)
        borderSpec: Border.flat(Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06), 1)
        radius: Style.cornerRadius
        padding: Style.space(12)
        implicitHeight: previewRow.implicitHeight + contentTopInset + contentBottomInset

        RowLayout {
          id: previewRow
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.topMargin: parent.contentTopInset
          anchors.rightMargin: parent.contentRightInset
          anchors.bottomMargin: parent.contentBottomInset
          anchors.leftMargin: parent.contentLeftInset
          spacing: Style.space(12)

          // Color swatch box
          Rectangle {
            width: Style.space(64)
            height: Style.space(64)
            radius: Style.space(8)
            color: root.currentColor
            border.width: 2
            border.color: Color.foreground
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.space(4)

            Text {
              text: root.currentColor.toUpperCase()
              color: Color.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
            }

            Text {
              text: "RGB: (" + root.rVal + ", " + root.gVal + ", " + root.bVal + ")"
              color: Color.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          // Previous / Initial Color Comparison Chip
          ColumnLayout {
            spacing: Style.space(2)
            Layout.alignment: Qt.AlignVCenter

            Text {
              text: "Original"
              color: Color.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            Rectangle {
              width: Style.space(28)
              height: Style.space(28)
              radius: width / 2
              color: root.initialColor
              border.width: 1
              border.color: Color.foreground

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.setColorFromHex(root.initialColor)
              }
            }
          }
        }
      }

      // ── Hex Code Input ──
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(8)

        Text {
          text: "Hex Code:"
          color: Color.muted
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          Layout.alignment: Qt.AlignVCenter
        }

        TextField {
          id: hexTextField
          Layout.fillWidth: true
          placeholderText: "#RRGGBB"
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          text: root.currentColor.toUpperCase()
          onTextChanged: {
            if (activeFocus && Model.isValidHex(text)) {
              root.setColorFromHex(text)
            }
          }
          onAccepted: {
            if (Model.isValidHex(text)) {
              root.setColorFromHex(text)
            }
          }
        }

        Button {
          text: "Set"
          fontFamily: root.fontFamily
          fontSize: Style.font.caption
          bordered: true
          horizontalPadding: Style.space(8)
          verticalPadding: Style.space(3)
          onClicked: {
            if (Model.isValidHex(hexTextField.text)) {
              root.setColorFromHex(hexTextField.text)
            }
          }
        }
      }

      // ── RGB Sliders Container ──
      BorderSurface {
        Layout.fillWidth: true
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.03)
        borderSpec: Border.flat(Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06), 1)
        radius: Style.cornerRadius
        padding: Style.space(12)
        implicitHeight: slidersCol.implicitHeight + contentTopInset + contentBottomInset

        ColumnLayout {
          id: slidersCol
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.topMargin: parent.contentTopInset
          anchors.rightMargin: parent.contentRightInset
          anchors.bottomMargin: parent.contentBottomInset
          anchors.leftMargin: parent.contentLeftInset
          spacing: Style.space(8)

          // Red Slider
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(8)

            Text {
              text: "R"
              color: "#ff0000"
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: true
              Layout.minimumWidth: Style.space(16)
            }

            PanelSlider {
              id: rSlider
              bar: null
              Layout.fillWidth: true
              minimum: 0
              maximum: 255
              step: 1
              integer: true
              value: root.rVal
              onReleased: function(v) {
                root.rVal = Math.round(v)
                root.updateColorFromRgb()
              }
            }

            Text {
              text: String(root.rVal)
              color: Color.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              horizontalAlignment: Text.AlignRight
              Layout.minimumWidth: Style.space(32)
            }
          }

          // Green Slider
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(8)

            Text {
              text: "G"
              color: "#00ff00"
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: true
              Layout.minimumWidth: Style.space(16)
            }

            PanelSlider {
              id: gSlider
              bar: null
              Layout.fillWidth: true
              minimum: 0
              maximum: 255
              step: 1
              integer: true
              value: root.gVal
              onReleased: function(v) {
                root.gVal = Math.round(v)
                root.updateColorFromRgb()
              }
            }

            Text {
              text: String(root.gVal)
              color: Color.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              horizontalAlignment: Text.AlignRight
              Layout.minimumWidth: Style.space(32)
            }
          }

          // Blue Slider
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(8)

            Text {
              text: "B"
              color: "#3b82f6"
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: true
              Layout.minimumWidth: Style.space(16)
            }

            PanelSlider {
              id: bSlider
              bar: null
              Layout.fillWidth: true
              minimum: 0
              maximum: 255
              step: 1
              integer: true
              value: root.bVal
              onReleased: function(v) {
                root.bVal = Math.round(v)
                root.updateColorFromRgb()
              }
            }

            Text {
              text: String(root.bVal)
              color: Color.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              horizontalAlignment: Text.AlignRight
              Layout.minimumWidth: Style.space(32)
            }
          }
        }
      }

      // ── Preset Quick Shortcuts (15 basic colors) ──
      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(6)

        Text {
          text: "Quick Presets:"
          color: Color.muted
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }

        Flow {
          Layout.fillWidth: true
          spacing: Style.space(5)

          Repeater {
            model: Model.paletteColors()

            delegate: Rectangle {
              id: swatch
              required property var modelData
              readonly property bool isSelected: root.currentColor.toLowerCase() === swatch.modelData.hex.toLowerCase()

              width: Style.space(20)
              height: Style.space(20)
              radius: width / 2
              color: swatch.modelData.hex
              border.width: isSelected ? 2 : 1
              border.color: isSelected ? Color.foreground : Qt.rgba(0, 0, 0, 0.3)

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.setColorFromHex(swatch.modelData.hex)
              }
            }
          }
        }
      }
    }
  }
}
