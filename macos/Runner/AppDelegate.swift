import Cocoa
import FlutterMacOS
import WidgetKit
import MediaPlayer

class MacOSMediaControls: NSObject {
  static let shared = MacOSMediaControls()
  private var channel: FlutterMethodChannel?
  private var isInitialized = false

  func setup(with messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "com.gokadzev.musify/macos_media_controls", binaryMessenger: messenger)
    channel?.setMethodCallHandler { [weak self] (call, result) in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "initialize":
      if !isInitialized {
        setupRemoteCommands()
        isInitialized = true
      }
      result(nil)
    case "update":
      guard let args = call.arguments as? [String: Any] else {
        result(nil)
        return
      }
      updateNowPlaying(with: args)
      result(nil)
    case "dispose":
      clearNowPlaying()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func setupRemoteCommands() {
    let commandCenter = MPRemoteCommandCenter.shared()

    commandCenter.playCommand.isEnabled = true
    commandCenter.playCommand.addTarget { [weak self] _ in
      self?.channel?.invokeMethod("button", arguments: "play")
      return .success
    }

    commandCenter.pauseCommand.isEnabled = true
    commandCenter.pauseCommand.addTarget { [weak self] _ in
      self?.channel?.invokeMethod("button", arguments: "pause")
      return .success
    }

    commandCenter.togglePlayPauseCommand.isEnabled = true
    commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
      self?.channel?.invokeMethod("button", arguments: "toggle")
      return .success
    }

    commandCenter.nextTrackCommand.isEnabled = true
    commandCenter.nextTrackCommand.addTarget { [weak self] _ in
      self?.channel?.invokeMethod("button", arguments: "next")
      return .success
    }

    commandCenter.previousTrackCommand.isEnabled = true
    commandCenter.previousTrackCommand.addTarget { [weak self] _ in
      self?.channel?.invokeMethod("button", arguments: "previous")
      return .success
    }

    commandCenter.changePlaybackPositionCommand.isEnabled = true
    commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
      if let positionEvent = event as? MPChangePlaybackPositionCommandEvent {
        self?.channel?.invokeMethod("seek", arguments: positionEvent.positionTime)
        return .success
      }
      return .commandFailed
    }
  }

  private func updateNowPlaying(with data: [String: Any]) {
    guard let enabled = data["enabled"] as? Bool, enabled else {
      MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
      return
    }

    var nowPlayingInfo = [String: Any]()
    nowPlayingInfo[MPMediaItemPropertyTitle] = data["title"] as? String ?? ""
    nowPlayingInfo[MPMediaItemPropertyArtist] = data["artist"] as? String ?? ""
    nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = data["album"] as? String ?? ""

    if let duration = data["durationSeconds"] as? Double, duration > 0 {
      nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
    }
    if let position = data["positionSeconds"] as? Double {
      nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = position
    }

    let isPlaying = (data["status"] as? String) == "playing"
    nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

    if let artPath = data["artPath"] as? String, !artPath.isEmpty,
       let image = NSImage(contentsOfFile: artPath) {
      if #available(macOS 10.13.2, *) {
        let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
      }
    }

    MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo

    let commandCenter = MPRemoteCommandCenter.shared()
    commandCenter.nextTrackCommand.isEnabled = (data["canGoNext"] as? Bool) ?? true
    commandCenter.previousTrackCommand.isEnabled = (data["canGoPrevious"] as? Bool) ?? true
  }

  private func clearNowPlaying() {
    MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
  }
}

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationWillFinishLaunching(_ notification: Notification) {
    let bundleID = Bundle.main.bundleIdentifier ?? "com.gokadzev.musify"
    let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
    let currentPID = ProcessInfo.processInfo.processIdentifier

    for app in runningApps {
      if app.processIdentifier != currentPID {
        // Bring existing instance to the foreground
        app.activate(options: [.activateIgnoringOtherApps])
        // Terminate duplicate instance before opening database locks
        NSApp.terminate(nil)
        return
      }
    }
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if !flag {
      mainFlutterWindow?.makeKeyAndOrderFront(nil)
    }
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    let controller = mainFlutterWindow?.contentViewController as? FlutterViewController
    if let messenger = controller?.engine.binaryMessenger {
      MacOSMediaControls.shared.setup(with: messenger)

      let channel = FlutterMethodChannel(name: "com.gokadzev.musify/widget", binaryMessenger: messenger)
      channel.setMethodCallHandler { call, result in
        if call.method == "reloadWidget" {
          if #available(macOS 11.0, *) {
            WidgetCenter.shared.reloadAllTimelines()
          }
          result(true)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
    super.applicationDidFinishLaunching(notification)
  }
}
