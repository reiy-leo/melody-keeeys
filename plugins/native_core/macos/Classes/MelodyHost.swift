import ApplicationServices
import Carbon.HIToolbox
import Cocoa
import FlutterMacOS
import ServiceManagement

// MARK: - C audio engine (audio_engine.c, compiled into this pod)

@_silgen_name("ae_version")
func _aeVersion() -> UnsafePointer<CChar>?
@_silgen_name("ae_create")
func _aeCreate(_ preset: Int32) -> OpaquePointer?
@_silgen_name("ae_destroy")
func _aeDestroy(_ engine: OpaquePointer?)
@_silgen_name("ae_load_sound")
func _aeLoadSound(_ engine: OpaquePointer?, _ slot: Int32, _ path: UnsafePointer<CChar>?) -> Int32
@_silgen_name("ae_play")
func _aePlay(_ engine: OpaquePointer?, _ slot: Int32, _ gain: Float, _ pitch: Float) -> Int32
@_silgen_name("ae_set_master_volume")
func _aeSetMasterVolume(_ engine: OpaquePointer?, _ volume: Float)
@_silgen_name("ae_latency_ms")
func _aeLatencyMs(_ engine: OpaquePointer?) -> Float

// MARK: - Packs and settings

/// One entry of assets/sounds/packs.json (generated from kBuiltinPacks).
struct PackInfo {
  let id: String
  let name: String
  let nameEn: String
  let description: String
}

/// Sample layers in slot order: slot = packIndex * 6 + layer.rawValue
/// (same convention as audio_engine_ffi.dart).
enum Layer: Int, CaseIterable {
  case alpha, space, enter, modifier, nav, release

  var assetName: String {
    switch self {
    case .alpha: return "alpha"
    case .space: return "space"
    case .enter: return "enter"
    case .modifier: return "modifier"
    case .nav: return "nav"
    case .release: return "release"
    }
  }

  var baseGain: Float {
    switch self {
    case .alpha: return 1.0
    case .space: return 1.15
    case .enter: return 1.2
    case .modifier: return 0.65
    case .nav: return 0.85
    case .release: return 0.4
    }
  }
}

/// Read-only view over the settings JSON the Dart side writes
/// (AppSettings.toJson). Defaults mirror AppSettings' constructor.
struct HostSettings {
  var raw: [String: Any]

  private func bool(_ k: String, _ d: Bool) -> Bool { raw[k] as? Bool ?? d }
  private func double(_ k: String, _ d: Double) -> Double { (raw[k] as? NSNumber)?.doubleValue ?? d }
  private func int(_ k: String, _ d: Int) -> Int { (raw[k] as? NSNumber)?.intValue ?? d }
  private func string(_ k: String, _ d: String) -> String { raw[k] as? String ?? d }

  var engineEnabled: Bool { bool("engineEnabled", true) }
  var activePackId: String { string("activePackId", "cherry_mx_blue") }
  var volumeDb: Double { double("volumeDb", -6.0) }
  var pitchJitter: Double { double("pitchJitter", 0.04) }
  var antiGhostingMs: Int { int("antiGhostingMs", 35) }
  var modifierAutoRepeat: Bool { bool("modifierAutoRepeat", false) }
  var keyReleaseSound: Bool { bool("keyReleaseSound", false) }
  var keyReleaseGain: Double { double("keyReleaseGain", 0.35) }
  var latencyPreset: Int { min(max(int("latencyPreset", 1), 0), 2) }
  /// 0 = light, 1 = dark, 2 = follow the system (UiTheme index).
  var uiTheme: Int { int("uiTheme", 2) }
  /// 0 = cycle to the next pack, 1 = open the tray panel.
  var leftClickAction: Int { int("leftClickAction", 0) }
  var trayIcon: String { string("trayIcon", "keyboard-music") }
  var muteHotkey: String { string("muteHotkey", "Option+Shift+K") }
  var cycleHotkey: String { string("cycleHotkey", "Option+Shift+]") }

  var volumeLinear: Float {
    let db = volumeDb
    return db <= -60 ? 0 : Float(pow(10.0, db / 20.0))
  }

