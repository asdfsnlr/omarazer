function parseData(raw) {
  if (!raw) return { daemon_running: false, version: "", device_count: 0, devices: [], error: "No data" }
  try {
    var str = String(raw).trim()
    var parsed = JSON.parse(str)
    if (parsed && typeof parsed === "object") {
      if (!Array.isArray(parsed.devices)) parsed.devices = []
      if (typeof parsed.device_count !== "number") parsed.device_count = parsed.devices.length
      if (parsed.daemon_running === undefined) parsed.daemon_running = true
      return parsed
    }
  } catch (e) {
    // Ignore parse error and fallback
  }
  return { daemon_running: false, version: "", device_count: 0, devices: [], error: "Failed to parse data" }
}

function deviceTypeIcon(typeOrDevice, name) {
  var type = ""
  var devName = ""
  if (typeOrDevice && typeof typeOrDevice === "object") {
    type = String(typeOrDevice.type || "")
    devName = String(typeOrDevice.name || "")
  } else {
    type = String(typeOrDevice || "")
    devName = String(name || "")
  }
  var t = type.toLowerCase().trim()
  var n = devName.toLowerCase().trim()

  if (t === "keyboard") return "󰌌"
  if (t === "keypad") return "󰦤"
  if (t === "mouse") return "󰍽"
  if (t === "speaker" || t === "speakers" || t === "soundbar" || n.indexOf("nommo") !== -1 || n.indexOf("speaker") !== -1 || n.indexOf("leviathan") !== -1 || n.indexOf("ferox") !== -1) return "󰓃"
  if (t === "headset" || t === "headphones" || n.indexOf("headset") !== -1 || n.indexOf("headphone") !== -1 || n.indexOf("kraken") !== -1 || n.indexOf("nari") !== -1 || n.indexOf("blackshark") !== -1 || n.indexOf("barracuda") !== -1 || n.indexOf("kaira") !== -1 || n.indexOf("opus") !== -1 || n.indexOf("hammerhead") !== -1 || n.indexOf("thresher") !== -1 || n.indexOf("electra") !== -1 || n.indexOf("seiren") !== -1) return "󰋋"
  if (t === "audio") {
    if (n.indexOf("nommo") !== -1 || n.indexOf("speaker") !== -1 || n.indexOf("leviathan") !== -1 || n.indexOf("ferox") !== -1) return "󰓃"
    return "󰋋"
  }
  if (t === "mousemat" || t === "mat" || t === "pad" || n.indexOf("firefly") !== -1 || n.indexOf("goliathus") !== -1 || n.indexOf("strider") !== -1 || n.indexOf("mouse mat") !== -1 || n.indexOf("mousemat") !== -1) return "󰆥"
  if (t === "accessory" || t === "dock" || t === "stand" || t === "hub" || t === "chassis" || t === "other" || t === "generic") return "󰒋"
  return "󰒋"
}

function batteryIcon(level, isCharging) {
  if (isCharging) return "󰂄"
  if (level === null || level === undefined || level < 0) return ""
  var l = Math.round(Number(level))
  if (l >= 90) return "󰁹"
  if (l >= 75) return "󰂁"
  if (l >= 50) return "󰁿"
  if (l >= 25) return "󰁽"
  if (l >= 10) return "󰁻"
  return "󰂎"
}

function batteryColor(level, isCharging) {
  if (isCharging) return "#22c55e"
  if (level === null || level === undefined || level < 0) return ""
  var l = Math.round(Number(level))
  if (l <= 15) return "#ef4444"
  if (l <= 30) return "#eab308"
  return "#22c55e"
}

function formatBarText(data, showCount) {
  var icon = "󰾰"
  if (!data || !data.daemon_running) return icon + " !"
  var count = typeof data.device_count === "number" ? data.device_count : (data.devices ? data.devices.length : 0)
  if (showCount !== false) {
    return icon + " " + count
  }
  return icon
}

function formatDeviceType(type) {
  var t = String(type || "").trim()
  if (!t) return "Accessory"
  return t.charAt(0).toUpperCase() + t.slice(1).toLowerCase()
}

