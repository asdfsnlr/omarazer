import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "omaRazer"
  ipcTarget: "omaRazer"

  property var razerData: ({ daemon_running: false, version: "", device_count: 0, devices: [], error: null })
  property var expandedSerials: ({})
  property var deviceSpeeds: ({})
  property int globalBrightness: 100
  property int dataVersion: 0
  property bool loading: false

  readonly property string barIcon: "󰾰"
  readonly property color fg: root.bar ? root.bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(fg, 1.45)
  readonly property string fontFamily: root.bar ? root.bar.fontFamily : Style.font.family

  readonly property int pollInterval: Model.getPollInterval(root.settings, 30)

  readonly property bool showCountInBar: {
    var v = settings ? settings.showCountInBar : undefined
    return v === undefined || v === null ? true : v === true
  }

  readonly property string tooltipText: Model.summaryText(root.razerData)

  function refresh() {
    if (!razerProc.running) {
      loading = true
      razerProc.running = true
    }
  }

  function updateData(raw) {
    var parsed = Model.parseData(raw)
    razerData = parsed
    dataVersion++
    loading = false
  }

  function setBrightness(serial, value) {
    if (!serial) return
    var valNum = Number(value)
    if (serial === "all") {
      root.globalBrightness = valNum
    }
    if (root.razerData && Array.isArray(root.razerData.devices)) {
      var copy = Object.assign({}, root.razerData)
      copy.devices = root.razerData.devices.map(function(d) {
        if (!d) return d
        if (serial === "all" || (d.serial && String(d.serial).toLowerCase() === String(serial).toLowerCase())) {
          var dc = Object.assign({}, d)
          if (dc.has_brightness) {
            dc.brightness = valNum
          }
          return dc
        }
        return d
      })
      root.razerData = copy
      root.dataVersion++
    }
    actionProc.command = ["python3", pathFromUrl(Qt.resolvedUrl("scripts/razer_devices.py")), "--set-brightness", String(serial), String(value)]
    actionProc.running = true
  }

  function setPollRate(serial, rate) {
    if (!serial || !rate) return
    actionProc.command = ["python3", pathFromUrl(Qt.resolvedUrl("scripts/razer_devices.py")), "--set-poll-rate", String(serial), String(rate)]
    actionProc.running = true
  }

  function toggleDeviceExpanded(serial) {
    if (!serial) return
    var copy = Object.assign({}, expandedSerials)
    if (copy[serial]) {
      delete copy[serial]
    } else {
      copy[serial] = true
    }
    expandedSerials = copy
  }

  function getDeviceSpeed(deviceKey) {
    if (!deviceKey) return "2"
    var s = deviceSpeeds[deviceKey]
    return s !== undefined && s !== null ? String(s) : "2"
  }

  function setDeviceSpeed(deviceKey, speed) {
    if (!deviceKey) return
    var copy = Object.assign({}, deviceSpeeds)
    copy[deviceKey] = String(speed)
    deviceSpeeds = copy
  }

  function setEffect(serial, effect, color, color2, param) {
    if (!serial || !effect) return
    var args = ["python3", pathFromUrl(Qt.resolvedUrl("scripts/razer_devices.py")), "--set-effect", String(serial), String(effect)]
    if (color) args.push(String(color))
    if (color2) args.push(String(color2))
    if (param) args.push(String(param))
    actionProc.command = args
    actionProc.running = true
  }

  function restartDaemon() {
    actionProc.command = ["systemctl", "--user", "restart", "openrazer-daemon"]
    actionProc.running = true
  }

  function pathFromUrl(url) {
    var value = String(url || "")
    if (value.indexOf("file://") === 0)
      return decodeURIComponent(value.substring(7))
    return value
  }

  function triggerPress(button) {
    if (button === Qt.MiddleButton) {
      refresh()
      return
    }
    if (opened) close()
    else {
      open()
      refresh()
    }
  }

  onOpenedChanged: {
    if (opened) {
      refresh()
    }
  }

  Component.onCompleted: {
    refresh()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Process {
    id: razerProc
    command: ["python3", pathFromUrl(Qt.resolvedUrl("scripts/razer_devices.py"))]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.updateData(text)
    }
  }

  Process {
    id: actionProc
    onExited: function(code, status) {
      Qt.callLater(root.refresh)
    }
  }

  Timer {
    id: pollTimer
    interval: root.pollInterval * 1000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: Model.formatBarText(root.razerData, root.showCountInBar)
    fixedWidth: root.showCountInBar ? -1 : (root.bar && root.bar.vertical ? -1 : Style.space(27))
    fixedHeight: root.showCountInBar ? -1 : (root.bar && root.bar.vertical ? Style.space(26) : -1)
    tooltipText: root.tooltipText
    onPressed: function(b) { root.triggerPress(b) }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(500))
    contentHeight: panel.fittedContentHeight(contentColumn.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTextKey: function(t) {
        if (t === "r" || t === "R") root.refresh()
      }

      ColumnLayout {
        id: contentColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(12)

        // ── Header ──
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(10)

          Text {
            text: root.barIcon
            color: Color.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.display
            Layout.alignment: Qt.AlignVCenter
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.space(2)

            Text {
              text: "OmaRazer"
              color: root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
            }

            Text {
              text: Model.summaryText(root.razerData) + (root.razerData.version ? " • Installed OpenRazer Daemon v" + root.razerData.version : "")
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
              Layout.fillWidth: true
            }
          }

          Button {
            iconText: "󰑐"
            tooltipText: "Refresh (R)"
            foreground: root.fg
            fontFamily: root.fontFamily
            fontSize: Style.font.body
            horizontalPadding: Style.spacing.controlPaddingX
            verticalPadding: Style.spacing.controlPaddingY
            bordered: true
            onClicked: root.refresh()
          }
        }

        // ── Global Controls (All Devices) ──
        BorderSurface {
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
                text: "󰌵"
                color: Color.accent
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }

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
                iconText: "󰑖"
                foreground: root.fg
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                bordered: true
                horizontalPadding: Style.space(6)
                verticalPadding: Style.space(3)
                onClicked: root.setEffect("all", "spectrum")
              }

              Button {
                text: "Wave"
                iconText: "󰓅"
                foreground: root.fg
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                bordered: true
                horizontalPadding: Style.space(6)
                verticalPadding: Style.space(3)
                onClicked: root.setEffect("all", "wave", null, null, "1")
              }

              Button {
                text: "Green"
                iconText: "󰏘"
                foreground: root.fg
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                bordered: true
                horizontalPadding: Style.space(6)
                verticalPadding: Style.space(3)
                onClicked: root.setEffect("all", "static", "#00ff00")
              }

              Button {
                text: "Off"
                iconText: "󰚌"
                foreground: root.fg
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                bordered: true
                horizontalPadding: Style.space(6)
                verticalPadding: Style.space(3)
                onClicked: root.setEffect("all", "none")
              }
            }

            // Global Brightness Slider (All Devices)
            RowLayout {
              visible: root.dataVersion >= 0 && Model.hasBrightnessSupport(root.razerData.devices)
              Layout.fillWidth: true
              spacing: Style.space(8)

              Text {
                text: "󰃟"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                Layout.alignment: Qt.AlignVCenter
              }

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

        PanelSeparator {
          Layout.fillWidth: true
          foreground: root.fg
        }

        // ── Offline / Error State ──
        BorderSurface {
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
                onClicked: root.refresh()
              }
            }
          }
        }

        // ── Empty State ──
        BorderSurface {
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
              text: "󰌢"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
              Layout.alignment: Qt.AlignHCenter
            }

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

        // ── Device List ──
        Flickable {
          id: deviceScroll
          visible: root.razerData.devices.length > 0
          Layout.fillWidth: true
          Layout.topMargin: Style.space(8)
          Layout.bottomMargin: Style.space(8)
          implicitHeight: Math.min(devicesColumn.implicitHeight, Style.space(520))
          contentHeight: devicesColumn.implicitHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds

          ColumnLayout {
            id: devicesColumn
            width: deviceScroll.width
            spacing: Style.space(10)

            Repeater {
              model: root.dataVersion >= 0 ? root.razerData.devices : []

              delegate: BorderSurface {
                id: deviceCard
                required property var modelData
                required property int index

                readonly property string deviceKey: deviceCard.modelData.serial || deviceCard.modelData.name || ("dev_" + deviceCard.index)
                readonly property bool isExpanded: !!root.expandedSerials[deviceCard.deviceKey]

                Layout.fillWidth: true
                color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.05)
                borderSpec: Border.flat(Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08), 1)
                radius: Style.cornerRadius
                padding: Style.space(10)
                implicitHeight: cardContent.implicitHeight + contentTopInset + contentBottomInset

                ColumnLayout {
                  id: cardContent
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.top: parent.top
                  anchors.topMargin: parent.contentTopInset
                  anchors.rightMargin: parent.contentRightInset
                  anchors.bottomMargin: parent.contentBottomInset
                  anchors.leftMargin: parent.contentLeftInset
                  spacing: Style.space(8)

                  // Device Title & Type Badge
                  RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.space(8)

                    Text {
                      text: Model.deviceTypeIcon(deviceCard.modelData)
                      color: Color.accent
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.title
                      Layout.alignment: Qt.AlignVCenter
                    }

                    Text {
                      text: deviceCard.modelData.name || "Unknown Razer Device"
                      color: root.fg
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                      font.bold: true
                      elide: Text.ElideRight
                      Layout.fillWidth: true
                      Layout.alignment: Qt.AlignVCenter
                    }

                    BorderSurface {
                      color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08)
                      borderSpec: Border.none()
                      radius: Style.space(4)
                      padding: Style.space(4)
                      implicitWidth: typeText.implicitWidth + Style.space(12)
                      implicitHeight: typeText.implicitHeight + Style.space(4)
                      Layout.alignment: Qt.AlignVCenter

                      Text {
                        id: typeText
                        anchors.centerIn: parent
                        text: Model.formatDeviceType(deviceCard.modelData.type).toUpperCase()
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        font.letterSpacing: 1.0
                      }
                    }
                  }

                  // Metadata badges row
                  RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.space(10)

                    Text {
                      visible: deviceCard.modelData.firmware_version !== ""
                      text: "FW " + deviceCard.modelData.firmware_version
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                    }

                    Text {
                      visible: deviceCard.modelData.serial !== ""
                      text: "SN: " + deviceCard.modelData.serial
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideMiddle
                      Layout.maximumWidth: Style.space(140)
                    }

                    Item { Layout.fillWidth: true }

                    // Battery Indicator (if present)
                    RowLayout {
                      visible: deviceCard.modelData.has_battery && deviceCard.modelData.battery_level !== null
                      spacing: Style.space(4)

                      Text {
                        text: Model.batteryIcon(deviceCard.modelData.battery_level, deviceCard.modelData.is_charging)
                        color: Model.batteryColor(deviceCard.modelData.battery_level, deviceCard.modelData.is_charging)
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.bodySmall
                      }

                      Text {
                        text: (deviceCard.modelData.battery_level !== null ? deviceCard.modelData.battery_level + "%" : "") + (deviceCard.modelData.is_charging ? " 󱐋" : "")
                        color: Model.batteryColor(deviceCard.modelData.battery_level, deviceCard.modelData.is_charging)
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: true
                      }
                    }

                    // DPI Indicator (if present)
                    Text {
                      visible: deviceCard.modelData.has_dpi && deviceCard.modelData.dpi !== null
                      text: Model.formatDpi(deviceCard.modelData.dpi)
                      color: root.fg
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                    }

                    // Poll Rate Indicator (if present)
                    Text {
                      visible: deviceCard.modelData.has_poll_rate && deviceCard.modelData.poll_rate !== null
                      text: Model.formatPollRate(deviceCard.modelData.poll_rate)
                      color: root.fg
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                    }
                  }

                  // Brightness Slider (if supported)
                  RowLayout {
                    visible: deviceCard.modelData.has_brightness && deviceCard.modelData.brightness !== null
                    Layout.fillWidth: true
                    spacing: Style.space(8)

                    Text {
                      text: "󰃟"
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.bodySmall
                      Layout.alignment: Qt.AlignVCenter
                    }

                    Text {
                      text: "Brightness"
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      Layout.alignment: Qt.AlignVCenter
                    }

                    PanelSlider {
                      id: brightnessSlider
                      bar: root.bar
                      Layout.fillWidth: true
                      minimum: 0
                      maximum: 100
                      step: 5
                      integer: true
                      value: deviceCard.modelData.brightness !== null ? deviceCard.modelData.brightness : 0
                      onReleased: function(v) {
                        root.setBrightness(deviceCard.modelData.serial, v)
                      }
                    }

                    Text {
                      text: Model.formatBrightness(brightnessSlider.liveValue)
                      color: root.fg
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      horizontalAlignment: Text.AlignRight
                      Layout.minimumWidth: Style.space(36)
                      Layout.alignment: Qt.AlignVCenter
                    }
                  }

                  // Polling Rate Selector (if supported)
                  RowLayout {
                    visible: deviceCard.modelData.has_poll_rate && deviceCard.modelData.poll_rate !== null
                    Layout.fillWidth: true
                    spacing: Style.space(8)

                    Text {
                      text: "󰍽"
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.bodySmall
                      Layout.alignment: Qt.AlignVCenter
                    }

                    Text {
                      text: "Polling Rate"
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      Layout.alignment: Qt.AlignVCenter
                    }

                    Item { Layout.fillWidth: true }

                    Repeater {
                      model: Model.supportedPollRates(deviceCard.modelData)

                      delegate: Button {
                        required property int modelData
                        text: modelData + " Hz"
                        foreground: deviceCard.modelData.poll_rate === modelData ? Color.accent : root.fg
                        fontFamily: root.fontFamily
                        fontSize: Style.font.caption
                        bordered: true
                        horizontalPadding: Style.space(6)
                        verticalPadding: Style.space(3)
                        onClicked: {
                          root.setPollRate(deviceCard.modelData.serial, modelData)
                        }
                      }
                    }
                  }

                  // Lighting Effects Section
                  ColumnLayout {
                    visible: deviceCard.modelData.has_lighting && Model.availableEffects(deviceCard.modelData).length > 0
                    Layout.fillWidth: true
                    spacing: Style.space(6)

                    // Lighting section header
                    RowLayout {
                      Layout.fillWidth: true
                      spacing: Style.space(6)

                      Text {
                        text: "󰌵"
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.bodySmall
                        Layout.alignment: Qt.AlignVCenter
                      }

                      Text {
                        text: "Lighting Effect"
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        Layout.alignment: Qt.AlignVCenter
                      }

                      Item { Layout.fillWidth: true }

                      // Active Effect & Color Badge (clickable dropdown toggle)
                      BorderSurface {
                        id: activeEffectBadge
                        color: effectBadgeMouse.containsMouse 
                          ? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.14) 
                          : (deviceCard.isExpanded 
                              ? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.12) 
                              : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08))
                        borderSpec: deviceCard.isExpanded 
                          ? Border.flat(Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.5), 1) 
                          : (effectBadgeMouse.containsMouse 
                              ? Border.flat(Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.2), 1) 
                              : Border.none())
                        radius: Style.space(4)
                        padding: Style.space(4)
                        implicitWidth: badgeRow.implicitWidth + Style.space(12)
                        implicitHeight: badgeRow.implicitHeight + Style.space(4)
                        Layout.alignment: Qt.AlignVCenter

                        RowLayout {
                          id: badgeRow
                          anchors.centerIn: parent
                          spacing: Style.space(4)

                          Rectangle {
                            visible: Model.needsColor(deviceCard.modelData.current_effect)
                            width: Style.space(8)
                            height: Style.space(8)
                            radius: width / 2
                            color: Model.primaryColor(deviceCard.modelData)
                            Layout.alignment: Qt.AlignVCenter
                          }

                          Rectangle {
                            visible: Model.needsSecondaryColor(deviceCard.modelData.current_effect)
                            width: Style.space(8)
                            height: Style.space(8)
                            radius: width / 2
                            color: Model.secondaryColor(deviceCard.modelData)
                            Layout.alignment: Qt.AlignVCenter
                          }

                          Text {
                            text: Model.effectIcon(deviceCard.modelData.current_effect) + " " + Model.effectDisplayName(deviceCard.modelData.current_effect)
                            color: Color.accent
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                            font.bold: true
                          }

                          Text {
                            text: deviceCard.isExpanded ? "󰅃" : "󰅀"
                            color: deviceCard.isExpanded ? Color.accent : root.dim
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                            Layout.alignment: Qt.AlignVCenter
                          }
                        }

                        MouseArea {
                          id: effectBadgeMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            root.toggleDeviceExpanded(deviceCard.deviceKey)
                          }
                        }
                      }
                    }

                    // Collapsible Per-Device Effect Options
                    ColumnLayout {
                      id: effectOptionsContainer
                      visible: deviceCard.isExpanded
                      Layout.fillWidth: true
                      spacing: Style.space(8)

                      // Categorized Effect Buttons Container
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
                            model: Model.categorizedEffects(deviceCard.modelData)

                            delegate: ColumnLayout {
                              id: categoryLayout
                              required property var modelData
                              Layout.fillWidth: true
                              spacing: Style.space(4)

                              // Category Section Header (e.g. 󰏘 Presets, 󰑖 Dynamic, 󰌌 Interactive)
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

                              // Category Buttons Flow
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
                                    selected: Model.isEffectSelected(deviceCard.modelData.current_effect, effectBtn.modelData)
                                    bordered: true
                                    fontFamily: root.fontFamily
                                    fontSize: Style.font.caption
                                    horizontalPadding: Style.space(6)
                                    verticalPadding: Style.space(3)
                                    onClicked: {
                                      var spd = Model.needsSpeed(effectBtn.modelData) ? root.getDeviceSpeed(deviceCard.deviceKey) : null
                                      root.setEffect(deviceCard.modelData.serial, effectBtn.modelData, Model.primaryColor(deviceCard.modelData), Model.secondaryColor(deviceCard.modelData), spd)
                                    }
                                  }
                                }
                              }
                            }
                          }
                        }
                      }

                      // Active Effect Customization / Parameter Options Card
                      BorderSurface {
                        visible: Model.hasCustomizationOptions(deviceCard.modelData)
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
                              text: Model.effectDisplayName(deviceCard.modelData.current_effect) + " Options" + (Model.needsSpeed(deviceCard.modelData.current_effect) ? " • " + Model.formatSpeed(root.getDeviceSpeed(deviceCard.deviceKey)) : "")
                              color: root.fg
                              font.family: root.fontFamily
                              font.pixelSize: Style.font.caption
                              font.bold: true
                            }

                            Item { Layout.fillWidth: true }
                          }

                          // Breathing Mode Switcher (Single / Random / Dual)
                          RowLayout {
                            visible: Model.isBreathingEffect(deviceCard.modelData.current_effect) && (Model.hasEffect(deviceCard.modelData, "breath_random") || Model.hasEffect(deviceCard.modelData, "breath_dual"))
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
                              visible: Model.hasEffect(deviceCard.modelData, "breath_single")
                              text: "Single Color"
                              iconText: "󰔄"
                              fontFamily: root.fontFamily
                              fontSize: Style.font.caption
                              bordered: true
                              selected: String(deviceCard.modelData.current_effect || "").toLowerCase() === "breath_single" || String(deviceCard.modelData.current_effect || "").toLowerCase() === "breath"
                              horizontalPadding: Style.space(6)
                              verticalPadding: Style.space(2)
                              onClicked: root.setEffect(deviceCard.modelData.serial, "breath_single", Model.primaryColor(deviceCard.modelData))
                            }

                            Button {
                              visible: Model.hasEffect(deviceCard.modelData, "breath_random")
                              text: "Random"
                              iconText: "󰔄"
                              fontFamily: root.fontFamily
                              fontSize: Style.font.caption
                              bordered: true
                              selected: String(deviceCard.modelData.current_effect || "").toLowerCase() === "breath_random"
                              horizontalPadding: Style.space(6)
                              verticalPadding: Style.space(2)
                              onClicked: root.setEffect(deviceCard.modelData.serial, "breath_random")
                            }

                            Button {
                              visible: Model.hasEffect(deviceCard.modelData, "breath_dual")
                              text: "Dual"
                              iconText: "󰔄"
                              fontFamily: root.fontFamily
                              fontSize: Style.font.caption
                              bordered: true
                              selected: String(deviceCard.modelData.current_effect || "").toLowerCase() === "breath_dual"
                              horizontalPadding: Style.space(6)
                              verticalPadding: Style.space(2)
                              onClicked: root.setEffect(deviceCard.modelData.serial, "breath_dual", Model.primaryColor(deviceCard.modelData), Model.secondaryColor(deviceCard.modelData))
                            }
                          }

                          // Ripple Mode Switcher (Single / Random)
                          RowLayout {
                            visible: Model.isRippleEffect(deviceCard.modelData.current_effect) && Model.hasEffect(deviceCard.modelData, "ripple_random")
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
                              visible: Model.hasEffect(deviceCard.modelData, "ripple")
                              text: "Single Color"
                              iconText: "󰑈"
                              fontFamily: root.fontFamily
                              fontSize: Style.font.caption
                              bordered: true
                              selected: String(deviceCard.modelData.current_effect || "").toLowerCase() === "ripple"
                              horizontalPadding: Style.space(6)
                              verticalPadding: Style.space(2)
                              onClicked: root.setEffect(deviceCard.modelData.serial, "ripple", Model.primaryColor(deviceCard.modelData), null, root.getDeviceSpeed(deviceCard.deviceKey))
                            }

                            Button {
                              visible: Model.hasEffect(deviceCard.modelData, "ripple_random")
                              text: "Random"
                              iconText: "󰑈"
                              fontFamily: root.fontFamily
                              fontSize: Style.font.caption
                              bordered: true
                              selected: String(deviceCard.modelData.current_effect || "").toLowerCase() === "ripple_random"
                              horizontalPadding: Style.space(6)
                              verticalPadding: Style.space(2)
                              onClicked: root.setEffect(deviceCard.modelData.serial, "ripple_random", null, null, root.getDeviceSpeed(deviceCard.deviceKey))
                            }
                          }

                          // Starlight Mode Switcher (Random / Single / Dual)
                          RowLayout {
                            visible: Model.isStarlightEffect(deviceCard.modelData.current_effect) && (Model.hasEffect(deviceCard.modelData, "starlight_random") || Model.hasEffect(deviceCard.modelData, "starlight_single") || Model.hasEffect(deviceCard.modelData, "starlight_dual"))
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
                              visible: Model.hasEffect(deviceCard.modelData, "starlight_random")
                              text: "Random"
                              iconText: "󰵚"
                              fontFamily: root.fontFamily
                              fontSize: Style.font.caption
                              bordered: true
                              selected: String(deviceCard.modelData.current_effect || "").toLowerCase() === "starlight_random" || String(deviceCard.modelData.current_effect || "").toLowerCase() === "starlight"
                              horizontalPadding: Style.space(6)
                              verticalPadding: Style.space(2)
                              onClicked: root.setEffect(deviceCard.modelData.serial, "starlight_random", null, null, root.getDeviceSpeed(deviceCard.deviceKey))
                            }

                            Button {
                              visible: Model.hasEffect(deviceCard.modelData, "starlight_single")
                              text: "Single Color"
                              iconText: "󰵚"
                              fontFamily: root.fontFamily
                              fontSize: Style.font.caption
                              bordered: true
                              selected: String(deviceCard.modelData.current_effect || "").toLowerCase() === "starlight_single"
                              horizontalPadding: Style.space(6)
                              verticalPadding: Style.space(2)
                              onClicked: root.setEffect(deviceCard.modelData.serial, "starlight_single", Model.primaryColor(deviceCard.modelData), null, root.getDeviceSpeed(deviceCard.deviceKey))
                            }

                            Button {
                              visible: Model.hasEffect(deviceCard.modelData, "starlight_dual")
                              text: "Dual"
                              iconText: "󰵚"
                              fontFamily: root.fontFamily
                              fontSize: Style.font.caption
                              bordered: true
                              selected: String(deviceCard.modelData.current_effect || "").toLowerCase() === "starlight_dual"
                              horizontalPadding: Style.space(6)
                              verticalPadding: Style.space(2)
                              onClicked: root.setEffect(deviceCard.modelData.serial, "starlight_dual", Model.primaryColor(deviceCard.modelData), Model.secondaryColor(deviceCard.modelData), root.getDeviceSpeed(deviceCard.deviceKey))
                            }
                          }

                          // Primary Color Palette Selector (when active effect uses primary color)
                          RowLayout {
                            visible: Model.needsColor(deviceCard.modelData.current_effect)
                            Layout.fillWidth: true
                            spacing: Style.space(6)

                            Text {
                              text: Model.needsSecondaryColor(deviceCard.modelData.current_effect) ? "Color 1:" : "Color:"
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

                                  readonly property bool isSelected: Model.primaryColor(deviceCard.modelData).toLowerCase() === swatch.modelData.hex.toLowerCase()

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
                                      var spd = Model.needsSpeed(deviceCard.modelData.current_effect) ? root.getDeviceSpeed(deviceCard.deviceKey) : null
                                      root.setEffect(deviceCard.modelData.serial, deviceCard.modelData.current_effect || "static", swatch.modelData.hex, Model.secondaryColor(deviceCard.modelData), spd)
                                    }
                                  }
                                }
                              }
                            }
                          }

                          // Secondary Color Palette Selector (when active effect uses secondary color)
                          RowLayout {
                            visible: Model.needsSecondaryColor(deviceCard.modelData.current_effect)
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

                                  readonly property bool isSelected: Model.secondaryColor(deviceCard.modelData).toLowerCase() === swatch2.modelData.hex.toLowerCase()

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
                                      var spd = Model.needsSpeed(deviceCard.modelData.current_effect) ? root.getDeviceSpeed(deviceCard.deviceKey) : null
                                      root.setEffect(deviceCard.modelData.serial, deviceCard.modelData.current_effect || "breath_dual", Model.primaryColor(deviceCard.modelData), swatch2.modelData.hex, spd)
                                    }
                                  }
                                }
                              }
                            }
                          }

                          // Wave Direction Selector (when active effect is wave)
                          RowLayout {
                            visible: Model.needsDirection(deviceCard.modelData.current_effect)
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
                              onClicked: root.setEffect(deviceCard.modelData.serial, "wave", null, null, "2")
                            }

                            Button {
                              text: "Right"
                              iconText: "󰁔"
                              fontFamily: root.fontFamily
                              fontSize: Style.font.caption
                              bordered: true
                              horizontalPadding: Style.space(6)
                              verticalPadding: Style.space(2)
                              onClicked: root.setEffect(deviceCard.modelData.serial, "wave", null, null, "1")
                            }
                          }

                          // Speed Selector (when active effect is reactive, starlight, or ripple)
                          RowLayout {
                            visible: Model.needsSpeed(deviceCard.modelData.current_effect)
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
                              model: Model.speedLevels(deviceCard.modelData.current_effect)

                              delegate: Button {
                                id: speedBtn
                                required property var modelData

                                readonly property string currentSpeed: root.getDeviceSpeed(deviceCard.deviceKey)
                                readonly property bool isSelected: currentSpeed === speedBtn.modelData.value

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
                                  root.setDeviceSpeed(deviceCard.deviceKey, speedBtn.modelData.value)
                                  root.setEffect(
                                    deviceCard.modelData.serial,
                                    deviceCard.modelData.current_effect || "reactive",
                                    Model.primaryColor(deviceCard.modelData),
                                    Model.secondaryColor(deviceCard.modelData),
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
                }
              }
            }
          }
        }

        PanelSeparator {
          Layout.fillWidth: true
          foreground: root.fg
        }

        Text {
          Layout.fillWidth: true
          horizontalAlignment: Text.AlignHCenter
          textFormat: Text.RichText
          text: "<span style='background-color: " + Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.12) + "; color: " + root.fg + "; border-radius: 3px; padding: 1px 4px;'><b>&nbsp;Esc&nbsp;</b></span> to close, and <span style='background-color: " + Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.12) + "; color: " + root.fg + "; border-radius: 3px; padding: 1px 4px;'><b>&nbsp;r&nbsp;</b></span> to refresh."
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }
  }
}