  func layerPitch(_ layer: Layer) -> Double {
    let tones = raw["layerTones"] as? [String: Any]
    let tone = (tones?[layer.assetName] as? NSNumber)?.doubleValue ?? 0.5
    return 0.85 + 0.4 * tone
  }
}

// MARK: - Audio core (owned by the audio queue)

/// Keystroke play policy, ported from the Dart SoundEngine: classification,
/// anti-ghosting, pitch jitter, auto-repeat and release sounds. Every member
/// is touched on `MelodyHost.audioQueue` only.
final class AudioCore {
  private var engine: OpaquePointer?
  var settings = HostSettings(raw: [:])
  var activePackIndex = 0
  var keystrokes = 0
  private var lastPlayAt: [Int: UInt64] = [:]
  private var lastReleaseAt: UInt64 = 0

  /// (Re)creates the engine and decodes every pack. Returns latency and the
  /// sample paths that failed to load.
  func start(preset: Int, samplePaths: [[String]]) -> (latency: Double?, failures: [String]) {
    if let engine { _aeDestroy(engine) }
    engine = _aeCreate(Int32(preset))
    guard let engine else { return (nil, []) }
    var failures: [String] = []
    for (packIndex, layers) in samplePaths.enumerated() {
      for (layerIndex, path) in layers.enumerated() {
        let slot = Int32(packIndex * Layer.allCases.count + layerIndex)
        if path.withCString({ _aeLoadSound(engine, slot, $0) }) != 0 {
          failures.append(path)
        }
      }
    }
    _aeSetMasterVolume(engine, settings.volumeLinear)
    return (Double(_aeLatencyMs(engine)), failures)
  }

  func setVolume(_ volume: Float) {
    if let engine { _aeSetMasterVolume(engine, volume) }
  }

  private static func nowMs() -> UInt64 { DispatchTime.now().uptimeNanoseconds / 1_000_000 }

  func handleKey(code: Int, down: Bool, isRepeat: Bool) {
    guard settings.engineEnabled, engine != nil else { return }
    let category = KeyClassifier.classify(code)
    guard category != .unknown else { return }
    if isRepeat {
      if category == .modifier && settings.modifierAutoRepeat { playCategory(category) }
      return
    }
    if down {
      playCategory(category)
      keystrokes += 1
    } else if settings.keyReleaseSound,
              [.alpha, .space, .enter, .nav].contains(category) {
      let now = Self.nowMs()
      if now &- lastReleaseAt < UInt64(max(settings.antiGhostingMs, 0)) { return }
      lastReleaseAt = now
      play(.release, packIndex: activePackIndex, gain: Float(settings.keyReleaseGain),
           pitch: jitter() * settings.layerPitch(.release))
    }
  }

  private func playCategory(_ category: KeyCategory) {
    let now = Self.nowMs()
    if let last = lastPlayAt[category.rawValue],
       now &- last < UInt64(max(settings.antiGhostingMs, 0)) { return }
    lastPlayAt[category.rawValue] = now
    let layer = category.layer
    play(layer, packIndex: activePackIndex, gain: layer.baseGain,
         pitch: jitter() * settings.layerPitch(layer))
  }

  private func jitter() -> Double {
    let j = settings.pitchJitter
    return j <= 0 ? 1.0 : 1.0 + Double.random(in: -1...1) * j
  }

  /// Pack switch / Strike button: always sounds (throttle cleared).
  func selectionPreview() {
    lastPlayAt.removeAll()
    play(.alpha, packIndex: activePackIndex, gain: Layer.alpha.baseGain,
         pitch: jitter() * settings.layerPitch(.alpha))
  }

  func preview(packIndex: Int, layer: Layer) {
    play(layer, packIndex: packIndex, gain: layer.baseGain, pitch: jitter())
  }

  private func play(_ layer: Layer, packIndex: Int, gain: Float, pitch: Double) {
    guard let engine else { return }
    let slot = Int32(packIndex * Layer.allCases.count + layer.rawValue)
    _ = _aePlay(engine, slot, gain, Float(pitch))
  }
}

// MARK: - Key classification (mirror of keymap_classifier.dart, macOS table)

enum KeyCategory: Int {
  case alpha, space, enter, modifier, nav, unknown