function formatDpi(dpi) {
  if (Array.isArray(dpi)) {
    if (dpi.length === 2 && dpi[0] === dpi[1]) return dpi[0] + " DPI"
    if (dpi.length === 2) return dpi[0] + " x " + dpi[1] + " DPI"
    if (dpi.length === 1) return dpi[0] + " DPI"
  }
  if (typeof dpi === "number" && dpi > 0) return Math.round(dpi) + " DPI"
  return ""
}

function formatPollRate(pollRate) {
  if (typeof pollRate === "number" && pollRate > 0) {
    return Math.round(pollRate) + " Hz"
  }
  return ""
}

function formatBrightness(val) {
  if (val !== null && val !== undefined && !isNaN(Number(val))) {
    return Math.round(Number(val)) + "%"
  }
  return ""
}

function getPollInterval(settings, defaultVal) {
  var d = (typeof defaultVal === "number" && defaultVal >= 5) ? defaultVal : 30
  if (!settings || typeof settings !== "object") return d
  var v = settings.pollIntervalSec !== undefined ? settings.pollIntervalSec : settings.refreshIntervalSec
  if (typeof v === "number" && v >= 5 && v <= 3600) return Math.round(v)
  if (typeof v === "string") {
    var n = parseInt(v, 10)
    if (!isNaN(n) && n >= 5 && n <= 3600) return n
  }
  return d
}

function summaryText(data) {
  if (!data || !data.daemon_running) {
    return data && data.error ? data.error : "OpenRazer daemon not running"
  }
  var count = typeof data.device_count === "number" ? data.device_count : (data.devices ? data.devices.length : 0)
  if (count === 0) return "No Razer devices connected"
  if (count === 1) return "1 device connected"
  return count + " devices connected"
}

function effectDisplayName(effect) {
  var e = String(effect || "").toLowerCase().replace(/-/g, "_")
  if (e === "none" || e === "off") return "Off"
  if (e === "static") return "Static"
  if (e === "spectrum" || e === "spectrumcycling" || e === "spectrum_cycling") return "Spectrum"
  if (e === "wave") return "Wave"
  if (e === "breath_single" || e === "breathsingle" || e === "breath" || e === "breathing") return "Breathing"
  if (e === "breath_random" || e === "breathrandom") return "Breathing (Rand)"
  if (e === "breath_dual" || e === "breathdual") return "Dual Breathing"
  if (e === "reactive") return "Reactive"
  if (e === "ripple") return "Ripple"
  if (e === "ripple_random" || e === "ripplerandom") return "Ripple (Rand)"
  if (e === "starlight_random" || e === "starlightrandom" || e === "starlight") return "Starlight"
  if (e === "starlight_single") return "Starlight (Single)"
  if (e === "starlight_dual") return "Dual Starlight"
  if (!e) return "None"
  return e.charAt(0).toUpperCase() + e.slice(1).replace(/_/g, " ")
}

function effectIcon(effect) {
  var e = String(effect || "").toLowerCase().replace(/-/g, "_")
  if (e === "none" || e === "off") return "󰚌"
  if (e === "static") return "󰏘"
  if (e === "spectrum" || e === "spectrumcycling" || e === "spectrum_cycling") return "󰑖"
  if (e === "wave") return "󰓅"
  if (e.indexOf("breath") === 0) return "󰔄"
  if (e === "reactive") return "󰌌"
  if (e.indexOf("ripple") === 0) return "󰑈"
  if (e.indexOf("starlight") === 0) return "󰵚"
  return "󰌵"
}

function paletteColors() {
  return [
    { name: "Razer Green", hex: "#00ff00" },
    { name: "Emerald", hex: "#10b981" },
    { name: "Cyan", hex: "#00e5ff" },
    { name: "Blue", hex: "#2563eb" },
    { name: "Purple", hex: "#8000ff" },
    { name: "Pink", hex: "#ec4899" },
    { name: "Red", hex: "#ef4444" },
    { name: "Orange", hex: "#f97316" },
    { name: "Yellow", hex: "#eab308" },
    { name: "White", hex: "#ffffff" }
  ]
}

