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
  property int currentDpi: 800
  property int maxDpi: 16000
  property var activePresets: [800, 1200, 1800, 2400, 3200]

  property int selectedDpi: 800
  property var presets: [800, 1200, 1800, 2400, 3200]
  property var profileNames: []
  property string selectedProfile: "Default"
  property string profileNameInput: ""
  property bool profileInputActive: false
  property bool hasChanges: false
  property string addStepInput: ""
  property bool addStepInputActive: false

  property color fg: Color.foreground
  property color dim: Color.muted
  property string fontFamily: Style.font.family

  signal closeRequested()
  signal applied(string serial, int dpi, var presets)
  signal presetsUpdated(string serial, var presets)

  visible: deviceSerial !== ""
  anchors { top: true; bottom: true; left: true; right: true }
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "omarchy-dpi-editor"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

  function pathFromUrl(url) {
    var value = String(url || "")
    if (value.indexOf("file://") === 0)
      return decodeURIComponent(value.substring(7))
    return value
  }

  function fetchProfiles() {
    profileListProc.command = ["python3", pathFromUrl(Qt.resolvedUrl("../scripts/razer_devices.py")), "--list-dpi-profiles"]
    profileListProc.running = true
  }

  function loadProfile(name) {
    if (!name) return
    loadProfileProc.command = ["python3", pathFromUrl(Qt.resolvedUrl("../scripts/razer_devices.py")), "--load-dpi-profile", name]
    loadProfileProc.running = true
  }

  function saveProfile(name) {
    if (!name || !name.trim()) return
    var data = {
      name: name.trim(),
      presets: presets.slice(),
      dpi: selectedDpi
    }
    saveProfileProc.command = ["python3", pathFromUrl(Qt.resolvedUrl("../scripts/razer_devices.py")), "--save-dpi-profile", name.trim(), JSON.stringify(data)]
    saveProfileProc.running = true
  }

  function deleteProfile(name) {
    if (!name) return
    deleteProfileProc.command = ["python3", pathFromUrl(Qt.resolvedUrl("../scripts/razer_devices.py")), "--delete-dpi-profile", name]
    deleteProfileProc.running = true
  }

  function applyToDevice() {
    if (!deviceSerial) return
    applyProc.command = ["python3", pathFromUrl(Qt.resolvedUrl("../scripts/razer_devices.py")), "--set-dpi", deviceSerial, String(selectedDpi)]
    applyProc.running = true
    root.applied(deviceSerial, selectedDpi, presets.slice())
    root.presetsUpdated(deviceSerial, presets.slice())
    hasChanges = false
  }

  function addPresetStep(val) {
    var num = parseInt(val, 10)
    if (isNaN(num)) return
    var sanitized = Model.sanitizeDpi(num, maxDpi)
    var copy = presets.slice()
    if (copy.indexOf(sanitized) === -1) {
      copy.push(sanitized)
      presets = Model.sortDpiPresets(copy, maxDpi)
      hasChanges = true
      root.presetsUpdated(deviceSerial, presets.slice())
    }
  }

  function removePresetStep(val) {
    if (presets.length <= 1) return
    var copy = presets.filter(function(p) { return p !== val })
    presets = copy
    hasChanges = true
    root.presetsUpdated(deviceSerial, presets.slice())
  }

  function setPresetTemplate(templatePresets) {
    presets = Model.sortDpiPresets(templatePresets, maxDpi)
    if (presets.indexOf(selectedDpi) === -1 && presets.length > 0) {
      selectedDpi = presets[0]
    }
    hasChanges = true
    root.presetsUpdated(deviceSerial, presets.slice())
  }


  onDeviceSerialChanged: {
    if (deviceSerial) {
      selectedDpi = currentDpi > 0 ? currentDpi : 800
      if (Array.isArray(activePresets) && activePresets.length > 0) {
        presets = Model.sortDpiPresets(activePresets, maxDpi)
      } else {
        presets = Model.defaultDpiPresets()
      }
      hasChanges = false
      fetchProfiles()
    }
  }

  onCurrentDpiChanged: {
    if (currentDpi > 0) {
      selectedDpi = currentDpi
    }
  }

  Process {
    id: applyProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        // finished apply
      }
    }
  }

  Process {
    id: profileListProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var names = JSON.parse(text.trim())
          if (Array.isArray(names)) {
            profileNames = names
          }
        } catch (e) {
          profileNames = Model.defaultDpiProfiles()
        }
      }
    }
  }

  Process {
    id: saveProfileProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        fetchProfiles()
      }
    }
  }

  Process {
    id: loadProfileProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var data = JSON.parse(text.trim())
          if (data && Array.isArray(data.presets)) {
            presets = Model.sortDpiPresets(data.presets, root.maxDpi)
            if (data.dpi) {
              selectedDpi = Model.sanitizeDpi(data.dpi, root.maxDpi)
            } else if (presets.length > 0) {
              selectedDpi = presets[0]
            }
            hasChanges = true
            root.presetsUpdated(root.deviceSerial, presets.slice())
          }
        } catch (e) {
          // ignore parse errors
        }
      }
    }
  }

  Process {
    id: deleteProfileProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        selectedProfile = "Default"
        fetchProfiles()
      }
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

  // ── Centered editor card ──
  BorderSurface {
    id: card
    anchors.centerIn: parent
    width: Math.min(Style.space(560), parent.width - Style.space(40))
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
            text: "DPI Sensitivity & Presets"
            color: Color.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
          }

          Text {
            text: root.deviceName + "  •  Max " + root.maxDpi + " DPI"
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
          onClicked: root.applyToDevice()
        }
      }

      // ── Profiles Bar ──
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(6)

        Text {
          text: "Profiles:"
          color: Color.muted
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          Layout.alignment: Qt.AlignVCenter
        }

        // Styled dropdown
        Item {
          Layout.fillWidth: true
          Layout.maximumWidth: Style.space(180)
          Layout.preferredHeight: profileDropdown.implicitHeight

          Button {
            id: profileDropdown
            anchors.fill: parent
            text: (root.selectedProfile || "Select profile...") + "  󰅀"
            foreground: root.selectedProfile ? Color.foreground : Color.muted
            fontFamily: root.fontFamily
            fontSize: Style.font.caption
            bordered: true
            horizontalPadding: Style.space(6)
            verticalPadding: Style.space(3)
            onClicked: profilePopup.open()
          }

          Popup {
            id: profilePopup
            y: profileDropdown.height + 4
            width: profileDropdown.width
            padding: Style.space(4)
            background: Rectangle {
              color: Color.popups.background
              border.color: Color.popups.border
              border.width: 1
              radius: Style.cornerRadius
            }
            contentItem: Column {
              spacing: 0

              Repeater {
                model: root.profileNames.length > 0 ? root.profileNames : ["Default"]

                delegate: Rectangle {
                  id: popupItem
                  required property string modelData
                  required property int index
                  readonly property bool isSelected: root.selectedProfile === popupItem.modelData

                  width: profilePopup.width - Style.space(8)
                  height: Style.space(28)
                  radius: Style.space(4)
                  color: popupItemArea.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08) : "transparent"

                  Text {
                    anchors.centerIn: parent
                    text: popupItem.modelData
                    color: popupItem.isSelected ? Color.accent : Color.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: popupItem.isSelected
                    elide: Text.ElideRight
                    width: parent.width - Style.space(12)
                    horizontalAlignment: Text.AlignHCenter
                  }

                  MouseArea {
                    id: popupItemArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      root.selectedProfile = popupItem.modelData
                      root.loadProfile(popupItem.modelData)
                      profilePopup.close()
                    }
                  }
                }
              }
            }
          }
        }

        Button {
          text: "New"
          fontFamily: root.fontFamily
          fontSize: Style.font.caption
          bordered: true
          horizontalPadding: Style.space(6)
          verticalPadding: Style.space(3)
          visible: !root.profileInputActive
          onClicked: {
            root.profileInputActive = true
            profileInput.text = ""
            profileInput.forceActiveFocus()
          }
        }

        Button {
          text: "Save"
          fontFamily: root.fontFamily
          fontSize: Style.font.caption
          bordered: true
          enabled: root.selectedProfile !== ""
          visible: !root.profileInputActive
          horizontalPadding: Style.space(6)
          verticalPadding: Style.space(3)
          onClicked: root.saveProfile(root.selectedProfile)
        }

        Button {
          text: "Delete"
          fontFamily: root.fontFamily
          fontSize: Style.font.caption
          bordered: true
          enabled: root.selectedProfile !== "" && root.selectedProfile !== "Default"
          visible: !root.profileInputActive
          horizontalPadding: Style.space(6)
          verticalPadding: Style.space(3)
          onClicked: {
            root.deleteProfile(root.selectedProfile)
            root.selectedProfile = "Default"
          }
        }

        TextField {
          id: profileInput
          visible: root.profileInputActive
          Layout.fillWidth: true
          Layout.maximumWidth: Style.space(140)
          placeholderText: "Profile name..."
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          onAccepted: {
            if (text.trim()) {
              root.selectedProfile = text.trim()
              root.saveProfile(text.trim())
              root.profileInputActive = false
              text = ""
            }
          }
        }

        Button {
          text: "Save"
          fontFamily: root.fontFamily
          fontSize: Style.font.caption
          bordered: true
          visible: root.profileInputActive
          horizontalPadding: Style.space(6)
          verticalPadding: Style.space(3)
          onClicked: {
            if (profileInput.text.trim()) {
              root.selectedProfile = profileInput.text.trim()
              root.saveProfile(profileInput.text.trim())
              root.profileInputActive = false
              profileInput.text = ""
            }
          }
        }

        Button {
          text: "Cancel"
          fontFamily: root.fontFamily
          fontSize: Style.font.caption
          bordered: true
          visible: root.profileInputActive
          horizontalPadding: Style.space(6)
          verticalPadding: Style.space(3)
          onClicked: {
            root.profileInputActive = false
            profileInput.text = ""
          }
        }
      }

      PanelSeparator {
        Layout.fillWidth: true
        foreground: Color.foreground
      }

      // ── Current DPI Sensitivity Slider & Reading ──
      BorderSurface {
        Layout.fillWidth: true
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.03)
        borderSpec: Border.flat(Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06), 1)
        radius: Style.cornerRadius
        padding: Style.space(12)
        implicitHeight: sensitivityCol.implicitHeight + contentTopInset + contentBottomInset

        ColumnLayout {
          id: sensitivityCol
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.topMargin: parent.contentTopInset
          anchors.rightMargin: parent.contentRightInset
          anchors.bottomMargin: parent.contentBottomInset
          anchors.leftMargin: parent.contentLeftInset
          spacing: Style.space(10)

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(8)

            Text {
              text: "Current Sensitivity:"
              color: Color.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            Item { Layout.fillWidth: true }

            Text {
              text: root.selectedDpi + " DPI"
              color: Color.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
            }
          }

          // Slider
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(8)

            Text {
              text: "100"
              color: Color.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            PanelSlider {
              id: dpiSlider
              Layout.fillWidth: true
              minimum: 100
              maximum: root.maxDpi
              step: 50
              integer: true
              value: root.selectedDpi
              onReleased: function(v) {
                root.selectedDpi = Model.sanitizeDpi(v, root.maxDpi)
                root.hasChanges = true
              }
            }

            Text {
              text: String(root.maxDpi)
              color: Color.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          // Quick adjustments buttons
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(6)

            Text {
              text: "Nudge:"
              color: Color.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            Item { Layout.fillWidth: true }

            Button {
              text: "-500"
              fontFamily: root.fontFamily
              fontSize: Style.font.caption
              bordered: true
              horizontalPadding: Style.space(6)
              verticalPadding: Style.space(2)
              onClicked: {
                root.selectedDpi = Model.sanitizeDpi(root.selectedDpi - 500, root.maxDpi)
                root.hasChanges = true
              }
            }

            Button {
              text: "-100"
              fontFamily: root.fontFamily
              fontSize: Style.font.caption
              bordered: true
              horizontalPadding: Style.space(6)
              verticalPadding: Style.space(2)
              onClicked: {
                root.selectedDpi = Model.sanitizeDpi(root.selectedDpi - 100, root.maxDpi)
                root.hasChanges = true
              }
            }

            Button {
              text: "+100"
              fontFamily: root.fontFamily
              fontSize: Style.font.caption
              bordered: true
              horizontalPadding: Style.space(6)
              verticalPadding: Style.space(2)
              onClicked: {
                root.selectedDpi = Model.sanitizeDpi(root.selectedDpi + 100, root.maxDpi)
                root.hasChanges = true
              }
            }

            Button {
              text: "+500"
              fontFamily: root.fontFamily
              fontSize: Style.font.caption
              bordered: true
              horizontalPadding: Style.space(6)
              verticalPadding: Style.space(2)
              onClicked: {
                root.selectedDpi = Model.sanitizeDpi(root.selectedDpi + 500, root.maxDpi)
                root.hasChanges = true
              }
            }
          }
        }
      }

      // ── Preset Steps Section ──
      BorderSurface {
        Layout.fillWidth: true
        color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.03)
        borderSpec: Border.flat(Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06), 1)
        radius: Style.cornerRadius
        padding: Style.space(12)
        implicitHeight: presetsCol.implicitHeight + contentTopInset + contentBottomInset

        ColumnLayout {
          id: presetsCol
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.topMargin: parent.contentTopInset
          anchors.rightMargin: parent.contentRightInset
          anchors.bottomMargin: parent.contentBottomInset
          anchors.leftMargin: parent.contentLeftInset
          spacing: Style.space(10)

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(8)

            Text {
              text: "Preset Steps (Quick-Switch):"
              color: Color.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }

            Item { Layout.fillWidth: true }

            Text {
              text: root.presets.length + " step" + (root.presets.length === 1 ? "" : "s")
              color: Color.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          // Preset Chips / Buttons Row
          Flow {
            Layout.fillWidth: true
            spacing: Style.space(6)

            Repeater {
              model: root.presets

              delegate: BorderSurface {
                id: chip
                required property int modelData
                required property int index
                readonly property bool isSelected: root.selectedDpi === chip.modelData

                radius: Style.space(4)
                color: chip.isSelected ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.15) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06)
                borderSpec: Border.flat(chip.isSelected ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12), 1)
                padding: Style.space(4)
                implicitWidth: chipRow.implicitWidth + Style.space(12)
                implicitHeight: Style.space(30)

                RowLayout {
                  id: chipRow
                  anchors.centerIn: parent
                  spacing: Style.space(6)

                  MouseArea {
                    id: chipSelectArea
                    Layout.fillHeight: true
                    implicitWidth: chipText.implicitWidth
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      root.selectedDpi = chip.modelData
                      root.hasChanges = true
                    }

                    Text {
                      id: chipText
                      anchors.centerIn: parent
                      text: chip.modelData + " DPI"
                      color: chip.isSelected ? Color.accent : Color.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: chip.isSelected
                    }
                  }

                  // Delete step button
                  Rectangle {
                    visible: root.presets.length > 1
                    width: Style.space(16)
                    height: Style.space(16)
                    radius: width / 2
                    color: removeMouseArea.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.15) : "transparent"

                    Text {
                      anchors.centerIn: parent
                      text: "×"
                      color: Color.muted
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.bodySmall
                      font.bold: true
                    }

                    MouseArea {
                      id: removeMouseArea
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.removePresetStep(chip.modelData)
                    }
                  }
                }
              }
            }
          }

          // Add New Step Row
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(6)

            TextField {
              id: addStepTextField
              Layout.fillWidth: true
              Layout.maximumWidth: Style.space(160)
              placeholderText: "Add DPI step (e.g. 3000)..."
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              onAccepted: {
                if (text.trim()) {
                  root.addPresetStep(text.trim())
                  text = ""
                }
              }
            }

            Button {
              text: "Add Step"
              fontFamily: root.fontFamily
              fontSize: Style.font.caption
              bordered: true
              horizontalPadding: Style.space(8)
              verticalPadding: Style.space(3)
              onClicked: {
                if (addStepTextField.text.trim()) {
                  root.addPresetStep(addStepTextField.text.trim())
                  addStepTextField.text = ""
                }
              }
            }

            Item { Layout.fillWidth: true }
          }

          // Quick Preset Templates
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(6)

            Text {
              text: "Templates:"
              color: Color.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            Button {
              text: "Default (5-Step)"
              fontFamily: root.fontFamily
              fontSize: Style.font.caption
              bordered: true
              horizontalPadding: Style.space(6)
              verticalPadding: Style.space(2)
              onClicked: root.setPresetTemplate([800, 1200, 1800, 2400, 3200])
            }

            Button {
              text: "FPS (800, 1200, 3000)"
              fontFamily: root.fontFamily
              fontSize: Style.font.caption
              bordered: true
              horizontalPadding: Style.space(6)
              verticalPadding: Style.space(2)
              onClicked: root.setPresetTemplate([800, 1200, 3000])
            }

            Button {
              text: "Gaming (400-3200)"
              fontFamily: root.fontFamily
              fontSize: Style.font.caption
              bordered: true
              horizontalPadding: Style.space(6)
              verticalPadding: Style.space(2)
              onClicked: root.setPresetTemplate([400, 800, 1600, 3200])
            }

            Button {
              text: "Office"
              fontFamily: root.fontFamily
              fontSize: Style.font.caption
              bordered: true
              horizontalPadding: Style.space(6)
              verticalPadding: Style.space(2)
              onClicked: root.setPresetTemplate([800, 1200, 2000])
            }
          }
        }
      }
    }
  }
}