  var layer: Layer {
    switch self {
    case .alpha, .unknown: return .alpha
    case .space: return .space
    case .enter: return .enter
    case .modifier: return .modifier
    case .nav: return .nav
    }
  }
}

enum KeyClassifier {
  private static let alpha: Set<Int> = [
    0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09,
    0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10, 0x11,
    0x1F, 0x20, 0x22, 0x23,
    0x25, 0x26, 0x28,
    0x2D, 0x2E,
    0x52, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5A, 0x5B,
    // digits and punctuation
    0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D,
    0x1E, 0x21, 0x27, 0x29, 0x2A, 0x2B, 0x2C, 0x2F, 0x32,
  ]
  private static let space: Set<Int> = [0x31]
  private static let enter: Set<Int> = [0x24, 0x33, 0x4C]
  private static let modifier: Set<Int> = [
    0x36, 0x37, 0x38, 0x39, 0x3A, 0x3B, 0x3C, 0x3D, 0x3E, 0x3F,
  ]
  private static let nav: Set<Int> = [
    0x35,
    0x40, 0x4F, 0x50, 0x5A, 0x6A,
    0x60, 0x61, 0x62, 0x63, 0x64, 0x65, 0x67, 0x69, 0x6B, 0x6D, 0x6F, 0x71, 0x76, 0x78, 0x7A,
    0x48, 0x49, 0x4A,
    0x41, 0x43, 0x45, 0x47, 0x4B, 0x4E, 0x51,
    0x72, 0x73, 0x74, 0x75, 0x77, 0x79,
    0x7B, 0x7C, 0x7D, 0x7E,
  ]

  static func classify(_ code: Int) -> KeyCategory {
    if space.contains(code) { return .space }
    if enter.contains(code) { return .enter }
    if modifier.contains(code) { return .modifier }
    if alpha.contains(code) { return .alpha }
    if nav.contains(code) { return .nav }
    return .unknown
  }
}

// MARK: - Host

/// The always-on part of Melody Keeeys on macOS: menu-bar icon and menu,
/// tray panel, global key hook, hotkeys, audio engine and settings
/// persistence, all native. A Flutter engine only exists while the settings
/// window is open (Runner creates it on `openSettings` and shuts it down on
/// `closeSettings`), so a menu-bar-only session carries no Dart VM, Skia
/// context or GPU surfaces.
public final class MelodyHost: NSObject, NSPopoverDelegate {
  public static let shared = MelodyHost()

  /// Runner hooks: create / tear down the settings window and its engine.
  public var openSettings: (() -> Void)?
  public var closeSettings: (() -> Void)?
  public var settingsShown: (() -> Void)?

  static let settingsKey = "flutter.melody_keeeys.settings.v1"

  let audioQueue = DispatchQueue(label: "melody.audio", qos: .userInteractive)
  private let audio = AudioCore()

  private(set) var packs: [PackInfo] = []
  private(set) var settings = HostSettings(raw: [:])
  private var latencyMs: Double?
  private var loadError: String?
  private(set) var hookRunning = false
  private var engineVersion = "-"
  private var started = false

  private var statusItem: NSStatusItem?
  private var currentIconId: String?
  private var popover: NSPopover?
  private var hudModel: HudModel?

  private var channel: FlutterMethodChannel?
  private var keystrokeTimer: Timer?
  private var lastSentKeystrokes = -1
  private var saveWork: DispatchWorkItem?

  private var tap: CFMachPort?
  private var tapSource: CFRunLoopSource?
  private var tapRunLoop: CFRunLoop?

  private var hotKeyRefs: [EventHotKeyRef] = []
  private var hotKeyHandler: EventHandlerRef?
  private var hotKeySignature = ""

  // MARK: Launch

  public func start() {
    guard !started else { return }
    started = true
    if let v = _aeVersion() { engineVersion = String(cString: v) }
    packs = Self.loadPacks()
    settings = Self.loadSettings()
    pushSettingsToAudio()

    setupStatusItem()
    registerHotkeys()
    restartAudio()

    NotificationCenter.default.addObserver(
      self, selector: #selector(willTerminate),
      name: NSApplication.willTerminateNotification, object: nil)

    if !startHook() {
      // Missing Accessibility grant: the settings page walks the user
      // through it, so open it right away (the only time it opens by itself).
      openSettings?()
    }
  }