function primaryColor(device) {
  if (!device) return "#00ff00"
  if (Array.isArray(device.colors) && device.colors.length > 0 && device.colors[0]) {
    return device.colors[0]
  }
  if (device.primary_color) return device.primary_color
  return "#00ff00"
}

function secondaryColor(device) {
  if (!device) return "#00e5ff"
  if (Array.isArray(device.colors) && device.colors.length > 1 && device.colors[1]) {
    return device.colors[1]
  }
  if (device.secondary_color) return device.secondary_color
  return "#00e5ff"
}

function needsColor(effect) {
  var e = String(effect || "").toLowerCase().replace(/-/g, "_")
  return e === "static" || e === "breath_single" || e === "breath" || e === "breathing" || e === "breath_dual" || e === "reactive" || e === "ripple" || e === "starlight_single" || e === "starlight_dual"
}

function needsSecondaryColor(effect) {
  var e = String(effect || "").toLowerCase().replace(/-/g, "_")
  return e === "breath_dual" || e === "starlight_dual"
}

function needsDirection(effect) {
  var e = String(effect || "").toLowerCase().replace(/-/g, "_")
  return e === "wave"
}

function needsSpeed(effect) {
  var e = String(effect || "").toLowerCase().replace(/-/g, "_")
  return e === "reactive" || e.indexOf("starlight") === 0 || e.indexOf("ripple") === 0
}

function isBreathingEffect(effect) {
  var e = String(effect || "").toLowerCase().replace(/-/g, "_")
  return e.indexOf("breath") === 0
}

function isRippleEffect(effect) {
  var e = String(effect || "").toLowerCase().replace(/-/g, "_")
  return e.indexOf("ripple") === 0
}

function isStarlightEffect(effect) {
  var e = String(effect || "").toLowerCase().replace(/-/g, "_")
  return e.indexOf("starlight") === 0
}

function speedLevels(effect) {
  var e = String(effect || "").toLowerCase().replace(/-/g, "_")
  if (e === "reactive") {
    return [
      { value: "1", label: "Fast", icon: "󱐋", desc: "Fast reaction (500ms)" },
      { value: "2", label: "Normal", icon: "󰓅", desc: "Normal reaction (1000ms)" },
      { value: "3", label: "Slow", icon: "󰾆", desc: "Slow reaction (1500ms)" },
      { value: "4", label: "Very Slow", icon: "󰄰", desc: "Very Slow reaction (2000ms)" }
    ]
  }
  return [
    { value: "1", label: "Fast", icon: "󱐋", desc: "Fast animation speed" },
    { value: "2", label: "Normal", icon: "󰓅", desc: "Normal animation speed" },
    { value: "3", label: "Slow", icon: "󰾆", desc: "Slow animation speed" }
  ]
}

function formatSpeed(speedVal) {
  var s = String(speedVal || "2").toLowerCase().trim()
  if (s === "1" || s === "fast") return "Fast"
  if (s === "2" || s === "normal" || s === "medium" || s === "med") return "Normal"
  if (s === "3" || s === "slow") return "Slow"
  if (s === "4" || s === "very_slow" || s === "veryslow") return "Very Slow"
  return "Normal"
}

function defaultEffectsForType(type) {
  var t = String(type || "").toLowerCase().trim()
  if (t === "keyboard") {
    return ["static", "spectrum", "wave", "breath_single", "breath_random", "breath_dual", "reactive", "ripple", "none"]
  }
  if (t === "mouse") {
    return ["static", "spectrum", "breath_single", "reactive", "none"]
  }
  if (t === "mousemat") {
    return ["static", "spectrum", "wave", "breath_single", "breath_random", "reactive", "none"]
  }
  if (t === "speaker" || t === "speakers" || t === "soundbar") {
    return ["static", "spectrum", "wave", "breath_single", "breath_random", "breath_dual", "none"]
  }
  if (t === "headset" || t === "headphones" || t === "audio") {
    return ["static", "spectrum", "breath_single", "none"]
  }
  if (t === "keypad") {
    return ["static", "spectrum", "wave", "breath_single", "reactive", "none"]
  }
  return ["static", "spectrum", "breath_single", "none"]
}

