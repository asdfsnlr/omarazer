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
  property int matrixRows: 0
  property int matrixCols: 0
  property bool loading: false
  property string errorMessage: ""

  property var matrixState: []
  property var usedColors: []
  property string currentColor: "#00ff00"
  property string paintMode: "paint"
  property bool painting: false
  property int paintCount: 0
  property bool hasChanges: false
  property var profileNames: []
  property string selectedProfile: ""
  property string profileNameInput: ""
  property bool profileInputActive: false

  property color fg: Color.foreground
  property color dim: Color.muted
  property string fontFamily: Style.font.family

  readonly property int cellSize: 26
  readonly property int cellGap: 2
  readonly property int cellTotal: cellSize + cellGap

  signal closeRequested()

  visible: deviceSerial !== ""
  anchors { top: true; bottom: true; left: true; right: true }
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "omarchy-per-key-editor"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

  function pathFromUrl(url) {
    var value = String(url || "")
    if (value.indexOf("file://") === 0)
      return decodeURIComponent(value.substring(7))
    return value
  }

  function initMatrix(rows, cols) {
    var state = []
    for (var i = 0; i < rows * cols; i++) {
      state.push("#000000")
    }
    matrixState = state
    usedColors = []
    matrixRows = rows
    matrixCols = cols
    paintCount = 0
    hasChanges = false
  }

  function rebuildUsedColors() {
    var seen = {}
    var list = []
    for (var i = 0; i < matrixState.length; i++) {
      var c = matrixState[i]
      if (c && c !== "#000000" && !seen[c]) {
        seen[c] = true
        list.push(c)
      }
    }
    usedColors = list
  }

  function cellColor(row, col) {
    if (row < 0 || row >= matrixRows || col < 0 || col >= matrixCols) return "#000000"
    var idx = row * matrixCols + col
    if (idx < 0 || idx >= matrixState.length) return "#000000"
    return matrixState[idx]
  }

  function setCellColor(row, col, color) {
    if (row < 0 || row >= matrixRows || col < 0 || col >= matrixCols) return
    var idx = row * matrixCols + col
    if (idx < 0 || idx >= matrixState.length) return
    var copy = matrixState.slice()
    var oldColor = copy[idx]
    copy[idx] = color
    matrixState = copy
    if (oldColor !== color) {
      if (color !== "#000000" && oldColor === "#000000") paintCount++
      else if (color === "#000000" && oldColor !== "#000000") paintCount--
      hasChanges = true
      rebuildUsedColors()
    }
  }

  function fillAll(color) {
    var copy = []
    var count = 0
    for (var i = 0; i < matrixRows * matrixCols; i++) {
      copy.push(color)
      if (color !== "#000000") count++
    }
    matrixState = copy
    paintCount = count
    hasChanges = true
    rebuildUsedColors()
  }

  function clearAll() {
    fillAll("#000000")
  }

  function recolorAll(newColor) {
    var copy = matrixState.slice()
    for (var i = 0; i < copy.length; i++) {
      if (copy[i] !== "#000000") copy[i] = newColor
    }
    matrixState = copy
    hasChanges = true
    rebuildUsedColors()
  }

  function fillRow(row, color) {
    var copy = matrixState.slice()
    for (var col = 0; col < matrixCols; col++) {
      var idx = row * matrixCols + col
      var oldColor = copy[idx]
      copy[idx] = color
      if (color !== "#000000" && oldColor === "#000000") paintCount++
      else if (color === "#000000" && oldColor !== "#000000") paintCount--
    }
    matrixState = copy
    hasChanges = true
    rebuildUsedColors()
  }

  function paintAt(row, col) {
    if (paintMode === "paint") {
      // Toggle: if key already has a color, clear it; otherwise paint it
      var existing = cellColor(row, col)
      if (existing !== "#000000") {
        setCellColor(row, col, "#000000")
      } else {
        setCellColor(row, col, currentColor)
      }
    } else if (paintMode === "fillRow") {
      fillRow(row, currentColor)
    }
  }

  function applyToDevice() {
    if (!hasChanges || !deviceSerial) return
    var keys = []
    for (var row = 0; row < matrixRows; row++) {
      for (var col = 0; col < matrixCols; col++) {
        var idx = row * matrixCols + col
        var hex = matrixState[idx]
        if (hex && hex !== "#000000") {
          var r = parseInt(hex.substring(1, 3), 16)
          var g = parseInt(hex.substring(3, 5), 16)
          var b = parseInt(hex.substring(5, 7), 16)
          keys.push([row, col, r, g, b])
        }
      }
    }
    if (keys.length === 0) return
    var jsonPayload = JSON.stringify(keys)
    applyProc.command = ["python3", pathFromUrl(Qt.resolvedUrl("../scripts/razer_devices.py")), "--set-per-key-batch", deviceSerial, jsonPayload]
    applyProc.running = true
  }

  function fetchProfiles() {
    profileListProc.command = ["python3", pathFromUrl(Qt.resolvedUrl("../scripts/razer_devices.py")), "--list-profiles"]
    profileListProc.running = true
  }

  function saveProfile(name) {
    if (!name || !name.trim()) return
    var data = {
      name: name.trim(),
      rows: matrixRows,
      cols: matrixCols,
      colors: matrixState.slice()
    }
    saveProfileProc.command = ["python3", pathFromUrl(Qt.resolvedUrl("../scripts/razer_devices.py")), "--save-profile", name.trim(), JSON.stringify(data)]
    saveProfileProc.running = true
  }

  function loadProfile(name) {
    if (!name) return
    loadProfileProc.command = ["python3", pathFromUrl(Qt.resolvedUrl("../scripts/razer_devices.py")), "--load-profile", name]
    loadProfileProc.running = true
  }

  function deleteProfile(name) {
    if (!name) return
    deleteProfileProc.command = ["python3", pathFromUrl(Qt.resolvedUrl("../scripts/razer_devices.py")), "--delete-profile", name]
    deleteProfileProc.running = true
  }

  function fetchMatrixDims() {
    if (!deviceSerial) return
    loading = true
    errorMessage = ""
    dimsProc.command = ["python3", pathFromUrl(Qt.resolvedUrl("../scripts/razer_devices.py")), "--get-matrix-dims", deviceSerial]
    dimsProc.running = true
  }

  onDeviceSerialChanged: {
    if (deviceSerial) {
      fetchMatrixDims()
      fetchProfiles()
    }
  }

  Process {
    id: dimsProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        loading = false
        try {
          var parsed = JSON.parse(text)
          if (parsed.error) {
            errorMessage = parsed.error
            return
          }
          if (parsed.has_per_key && parsed.rows > 0 && parsed.cols > 0) {
            initMatrix(parsed.rows, parsed.cols)
          } else {
            errorMessage = "Device does not support per-key lighting"
          }
        } catch (e) {
          errorMessage = "Failed to get matrix dimensions"
        }
      }
    }
  }

  signal applied(string serial)

  Process {
    id: applyProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (text.trim() === "true" || text.trim() === "") {
          hasChanges = false
          root.applied(root.deviceSerial)
        }
      }
    }
  }

  Process {
    id: profileListProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          profileNames = JSON.parse(text.trim())
        } catch (e) {
          profileNames = []
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
          if (data.rows && data.cols && data.colors && data.colors.length === data.rows * data.cols) {
            matrixState = data.colors
            matrixRows = data.rows
            matrixCols = data.cols
            paintCount = 0
            for (var i = 0; i < matrixState.length; i++) {
              if (matrixState[i] !== "#000000") paintCount++
            }
            hasChanges = true
            rebuildUsedColors()
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
        selectedProfile = ""
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
    width: Math.min(root.matrixCols * root.cellTotal + Style.space(80), parent.width - Style.space(80))
    height: Math.min(root.matrixRows * root.cellTotal + Style.space(320), parent.height - Style.space(80))
    color: Color.popups.background
    borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, 1)
    radius: Style.cornerRadius
    padding: Style.space(16)

    MouseArea {
      anchors.fill: parent
      onClicked: {} // swallow clicks on card
    }

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: card.padding
      spacing: Style.space(8)

      // ── Header ──
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(10)

        Button {
          text: "Back"
          iconText: "󰁍"
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
            text: "󰌌  Per-Key Lighting"
            color: Color.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
          }

          Text {
            text: root.deviceName + (root.matrixRows > 0 ? "  •  " + root.matrixRows + "×" + root.matrixCols + " matrix" : "")
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
          iconText: "󰅬"
          foreground: root.hasChanges ? Color.accent : Color.muted
          fontFamily: root.fontFamily
          fontSize: Style.font.body
          bordered: true
          horizontalPadding: Style.space(10)
          verticalPadding: Style.space(4)
          enabled: root.hasChanges
          onClicked: root.applyToDevice()
        }
      }

      // ── Profiles ──
      RowLayout {
        visible: root.matrixRows > 0 && !root.loading
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
          Layout.maximumWidth: Style.space(200)
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
                model: root.profileNames.length > 0 ? root.profileNames : [""]

                delegate: Rectangle {
                  id: popupItem
                  required property string modelData
                  required property int index
                  readonly property bool isEmpty: root.profileNames.length === 0
                  readonly property bool isSelected: !isEmpty && root.selectedProfile === popupItem.modelData

                  width: profilePopup.width - Style.space(8)
                  height: Style.space(28)
                  radius: Style.space(4)
                  color: popupItemArea.containsMouse ? Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.08) : "transparent"

                  Text {
                    anchors.centerIn: parent
                    text: popupItem.isEmpty ? "No profiles saved" : popupItem.modelData
                    color: popupItem.isEmpty ? Color.muted : (popupItem.isSelected ? Color.accent : Color.foreground)
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
                    cursorShape: popupItem.isEmpty ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: {
                      if (popupItem.isEmpty) return
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
          iconText: "󰐕"
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
          iconText: "󰅬"
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
          iconText: "󰚌"
          fontFamily: root.fontFamily
          fontSize: Style.font.caption
          bordered: true
          enabled: root.selectedProfile !== ""
          visible: !root.profileInputActive
          horizontalPadding: Style.space(6)
          verticalPadding: Style.space(3)
          onClicked: {
            root.deleteProfile(root.selectedProfile)
            root.selectedProfile = ""
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
              root.saveProfile(text.trim())
              root.profileInputActive = false
              text = ""
            }
          }
        }

        Button {
          text: "Save"
          iconText: "󰅬"
          fontFamily: root.fontFamily
          fontSize: Style.font.caption
          bordered: true
          visible: root.profileInputActive
          horizontalPadding: Style.space(6)
          verticalPadding: Style.space(3)
          onClicked: {
            if (profileInput.text.trim()) {
              root.saveProfile(profileInput.text.trim())
              root.profileInputActive = false
              profileInput.text = ""
            }
          }
        }

        Button {
          text: "Cancel"
          iconText: "X"
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

      // ── Loading / Error State ──
      Text {
        visible: root.loading
        text: "Loading matrix dimensions..."
        color: Color.muted
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        Layout.alignment: Qt.AlignHCenter
      }

      Text {
        visible: root.errorMessage !== ""
        text: root.errorMessage
        color: "#ef4444"
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
      }

      // ── Color Palette ──
      RowLayout {
        visible: root.matrixRows > 0 && !root.loading
        Layout.fillWidth: true
        spacing: Style.space(6)

        Text {
          text: "Paint:"
          color: Color.muted
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          Layout.alignment: Qt.AlignVCenter
        }

        Flow {
          Layout.fillWidth: true
          spacing: Style.space(4)

          Repeater {
            model: Model.paletteColors()

            delegate: Rectangle {
              id: swatch
              required property var modelData

              readonly property bool isSelected: root.currentColor.toLowerCase() === swatch.modelData.hex.toLowerCase()

              width: Style.space(18)
              height: Style.space(18)
              radius: width / 2
              color: swatch.modelData.hex
              border.width: isSelected ? 2 : 1
              border.color: isSelected ? Color.foreground : Qt.rgba(0, 0, 0, 0.3)

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.currentColor = swatch.modelData.hex
                }
              }
            }
          }
        }

        // Current color indicator
        Rectangle {
          width: Style.space(18)
          height: Style.space(18)
          radius: width / 2
          color: root.currentColor
          border.width: 2
          border.color: Color.foreground
          Layout.alignment: Qt.AlignVCenter
        }
      }

      // ── Used Colors ──
      RowLayout {
        visible: root.matrixRows > 0 && !root.loading && root.usedColors.length > 0
        Layout.fillWidth: true
        spacing: Style.space(6)

        Text {
          text: "Used:"
          color: Color.muted
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          Layout.alignment: Qt.AlignVCenter
        }

        Flow {
          Layout.fillWidth: true
          spacing: Style.space(4)

          Repeater {
            model: root.usedColors

            delegate: Rectangle {
              id: usedSwatch
              required property string modelData
              readonly property int index: usedSwatch.Repeater.index
              readonly property bool isSelected: root.currentColor.toLowerCase() === usedSwatch.modelData.toLowerCase()

              width: Style.space(18)
              height: Style.space(18)
              radius: width / 2
              color: usedSwatch.modelData
              border.width: isSelected ? 2 : 1
              border.color: isSelected ? Color.foreground : Qt.rgba(0, 0, 0, 0.3)

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.currentColor = usedSwatch.modelData
                }
              }
            }
          }
        }
      }

      // ── Paint Mode / Actions ──
      RowLayout {
        visible: root.matrixRows > 0 && !root.loading
        Layout.fillWidth: true
        spacing: Style.space(6)

        Text {
          text: "Mode:"
          color: Color.muted
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          Layout.alignment: Qt.AlignVCenter
        }

        Button {
          text: "Paint"
          iconText: "󰏘"
          fontFamily: root.fontFamily
          fontSize: Style.font.caption
          bordered: true
          selected: root.paintMode === "paint"
          horizontalPadding: Style.space(6)
          verticalPadding: Style.space(3)
          onClicked: root.paintMode = "paint"
        }

        Button {
          text: "Fill Row"
          iconText: "[]"
          fontFamily: root.fontFamily
          fontSize: Style.font.caption
          bordered: true
          selected: root.paintMode === "fillRow"
          horizontalPadding: Style.space(6)
          verticalPadding: Style.space(3)
          onClicked: root.paintMode = "fillRow"
        }

        Item { Layout.fillWidth: true }

        Button {
          text: "Fill All"
          iconText: "󰆤"
          fontFamily: root.fontFamily
          fontSize: Style.font.caption
          bordered: true
          horizontalPadding: Style.space(6)
          verticalPadding: Style.space(3)
          onClicked: root.fillAll(root.currentColor)
        }

        Button {
          text: "Clear"
          iconText: "󰚌"
          fontFamily: root.fontFamily
          fontSize: Style.font.caption
          bordered: true
          horizontalPadding: Style.space(6)
          verticalPadding: Style.space(3)
          onClicked: root.clearAll()
        }
      }

      // ── Matrix Grid ──
      Flickable {
        visible: root.matrixRows > 0 && !root.loading
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.topMargin: Style.space(16)
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        contentWidth: root.matrixCols * root.cellTotal + Style.space(20)
        contentHeight: root.matrixRows * root.cellTotal + Style.space(20)

        Grid {
          id: matrixGrid
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.top: parent.top
          anchors.topMargin: Style.space(4)
          columns: root.matrixCols
          spacing: root.cellGap

          Repeater {
            model: root.matrixRows * root.matrixCols

            Rectangle {
              id: keyCell
              required property int index

              readonly property int cellRow: Math.floor(index / root.matrixCols)
              readonly property int cellCol: index % root.matrixCols
              readonly property string cellColor: root.cellColor(cellRow, cellCol)
              readonly property bool isPainted: cellColor !== "#000000"
              readonly property string label: Model.keyLabel(cellRow, cellCol)

              width: root.cellSize
              height: root.cellSize
              radius: Style.space(3)
              color: isPainted ? cellColor : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.06)
              border.width: 1
              border.color: isPainted ? Qt.rgba(
                Math.min(1, Qt.colorEqual(cellColor, Color.foreground) ? 0.6 : Qt.lighter(cellColor, 1.2).r),
                Math.min(1, Qt.lighter(cellColor, 1.2).g),
                Math.min(1, Qt.lighter(cellColor, 1.2).b),
                0.5
              ) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.1)

              Text {
                anchors.centerIn: parent
                visible: keyCell.label !== ""
                text: keyCell.label
                color: keyCell.isPainted ? Qt.rgba(1, 1, 1, 0.85) : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.35)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onPressed: function(mouse) {
                  root.painting = true
                  root.paintAt(keyCell.cellRow, keyCell.cellCol)
                }
                onPositionChanged: function(mouse) {
                  if (!root.painting) return
                  var pos = mapToItem(matrixGrid, mouse.x, mouse.y)
                  var col = Math.floor(pos.x / root.cellTotal)
                  var row = Math.floor(pos.y / root.cellTotal)
                  if (row >= 0 && row < root.matrixRows && col >= 0 && col < root.matrixCols) {
                    root.paintAt(row, col)
                  }
                }
                onReleased: root.painting = false
                onCanceled: root.painting = false
              }
            }
          }
        }
      }

      // ── Status Bar ──
      Text {
        visible: root.matrixRows > 0 && !root.loading
        text: "Matrix: " + root.matrixRows + "×" + root.matrixCols + "  •  Keys painted: " + root.paintCount + (root.hasChanges ? "  •  Unsaved changes" : "")
        color: root.hasChanges ? Color.accent : Color.muted
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
      }
    }
  }
}