  @objc private func willTerminate() {
    flushSettings()
  }

  // MARK: Assets

  private static func flutterAsset(_ relative: String) -> URL? {
    let contents = Bundle.main.bundleURL.appendingPathComponent("Contents")
    let candidates = [
      contents.appendingPathComponent("Frameworks/App.framework/Resources/flutter_assets"),
      contents.appendingPathComponent("Frameworks/App.framework/Versions/A/Resources/flutter_assets"),
    ]
    for base in candidates {
      let url = base.appendingPathComponent(relative)
      if FileManager.default.fileExists(atPath: url.path) { return url }
    }
    return nil
  }

  private static func loadPacks() -> [PackInfo] {
    guard let url = flutterAsset("assets/sounds/packs.json"),
          let data = try? Data(contentsOf: url),
          let list = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
    else {
      NSLog("[melody] packs.json missing")
      return []
    }
    return list.compactMap { p in
      guard let id = p["id"] as? String else { return nil }
      return PackInfo(
        id: id,
        name: p["name"] as? String ?? id,
        nameEn: p["nameEn"] as? String ?? "",
        description: p["description"] as? String ?? "")
    }
  }

  private func samplePaths() -> [[String]] {
    packs.map { pack in
      Layer.allCases.map { layer in
        Self.flutterAsset("assets/sounds/\(pack.id)/\(layer.assetName).wav")?.path
          ?? "missing:\(pack.id)/\(layer.assetName)"
      }
    }
  }

  // MARK: Settings