function availableEffects(deviceOrEffects, deviceType) {
  var rawEffects = null
  var type = ""
  if (deviceOrEffects && typeof deviceOrEffects === "object" && !Array.isArray(deviceOrEffects)) {
    rawEffects = deviceOrEffects.supported_effects
    type = deviceOrEffects.type || ""
  } else if (Array.isArray(deviceOrEffects)) {
    rawEffects = deviceOrEffects
    type = deviceType || ""
  } else if (typeof deviceOrEffects === "string") {
    type = deviceOrEffects
  }

  if (!Array.isArray(rawEffects) || rawEffects.length === 0) {
    rawEffects = defaultEffectsForType(type)
  }

  var priority = [
    "static",
    "spectrum",
    "wave",
    "breath_single",
    "breath_random",
    "breath_dual",
    "reactive",
    "ripple",
    "ripple_random",
    "starlight_random",
    "starlight_single",
    "starlight_dual",
    "none"
  ]

  var list = []
  var normalized = []
  for (var i = 0; i < rawEffects.length; i++) {
    var eff = String(rawEffects[i] || "").toLowerCase().replace(/-/g, "_")
    if (eff === "off") eff = "none"
    if (eff === "breath" || eff === "breathing") eff = "breath_single"
    if (eff && normalized.indexOf(eff) === -1) {
      normalized.push(eff)
    }
  }

  for (var p = 0; p < priority.length; p++) {
    if (normalized.indexOf(priority[p]) !== -1) {
      list.push(priority[p])
    }
  }

  for (var j = 0; j < normalized.length; j++) {
    if (list.indexOf(normalized[j]) === -1) {
      list.push(normalized[j])
    }
  }

  return list
}

function hasEffect(device, effectName) {
  if (!device) return false
  var list = availableEffects(device)
  var target = String(effectName || "").toLowerCase().replace(/-/g, "_")
  if (target === "off") target = "none"
  if (target === "breath" || target === "breathing") target = "breath_single"
  for (var i = 0; i < list.length; i++) {
    if (String(list[i]).toLowerCase().replace(/-/g, "_") === target) {
      return true
    }
  }
  return false
}

function sanitizeEffectsList(effects, deviceType) {
  return availableEffects(effects, deviceType)
}

function effectCategory(effect) {
  var e = String(effect || "").toLowerCase().replace(/-/g, "_")
  if (e === "static" || e === "spectrum" || e === "spectrumcycling" || e === "spectrum_cycling" || e === "none" || e === "off") {
    return "presets"
  }
  if (e.indexOf("breath") === 0 || e === "wave" || e.indexOf("starlight") === 0) {
    return "dynamic"
  }
  if (e === "reactive" || e.indexOf("ripple") === 0) {
    return "interactive"
  }
  return "presets"
}

function categoryDisplayName(category) {
  var c = String(category || "").toLowerCase()
  if (c === "presets" || c === "basic") return "Presets"
  if (c === "dynamic" || c === "animated") return "Dynamic"
  if (c === "interactive" || c === "reactive") return "Interactive"
  return "Effects"
}

function categoryIcon(category) {
  var c = String(category || "").toLowerCase()
  if (c === "presets" || c === "basic") return "󰏘"
  if (c === "dynamic" || c === "animated") return "󰑖"
  if (c === "interactive" || c === "reactive") return "󰌌"
  return "󰌵"
}

function isEffectSelected(currentEffect, buttonEffect) {
  var curr = String(currentEffect || "").toLowerCase().replace(/-/g, "_")
  var btn = String(buttonEffect || "").toLowerCase().replace(/-/g, "_")
  if (btn === "breath_single" || btn === "breath" || btn === "breathing") {
    return curr.indexOf("breath") === 0
  }
  if (btn === "ripple") {
    return curr.indexOf("ripple") === 0
  }
  if (btn === "starlight" || btn === "starlight_random") {
    return curr.indexOf("starlight") === 0
  }
  if (btn === "none" || btn === "off") {
    return curr === "none" || curr === "off"
  }
  if (btn === "spectrum" || btn === "spectrumcycling" || btn === "spectrum_cycling") {
    return curr === "spectrum" || curr === "spectrumcycling" || curr === "spectrum_cycling"
  }
  return curr === btn
}

