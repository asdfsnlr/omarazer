import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "../Model.js" as Model

BorderSurface {
  id: root

  property var modelData: ({})
  property string fontFamily: ""
  property color fg: Color.foreground
  property color dim: Qt.darker(fg, 1.45)
  property var bar: null
  property bool perKeyActive: false
  property var deviceEffects: ({})
  property var deviceSpeeds: ({})
  property string deviceKey: ""
  property string currentEffect: "static"
  property string currentSpeed: ""

  signal setBrightness(serial: string, value: real)
  signal setEffect(serial: string, effect: string, color: string, color2: string, param: string)
  signal openPerKeyEditor(device: var)

  color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.03)
  borderSpec: Border.flat(Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.06), 1)
  radius: Style.cornerRadius
  padding: Style.space(8)
  implicitHeight: contentColumn.implicitHeight + contentTopInset + contentBottomInset

  ColumnLayout {
    id: contentColumn
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.topMargin: parent.contentTopInset
    anchors.rightMargin: parent.contentRightInset
    anchors.bottomMargin: parent.contentBottomInset
    anchors.leftMargin: parent.contentLeftInset
    spacing: Style.space(8)

    // ── Per-Key Lighting (keyboard-only) ──
    BorderSurface {
      visible: Model.hasPerKeyLighting(root.modelData)
      Layout.fillWidth: true
      color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.03)
      borderSpec: Border.flat(Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.06), 1)
      radius: Style.cornerRadius
      padding: Style.space(8)
      implicitHeight: perKeyRow.implicitHeight + contentTopInset + contentBottomInset

      RowLayout {
        id: perKeyRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: parent.contentTopInset
        anchors.rightMargin: parent.contentRightInset
        anchors.bottomMargin: parent.contentBottomInset
        anchors.leftMargin: parent.contentLeftInset
        spacing: Style.space(6)

        Text {
          text: "󰌌"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          Layout.alignment: Qt.AlignVCenter
        }

        Text {
          text: "Per-Key Lighting"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          Layout.alignment: Qt.AlignVCenter
        }

        Item { Layout.fillWidth: true }

        Button {
          text: "Open"
          iconText: "󰒓"
          foreground: root.fg
          fontFamily: root.fontFamily
          fontSize: Style.font.caption
          bordered: true
          horizontalPadding: Style.space(8)
          verticalPadding: Style.space(4)
          onClicked: root.openPerKeyEditor(root.modelData)
        }
      }
    }

    // ── Categorized Effect Buttons Container ──
    BorderSurface {
      Layout.fillWidth: true
      color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.03)
      borderSpec: Border.flat(Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.06), 1)
      radius: Style.cornerRadius
      padding: Style.space(8)
      implicitHeight: categoriesColumn.implicitHeight + contentTopInset + contentBottomInset

      ColumnLayout {
        id: categoriesColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: parent.contentTopInset
        anchors.rightMargin: parent.contentRightInset
        anchors.bottomMargin: parent.contentBottomInset
        anchors.leftMargin: parent.contentLeftInset
        spacing: Style.space(8)

        Repeater {
          model: Model.categorizedEffects(root.modelData)

          delegate: ColumnLayout {
            id: categoryLayout
            required property var modelData
            Layout.fillWidth: true
            spacing: Style.space(4)

            RowLayout {
              Layout.fillWidth: true
              spacing: Style.space(5)

              Text {
                text: categoryLayout.modelData.icon
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }

              Text {
                text: categoryLayout.modelData.label
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }

              Item { Layout.fillWidth: true }
            }

            Flow {
              Layout.fillWidth: true
              spacing: Style.space(4)

              Repeater {
                model: categoryLayout.modelData.effects

                delegate: Button {
                  id: effectBtn
                  required property string modelData

                  text: Model.effectDisplayName(effectBtn.modelData)
                  iconText: Model.effectIcon(effectBtn.modelData)
                  selected: !root.perKeyActive && Model.isEffectSelected(root.modelData.current_effect, effectBtn.modelData)
                  bordered: true
                  fontFamily: root.fontFamily
                  fontSize: Style.font.caption
                  horizontalPadding: Style.space(6)
                  verticalPadding: Style.space(3)
                  onClicked: {
                    var spd = Model.needsSpeed(effectBtn.modelData) ? root.currentSpeed : null
                    root.setEffect(root.modelData.serial, effectBtn.modelData, Model.primaryColor(root.modelData), Model.secondaryColor(root.modelData), spd)
                  }
                }
              }
            }
          }
        }
      }
    }

    // ── Active Effect Customization / Parameter Options Card ──
    BorderSurface {
      visible: !root.perKeyActive && Model.hasCustomizationOptions(root.modelData)
      Layout.fillWidth: true
      color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.03)
      borderSpec: Border.flat(Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.06), 1)
      radius: Style.cornerRadius
      padding: Style.space(8)
      implicitHeight: paramsColumn.implicitHeight + contentTopInset + contentBottomInset

      ColumnLayout {
        id: paramsColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: parent.contentTopInset
        anchors.rightMargin: parent.contentRightInset
        anchors.bottomMargin: parent.contentBottomInset
        anchors.leftMargin: parent.contentLeftInset
        spacing: Style.space(6)

        // Settings Header
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(6)

          Text {
            text: "󰌵"
            color: Color.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          Text {
            text: Model.effectDisplayName(root.modelData.current_effect) + " Options" + (Model.needsSpeed(root.modelData.current_effect) ? " • " + Model.formatSpeed(root.currentSpeed) : "")
            color: root.fg
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }

          Item { Layout.fillWidth: true }
        }

        // Breathing Mode Switcher
        RowLayout {
          visible: Model.isBreathingEffect(root.modelData.current_effect) && (Model.hasEffect(root.modelData, "breath_random") || Model.hasEffect(root.modelData, "breath_dual"))
          Layout.fillWidth: true
          spacing: Style.space(6)

          Text {
            text: "Mode:"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            Layout.alignment: Qt.AlignVCenter
            Layout.minimumWidth: Style.space(48)
          }

          Button {
            visible: Model.hasEffect(root.modelData, "breath_single")
            text: "Single Color"
            iconText: "󰔄"
            fontFamily: root.fontFamily
            fontSize: Style.font.caption
            bordered: true
            selected: String(root.modelData.current_effect || "").toLowerCase() === "breath_single" || String(root.modelData.current_effect || "").toLowerCase() === "breath"
            horizontalPadding: Style.space(6)
            verticalPadding: Style.space(2)
            onClicked: root.setEffect(root.modelData.serial, "breath_single", Model.primaryColor(root.modelData), "", "")
          }

          Button {
            visible: Model.hasEffect(root.modelData, "breath_random")
            text: "Random"
            iconText: "󰔄"
            fontFamily: root.fontFamily
            fontSize: Style.font.caption
            bordered: true
            selected: String(root.modelData.current_effect || "").toLowerCase() === "breath_random"
            horizontalPadding: Style.space(6)
            verticalPadding: Style.space(2)
            onClicked: root.setEffect(root.modelData.serial, "breath_random", "", "", "")
          }
        }

        // Ripple Mode Switcher
        RowLayout {
          visible: Model.isRippleEffect(root.modelData.current_effect) && Model.hasEffect(root.modelData, "ripple_random")
          Layout.fillWidth: true
          spacing: Style.space(6)

          Text {
            text: "Mode:"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            Layout.alignment: Qt.AlignVCenter
            Layout.minimumWidth: Style.space(48)
          }

          Button {
            visible: Model.hasEffect(root.modelData, "ripple")
            text: "Single Color"
            iconText: "󰑈"
            fontFamily: root.fontFamily
            fontSize: Style.font.caption
            bordered: true
            selected: String(root.modelData.current_effect || "").toLowerCase() === "ripple"
            horizontalPadding: Style.space(6)
            verticalPadding: Style.space(2)
            onClicked: root.setEffect(root.modelData.serial, "ripple", Model.primaryColor(root.modelData), "", root.currentSpeed)
          }

          Button {
            visible: Model.hasEffect(root.modelData, "ripple_random")
            text: "Random"
            iconText: "󰑈"
            fontFamily: root.fontFamily
            fontSize: Style.font.caption
            bordered: true
            selected: String(root.modelData.current_effect || "").toLowerCase() === "ripple_random"
            horizontalPadding: Style.space(6)
            verticalPadding: Style.space(2)
            onClicked: root.setEffect(root.modelData.serial, "ripple_random", "", "", root.currentSpeed)
          }
        }

        // Starlight Mode Switcher
        RowLayout {
          visible: Model.isStarlightEffect(root.modelData.current_effect) && (Model.hasEffect(root.modelData, "starlight_random") || Model.hasEffect(root.modelData, "starlight_single") || Model.hasEffect(root.modelData, "starlight_dual"))
          Layout.fillWidth: true
          spacing: Style.space(6)

          Text {
            text: "Mode:"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            Layout.alignment: Qt.AlignVCenter
            Layout.minimumWidth: Style.space(48)
          }

          Button {
            visible: Model.hasEffect(root.modelData, "starlight_random")
            text: "Random"
            iconText: "󰵚"
            fontFamily: root.fontFamily
            fontSize: Style.font.caption
            bordered: true
            selected: String(root.modelData.current_effect || "").toLowerCase() === "starlight_random" || String(root.modelData.current_effect || "").toLowerCase() === "starlight"
            horizontalPadding: Style.space(6)
            verticalPadding: Style.space(2)
            onClicked: root.setEffect(root.modelData.serial, "starlight_random", "", "", root.currentSpeed)
          }

          Button {
            visible: Model.hasEffect(root.modelData, "starlight_single")
            text: "Single Color"
            iconText: "󰵚"
            fontFamily: root.fontFamily
            fontSize: Style.font.caption
            bordered: true
            selected: String(root.modelData.current_effect || "").toLowerCase() === "starlight_single"
            horizontalPadding: Style.space(6)
            verticalPadding: Style.space(2)
            onClicked: root.setEffect(root.modelData.serial, "starlight_single", Model.primaryColor(root.modelData), "", root.currentSpeed)
          }

          Button {
            visible: Model.hasEffect(root.modelData, "starlight_dual")
            text: "Dual"
            iconText: "󰵚"
            fontFamily: root.fontFamily
            fontSize: Style.font.caption
            bordered: true
            selected: String(root.modelData.current_effect || "").toLowerCase() === "starlight_dual"
            horizontalPadding: Style.space(6)
            verticalPadding: Style.space(2)
            onClicked: root.setEffect(root.modelData.serial, "starlight_dual", Model.primaryColor(root.modelData), Model.secondaryColor(root.modelData), root.currentSpeed)
          }
        }

        // Primary Color Palette Selector
        RowLayout {
          visible: !root.perKeyActive && Model.needsColor(root.modelData.current_effect)
          Layout.fillWidth: true
          spacing: Style.space(6)

          Text {
            text: Model.needsSecondaryColor(root.modelData.current_effect) ? "Color 1:" : "Color:"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            Layout.alignment: Qt.AlignVCenter
            Layout.minimumWidth: Style.space(48)
          }

          Flow {
            Layout.fillWidth: true
            spacing: Style.space(5)

            Repeater {
              model: Model.paletteColors()

              delegate: Rectangle {
                id: swatch
                required property var modelData

                readonly property bool isSelected: Model.primaryColor(root.modelData).toLowerCase() === swatch.modelData.hex.toLowerCase()

                width: Style.space(16)
                height: Style.space(16)
                radius: width / 2
                color: swatch.modelData.hex
                border.width: isSelected ? 2 : 1
                border.color: isSelected ? "#ffffff" : Qt.rgba(0, 0, 0, 0.3)

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    var eff = root.modelData.current_effect || "static"
                    var spd = Model.needsSpeed(eff) ? root.currentSpeed : null
                    root.setEffect(root.modelData.serial, eff, swatch.modelData.hex, Model.secondaryColor(root.modelData), spd)
                  }
                }
              }
            }
          }
        }

        // Secondary Color Palette Selector
        RowLayout {
          visible: !root.perKeyActive && Model.needsSecondaryColor(root.modelData.current_effect)
          Layout.fillWidth: true
          spacing: Style.space(6)

          Text {
            text: "Color 2:"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            Layout.alignment: Qt.AlignVCenter
            Layout.minimumWidth: Style.space(48)
          }

          Flow {
            Layout.fillWidth: true
            spacing: Style.space(5)

            Repeater {
              model: Model.paletteColors()

              delegate: Rectangle {
                id: swatch2
                required property var modelData

                readonly property bool isSelected: Model.secondaryColor(root.modelData).toLowerCase() === swatch2.modelData.hex.toLowerCase()

                width: Style.space(16)
                height: Style.space(16)
                radius: width / 2
                color: swatch2.modelData.hex
                border.width: isSelected ? 2 : 1
                border.color: isSelected ? "#ffffff" : Qt.rgba(0, 0, 0, 0.3)

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    var eff = root.modelData.current_effect || "starlight_dual"
                    var spd = Model.needsSpeed(eff) ? root.currentSpeed : null
                    root.setEffect(root.modelData.serial, eff, Model.primaryColor(root.modelData), swatch2.modelData.hex, spd)
                  }
                }
              }
            }
          }
        }

        // Wave Direction Selector
        RowLayout {
          visible: !root.perKeyActive && Model.needsDirection(root.modelData.current_effect)
          Layout.fillWidth: true
          spacing: Style.space(6)

          Text {
            text: "Direction:"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            Layout.alignment: Qt.AlignVCenter
            Layout.minimumWidth: Style.space(48)
          }

          Button {
            text: "Left"
            iconText: "󰁍"
            fontFamily: root.fontFamily
            fontSize: Style.font.caption
            bordered: true
            horizontalPadding: Style.space(6)
            verticalPadding: Style.space(2)
            onClicked: root.setEffect(root.modelData.serial, "wave", "", "", "2")
          }

          Button {
            text: "Right"
            iconText: "󰁔"
            fontFamily: root.fontFamily
            fontSize: Style.font.caption
            bordered: true
            horizontalPadding: Style.space(6)
            verticalPadding: Style.space(2)
            onClicked: root.setEffect(root.modelData.serial, "wave", "", "", "1")
          }
        }

        // Speed Selector
        RowLayout {
          visible: !root.perKeyActive && Model.needsSpeed(root.modelData.current_effect)
          Layout.fillWidth: true
          spacing: Style.space(6)

          Text {
            text: "Speed:"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            Layout.alignment: Qt.AlignVCenter
            Layout.minimumWidth: Style.space(48)
          }

          Repeater {
            model: Model.speedLevels(root.modelData.current_effect)

            delegate: Button {
              id: speedBtn
              required property var modelData

              readonly property bool isSelected: root.currentSpeed === speedBtn.modelData.value

              text: speedBtn.modelData.label
              iconText: speedBtn.modelData.icon
              tooltipText: speedBtn.modelData.desc
              selected: isSelected
              bordered: true
              fontFamily: root.fontFamily
              fontSize: Style.font.caption
              horizontalPadding: Style.space(6)
              verticalPadding: Style.space(2)
              onClicked: {
                var eff = root.modelData.current_effect || "reactive"
                root.setEffect(
                  root.modelData.serial,
                  eff,
                  Model.primaryColor(root.modelData),
                  Model.secondaryColor(root.modelData),
                  speedBtn.modelData.value
                )
              }
            }
          }
        }
      }
    }
  }
}