  private static func loadSettings() -> HostSettings {
    guard let json = UserDefaults.standard.string(forKey: settingsKey),
          let data = json.data(using: .utf8),
          let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return HostSettings(raw: [:]) }
    return HostSettings(raw: raw)
  }

  private func scheduleSave() {
    saveWork?.cancel()
    let work = DispatchWorkItem { [weak self] in self?.flushSettings() }
    saveWork = work
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
  }

  private func flushSettings() {
    saveWork?.cancel()
    saveWork = nil
    guard JSONSerialization.isValidJSONObject(settings.raw),
          let data = try? JSONSerialization.data(withJSONObject: settings.raw),
          let json = String(data: data, encoding: .utf8) else { return }
    UserDefaults.standard.set(json, forKey: Self.settingsKey)
  }

  private var activePackIndex: Int {
    packs.firstIndex { $0.id == settings.activePackId } ?? 0
  }

  private func pushSettingsToAudio() {
    let snapshot = settings
    let index = activePackIndex
    audioQueue.async { [audio = self.audio] in
      audio.settings = snapshot
      audio.activePackIndex = index
      audio.setVolume(snapshot.volumeLinear)
    }
  }

  private func restartAudio() {
    let preset = settings.latencyPreset
    let paths = samplePaths()
    audioQueue.async { [weak self, audio = self.audio] in
      let result = audio.start(preset: preset, samplePaths: paths)
      DispatchQueue.main.async {
        guard let self else { return }
        self.latencyMs = result.latency
        if result.latency == nil {
          self.loadError = "Audio engine init failed: ae_create failed"
        } else if let first = result.failures.first {
          self.loadError = "Failed to load \(result.failures.count) samples, e.g. \(first)"
        } else {
          self.loadError = nil
        }
        self.stateChanged(notifyFlutter: true)
      }
    }
  }

  /// Applies a settings change from any source. Flutter-originated changes
  /// are not echoed back (a slider drag would otherwise snap back to stale
  /// values in flight).
  private func apply(_ next: HostSettings, fromFlutter: Bool) {
    let old = settings
    settings = next
    pushSettingsToAudio()
    if next.latencyPreset != old.latencyPreset { restartAudio() }
    if next.muteHotkey != old.muteHotkey || next.cycleHotkey != old.cycleHotkey {
      registerHotkeys()
    }
    scheduleSave()
    stateChanged(notifyFlutter: !fromFlutter)
  }

  private func update(_ key: String, _ value: Any) {
    var raw = settings.raw
    raw[key] = value
    apply(HostSettings(raw: raw), fromFlutter: false)
  }

  func selectPack(_ id: String, preview: Bool = true) {
    var raw = settings.raw
    raw["activePackId"] = id
    settings = HostSettings(raw: raw)
    let snapshot = settings
    let index = activePackIndex
    // Switch and sound right away; menu, panel and persistence follow.
    audioQueue.async { [audio = self.audio] in
      audio.settings = snapshot
      audio.activePackIndex = index
      if preview { audio.selectionPreview() }
    }
    scheduleSave()
    stateChanged(notifyFlutter: true)
  }

  func cyclePack() {
    guard !packs.isEmpty else { return }
    selectPack(packs[(activePackIndex + 1) % packs.count].id)
  }

  func toggleEngine() {
    update("engineEnabled", !settings.engineEnabled)
  }

  func preview(packId: String, layer: Layer = .alpha) {
    let index = packs.firstIndex { $0.id == packId } ?? 0
    audioQueue.async { [audio = self.audio] in audio.preview(packIndex: index, layer: layer) }
  }

  /// Refresh every native surface and, when asked, the open settings UI.
  private func stateChanged(notifyFlutter: Bool) {
    refreshStatusItem()
    refreshHud()
    if notifyFlutter { channel?.invokeMethod("state", arguments: stateMap()) }
  }

  private func stateMap() -> [String: Any] {
    var json = "{}"
    if let data = try? JSONSerialization.data(withJSONObject: settings.raw),
       let s = String(data: data, encoding: .utf8) { json = s }
    return [
      "settings": json,
      "latencyMs": latencyMs.map { $0 as Any } ?? NSNull(),
      "engineVersion": engineVersion,
      "hookRunning": hookRunning,
      "loadError": loadError.map { $0 as Any } ?? NSNull(),
    ]
  }

  // MARK: Flutter bridge (settings window only)

  /// Called by NativeCorePlugin when a settings engine registers.
  func attach(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "melody/host", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }
      self.handle(call, result: result)
    }
    self.channel = channel
    lastSentKeystrokes = -1
    keystrokeTimer?.invalidate()
    keystrokeTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
      self?.sendKeystrokes()
    }

    let launch = FlutterMethodChannel(name: "launch_at_startup", binaryMessenger: messenger)
    launch.setMethodCallHandler { call, result in
      Self.handleLaunchAtStartup(call, result: result)
    }
  }

  private func detachFlutter() {
    keystrokeTimer?.invalidate()
    keystrokeTimer = nil
    channel?.setMethodCallHandler(nil)
    channel = nil
  }

  private func sendKeystrokes() {
    audioQueue.async { [weak self, audio = self.audio] in
      let count = audio.keystrokes
      DispatchQueue.main.async {
        guard let self, let channel = self.channel, count != self.lastSentKeystrokes else { return }
        self.lastSentKeystrokes = count
        channel.invokeMethod("keystrokes", arguments: count)
      }
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    switch call.method {
    case "getState":
      var state = stateMap()
      audioQueue.sync { state["keystrokes"] = audio.keystrokes }
      result(state)
    case "updateSettings":
      if let json = call.arguments as? String,
         let data = json.data(using: .utf8),
         let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
        apply(HostSettings(raw: raw), fromFlutter: true)
      }
      result(nil)
    case "selectPack":
      if let id = args?["packId"] as? String {
        selectPack(id, preview: args?["preview"] as? Bool ?? true)
      }
      result(nil)
    case "preview":
      let layer = Layer.allCases.first { $0.assetName == args?["layer"] as? String } ?? .alpha
      preview(packId: args?["packId"] as? String ?? settings.activePackId, layer: layer)
      result(nil)
    case "startHook":
      result(startHook())
    case "settingsShown":
      settingsShown?()
      result(nil)
    case "settingsClosed":
      result(nil)
      flushSettings()
      // Tear the engine down on the next runloop turn, after this reply.
      DispatchQueue.main.async { [weak self] in
        self?.detachFlutter()
        self?.closeSettings?()
      }
    case "quit":
      result(nil)
      DispatchQueue.main.async { NSApp.terminate(nil) }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static func handleLaunchAtStartup(_ call: FlutterMethodCall, result: FlutterResult) {
    guard #available(macOS 13.0, *) else {
      result(call.method == "launchAtStartupIsEnabled" ? false : nil)
      return
    }
    switch call.method {
    case "launchAtStartupIsEnabled":
      result(SMAppService.mainApp.status == .enabled)
    case "launchAtStartupSetEnabled":
      let enable = (call.arguments as? [String: Any])?["setEnabledValue"] as? Bool ?? false
      do {
        if enable { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        result(nil)
      } catch {
        result(FlutterError(code: "login_item", message: error.localizedDescription, details: nil))
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: Key hook (CGEventTap)

  /// Starts the global tap; true when it is running. Requires Accessibility:
  /// without it macOS may hand back a tap that silently receives nothing.
  @discardableResult
  func startHook() -> Bool {
    if tap != nil { return true }
    guard AXIsProcessTrusted() else {
      hookRunning = false
      return false
    }
    let mask: CGEventMask =
      (1 << CGEventType.keyDown.rawValue)
      | (1 << CGEventType.keyUp.rawValue)
      | (1 << CGEventType.flagsChanged.rawValue)
    // Active tap (events passed through unchanged): covered by the stable
    // Accessibility grant, unlike listen-only taps (Input Monitoring).
    guard let tap = CGEvent.tapCreate(
      tap: .cgSessionEventTap,
      place: .headInsertEventTap,
      options: .defaultTap,
      eventsOfInterest: mask,
      callback: { _, type, event, _ in MelodyHost.tapCallback(type, event) },
      userInfo: nil)
    else {
      hookRunning = false
      return false
    }
    self.tap = tap
    let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    tapSource = source
    // Own thread: an active tap holds up system-wide key delivery until its
    // callback returns, so it must never wait on the main thread.
    let thread = Thread { [weak self] in
      guard let self, let source = self.tapSource, let tap = self.tap else { return }
      self.tapRunLoop = CFRunLoopGetCurrent()
      CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .defaultMode)
      CGEvent.tapEnable(tap: tap, enable: true)
      CFRunLoopRun()
    }
    thread.name = "melody.eventtap"
    thread.qualityOfService = .userInteractive
    thread.start()
    hookRunning = true
    stateChanged(notifyFlutter: true)
    return true
  }

  private static func tapCallback(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
    let host = MelodyHost.shared
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      if let tap = host.tap { CGEvent.tapEnable(tap: tap, enable: true) }
      return Unmanaged.passUnretained(event)
    }
    let code = Int(event.getIntegerValueField(.keyboardEventKeycode))
    var down = type == .keyDown
    var isRepeat = false
    if type == .flagsChanged {
      // Modifiers emit flagsChanged, not keyDown/up: derive state from flags.
      let mask = modifierMask(code)
      down = !mask.isEmpty && event.flags.intersection(mask) == mask
    } else {
      isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) == 1
    }
    host.audioQueue.async { [audio = host.audio] in
      audio.handleKey(code: code, down: down, isRepeat: isRepeat)
    }
    return Unmanaged.passUnretained(event)
  }

  private static func modifierMask(_ code: Int) -> CGEventFlags {
    switch code {
    case kVK_Shift, kVK_RightShift: return .maskShift
    case kVK_Command, kVK_RightCommand: return .maskCommand
    case kVK_Option, kVK_RightOption: return .maskAlternate
    case kVK_Control, kVK_RightControl: return .maskControl
    case kVK_CapsLock: return .maskAlphaShift
    case kVK_Function: return .maskSecondaryFn
    default: return []
    }
  }

  // MARK: Hotkeys (Carbon, no permission needed)

  private func registerHotkeys() {
    let signature = settings.muteHotkey + "|" + settings.cycleHotkey
    if signature == hotKeySignature && !hotKeyRefs.isEmpty { return }
    hotKeySignature = signature
    for ref in hotKeyRefs { UnregisterEventHotKey(ref) }
    hotKeyRefs.removeAll()

    if hotKeyHandler == nil {
      var spec = EventTypeSpec(
        eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
      InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
        var id = EventHotKeyID()
        GetEventParameter(
          event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
          nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
        DispatchQueue.main.async {
          switch id.id {
          case 1: MelodyHost.shared.toggleEngine()
          case 2: MelodyHost.shared.cyclePack()
          default: break
          }
        }
        return OSStatus(noErr)
      }, 1, &spec, nil, &hotKeyHandler)
    }

    for (index, spec) in [settings.muteHotkey, settings.cycleHotkey].enumerated() {
      guard let parsed = Self.parseHotkey(spec) else { continue }
      let (code, modifiers) = parsed
      var ref: EventHotKeyRef?
      let id = EventHotKeyID(signature: OSType(0x4D4B_4559), id: UInt32(index + 1)) // 'MKEY'
      let status = RegisterEventHotKey(
        UInt32(code), UInt32(modifiers), id, GetApplicationEventTarget(), 0, &ref)
      if status == OSStatus(noErr), let ref { hotKeyRefs.append(ref) }
    }
  }

  /// "Option+Shift+K" / "Ctrl+Alt+]" -> (virtual key code, Carbon modifiers).
  static func parseHotkey(_ spec: String) -> (Int, Int)? {
    var parts = spec.split(separator: "+").map { $0.trimmingCharacters(in: .whitespaces) }
    guard parts.count >= 2, let key = parts.popLast(), key.count == 1 else { return nil }
    var modifiers = 0
    for part in parts {
      switch part.lowercased() {
      case "option", "alt": modifiers |= optionKey
      case "ctrl", "control": modifiers |= controlKey
      case "shift": modifiers |= shiftKey
      case "cmd", "meta", "command": modifiers |= cmdKey
      default: return nil
      }
    }
    guard let code = keyCodes[key.lowercased()] else { return nil }
    return (code, modifiers)
  }

  private static let keyCodes: [String: Int] = [
    "a": kVK_ANSI_A, "b": kVK_ANSI_B, "c": kVK_ANSI_C, "d": kVK_ANSI_D, "e": kVK_ANSI_E,
    "f": kVK_ANSI_F, "g": kVK_ANSI_G, "h": kVK_ANSI_H, "i": kVK_ANSI_I, "j": kVK_ANSI_J,
    "k": kVK_ANSI_K, "l": kVK_ANSI_L, "m": kVK_ANSI_M, "n": kVK_ANSI_N, "o": kVK_ANSI_O,
    "p": kVK_ANSI_P, "q": kVK_ANSI_Q, "r": kVK_ANSI_R, "s": kVK_ANSI_S, "t": kVK_ANSI_T,
    "u": kVK_ANSI_U, "v": kVK_ANSI_V, "w": kVK_ANSI_W, "x": kVK_ANSI_X, "y": kVK_ANSI_Y,
    "z": kVK_ANSI_Z,
    "[": kVK_ANSI_LeftBracket, "]": kVK_ANSI_RightBracket, "\\": kVK_ANSI_Backslash,
    ";": kVK_ANSI_Semicolon, "'": kVK_ANSI_Quote, ",": kVK_ANSI_Comma, ".": kVK_ANSI_Period,
    "/": kVK_ANSI_Slash, "`": kVK_ANSI_Grave, "-": kVK_ANSI_Minus, "=": kVK_ANSI_Equal,
  ]

  // MARK: Menu-bar icon

  private func setupStatusItem() {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    statusItem = item
    if let button = item.button {
      button.target = self
      button.action = #selector(statusItemClicked(_:))
      button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }
    refreshStatusItem()
  }

  private func refreshStatusItem() {
    guard let button = statusItem?.button else { return }
    let iconId = settings.trayIcon
    if iconId != currentIconId, let image = Self.trayImage(iconId) {
      // Keep the current icon when the new one fails to load.
      currentIconId = iconId
      button.image = image
    }
    let name = packs.indices.contains(activePackIndex) ? packs[activePackIndex].name : ""
    button.toolTip = "Melody Keeeys · 旋律键音 — 正在使用：\(name)"
    button.appearsDisabled = !settings.engineEnabled
  }

  private static func trayImage(_ iconId: String) -> NSImage? {
    for asset in ["assets/icons/tray_\(iconId)_template.png", "assets/icons/tray_template.png"] {
      if let url = flutterAsset(asset), let image = NSImage(contentsOf: url) {
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = true
        return image
      }
    }
    return nil
  }

  @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
    let event = NSApp.currentEvent
    if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
      showMenu()
    } else if settings.leftClickAction == 1 {
      toggleHud()
    } else {
      cyclePack()
    }
  }

  private func showMenu() {
    guard let item = statusItem else { return }
    popover?.performClose(nil)
    let menu = buildMenu()
    item.menu = menu
    item.button?.performClick(nil)
    item.menu = nil
  }

  private func buildMenu() -> NSMenu {
    let menu = NSMenu()
    menu.autoenablesItems = false
    let current = packs.indices.contains(activePackIndex) ? packs[activePackIndex].name : "-"
    let head = NSMenuItem(title: "正在使用：\(current)", action: nil, keyEquivalent: "")
    head.isEnabled = false
    menu.addItem(head)
    menu.addItem(.separator())

    for (i, pack) in packs.enumerated() {
      let item = NSMenuItem(
        title: "\(i + 1). \(pack.name)（\(pack.nameEn)）",
        action: #selector(menuSelectPack(_:)), keyEquivalent: "")
      item.target = self
      item.tag = i
      item.state = i == activePackIndex ? .on : .off
      menu.addItem(item)
    }
    menu.addItem(.separator())

    let engine = NSMenuItem(title: "声音引擎：已开启", action: #selector(menuToggleEngine), keyEquivalent: "")
    engine.target = self
    engine.state = settings.engineEnabled ? .on : .off
    menu.addItem(engine)
    let hud = NSMenuItem(title: "打开托盘面板", action: #selector(menuShowHud), keyEquivalent: "")
    hud.target = self
    menu.addItem(hud)
    let prefs = NSMenuItem(title: "设置…", action: #selector(menuOpenSettings), keyEquivalent: ",")
    prefs.target = self
    menu.addItem(prefs)
    menu.addItem(.separator())
    let quit = NSMenuItem(title: "退出 Melody Keeeys", action: #selector(menuQuit), keyEquivalent: "q")
    quit.target = self
    menu.addItem(quit)
    return menu
  }

  @objc private func menuSelectPack(_ sender: NSMenuItem) {
    guard packs.indices.contains(sender.tag) else { return }
    selectPack(packs[sender.tag].id)
  }

  @objc private func menuToggleEngine() { toggleEngine() }
  @objc private func menuShowHud() {
    // Let the menu finish closing before anchoring the popover.
    DispatchQueue.main.async { [weak self] in self?.showHud() }
  }
  @objc private func menuOpenSettings() { requestSettings() }
  @objc private func menuQuit() { NSApp.terminate(nil) }

  func requestSettings() {
    popover?.performClose(nil)
    openSettings?()
  }

  // MARK: Tray panel (native popover; built on open, released on close)

  private func toggleHud() {
    if popover?.isShown == true {
      popover?.performClose(nil)
    } else {
      showHud()
    }
  }

  private func showHud() {
    guard let button = statusItem?.button else { return }
    if popover?.isShown == true { return }
    let model = HudModel()
    hudModel = model
    refreshHud()
    let popover = NSPopover()
    popover.behavior = .transient
    popover.animates = false
    popover.delegate = self
    popover.contentViewController = HudViewController(model: model, packs: packs, host: self)
    switch settings.uiTheme {
    case 0: popover.appearance = NSAppearance(named: .aqua)
    case 1: popover.appearance = NSAppearance(named: .darkAqua)
    default: popover.appearance = nil
    }
    self.popover = popover
    NSApp.activate(ignoringOtherApps: true)
    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
  }

  public func popoverDidClose(_ notification: Notification) {
    // Drop the whole view hierarchy; it is rebuilt on the next open.
    popover?.contentViewController = nil
    popover = nil
    hudModel = nil
  }

  private func refreshHud() {
    guard let model = hudModel else { return }
    model.engineEnabled = settings.engineEnabled
    model.activePackId = settings.activePackId
    model.latencyMs = latencyMs
  }
}