function categorizedEffects(deviceOrEffects, deviceType) {
  var avail = availableEffects(deviceOrEffects, deviceType)
  var deviceObj = (deviceOrEffects && typeof deviceOrEffects === "object" && !Array.isArray(deviceOrEffects)) ? deviceOrEffects : null

  var categories = [
    { id: "presets", label: "Presets", icon: "󰏘", effects: [] },
    { id: "dynamic", label: "Dynamic", icon: "󰑖", effects: [] },
    { id: "interactive", label: "Interactive", icon: "󰌌", effects: [] }
  ]

  var addedBreathing = false
  var addedRipple = false
  var addedStarlight = false

  for (var i = 0; i < avail.length; i++) {
    var eff = avail[i]
    var cat = effectCategory(eff)
    var targetCat = null
    for (var c = 0; c < categories.length; c++) {
      if (categories[c].id === cat) {
        targetCat = categories[c]
        break
      }
    }
    if (!targetCat) targetCat = categories[0]

    // Consolidate sub-modes into primary base effect buttons
    if (eff.indexOf("breath") === 0) {
      if (!addedBreathing) {
        targetCat.effects.push("breath_single")
        addedBreathing = true
      }
    } else if (eff.indexOf("ripple") === 0) {
      if (!addedRipple) {
        targetCat.effects.push("ripple")
        addedRipple = true
      }
    } else if (eff.indexOf("starlight") === 0) {
      if (!addedStarlight) {
        targetCat.effects.push("starlight_random")
        addedStarlight = true
      }
    } else {
      if (targetCat.effects.indexOf(eff) === -1) {
        targetCat.effects.push(eff)
      }
    }
  }

  var result = []
  for (var k = 0; k < categories.length; k++) {
    if (categories[k].effects.length > 0) {
      result.push(categories[k])
    }
  }
  return result
}

function hasCustomizationOptions(device) {
  if (!device) return false
  var eff = device.current_effect
  if (!eff) return false
  if (needsColor(eff) || needsSecondaryColor(eff) || needsDirection(eff) || needsSpeed(eff)) return true
  if (isBreathingEffect(eff) || isRippleEffect(eff) || isStarlightEffect(eff)) return true
  return false
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    parseData: parseData,
    deviceTypeIcon: deviceTypeIcon,
    batteryIcon: batteryIcon,
    batteryColor: batteryColor,
    formatBarText: formatBarText,
    formatDeviceType: formatDeviceType,
    formatDpi: formatDpi,
    formatPollRate: formatPollRate,
    formatBrightness: formatBrightness,
    getPollInterval: getPollInterval,
    summaryText: summaryText,
    effectDisplayName: effectDisplayName,
    effectIcon: effectIcon,
    paletteColors: paletteColors,
    primaryColor: primaryColor,
    secondaryColor: secondaryColor,
    needsColor: needsColor,
    needsSecondaryColor: needsSecondaryColor,
    needsDirection: needsDirection,
    needsSpeed: needsSpeed,
    speedLevels: speedLevels,
    formatSpeed: formatSpeed,
    isBreathingEffect: isBreathingEffect,
    isRippleEffect: isRippleEffect,
    isStarlightEffect: isStarlightEffect,
    defaultEffectsForType: defaultEffectsForType,
    availableEffects: availableEffects,
    hasEffect: hasEffect,
    sanitizeEffectsList: sanitizeEffectsList,
    effectCategory: effectCategory,
    categoryDisplayName: categoryDisplayName,
    categoryIcon: categoryIcon,
    isEffectSelected: isEffectSelected,
    categorizedEffects: categorizedEffects,
    hasCustomizationOptions: hasCustomizationOptions
  }
}
