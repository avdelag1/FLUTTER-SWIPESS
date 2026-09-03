import AVFoundation
import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var privacyChannel: FlutterMethodChannel?
  private var videoOptimizerChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Required by flutter_local_notifications so a tapped re-engagement
    // reminder reaches Dart instead of only opening the app.
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Cap `@capacitor-community/privacy-screen` — see PrivacyScreen.swift.
    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "swipess-privacy-screen")
    if let messenger = registrar?.messenger() {
      let privacy = FlutterMethodChannel(
        name: "swipess/privacy_screen",
        binaryMessenger: messenger
      )
      privacy.setMethodCallHandler { call, result in
        switch call.method {
        case "enable":
          PrivacyScreen.shared.setEnabled(true)
          result(true)
        case "disable":
          PrivacyScreen.shared.setEnabled(false)
          result(true)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
      privacyChannel = privacy

      // User camera files are normalized before upload so iPhone HEVC/MOV files
      // do not become slow dashboard downloads. AVFoundation produces an MP4,
      // applies the selected trim/portrait framing and moves the MP4 metadata to
      // the front for progressive network playback.
      let optimizer = FlutterMethodChannel(
        name: "swipess/video_optimizer",
        binaryMessenger: messenger
      )
      optimizer.setMethodCallHandler { [weak self] call, result in
        guard call.method == "optimize" else {
          result(FlutterMethodNotImplemented)
          return
        }
        guard
          let self,
          let args = call.arguments as? [String: Any],
          let path = args["path"] as? String,
          !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
          result(FlutterError(code: "invalid_path", message: "Missing input video path", details: nil))
          return
        }

        let startMs = (args["startMs"] as? NSNumber)?.int64Value ?? 0
        let endMs = (args["endMs"] as? NSNumber)?.int64Value ?? -1
        let portraitCrop = (args["portraitCrop"] as? Bool) ?? false
        let cropX = min(1.0, max(0.0, (args["cropX"] as? NSNumber)?.doubleValue ?? 0.5))
        let includeOriginalAudio = (args["includeOriginalAudio"] as? Bool) ?? true

        self.optimizeVideo(
          path: path,
          startMs: max(0, startMs),
          endMs: endMs,
          portraitCrop: portraitCrop,
          cropX: cropX,
          includeOriginalAudio: includeOriginalAudio,
          result: result
        )
      }
      videoOptimizerChannel = optimizer
    }
  }

  private func optimizeVideo(
    path: String,
    startMs: Int64,
    endMs: Int64,
    portraitCrop: Bool,
    cropX: Double,
    includeOriginalAudio: Bool,
    result: @escaping FlutterResult
  ) {
    let sourceURL = URL(fileURLWithPath: path)
    guard FileManager.default.fileExists(atPath: sourceURL.path) else {
      result(FlutterError(code: "missing_video", message: "Selected video is unavailable", details: nil))
      return
    }

    let asset = AVURLAsset(url: sourceURL)
    guard let sourceVideo = asset.tracks(withMediaType: .video).first else {
      result(FlutterError(code: "missing_video_track", message: "The selected file has no video track", details: nil))
      return
    }

    let assetDuration = asset.duration
    let requestedStart = CMTime(milliseconds: startMs)
    let safeStart = CMTimeCompare(requestedStart, assetDuration) < 0 ? requestedStart : .zero
    let requestedEnd = endMs > startMs ? CMTime(milliseconds: endMs) : assetDuration
    let safeEnd = CMTimeCompare(requestedEnd, assetDuration) < 0 ? requestedEnd : assetDuration
    let rangeDuration = CMTimeSubtract(safeEnd, safeStart)
    guard CMTimeCompare(rangeDuration, CMTime(value: 1, timescale: 10)) > 0 else {
      result(FlutterError(code: "invalid_range", message: "The selected video window is too short", details: nil))
      return
    }
    let sourceRange = CMTimeRange(start: safeStart, duration: rangeDuration)

    let composition = AVMutableComposition()
    guard let videoTrack = composition.addMutableTrack(
      withMediaType: .video,
      preferredTrackID: kCMPersistentTrackID_Invalid
    ) else {
      result(FlutterError(code: "composition_failed", message: "Could not prepare video track", details: nil))
      return
    }

    do {
      try videoTrack.insertTimeRange(sourceRange, of: sourceVideo, at: .zero)
      videoTrack.preferredTransform = sourceVideo.preferredTransform

      if includeOriginalAudio, let sourceAudio = asset.tracks(withMediaType: .audio).first,
         let audioTrack = composition.addMutableTrack(
          withMediaType: .audio,
          preferredTrackID: kCMPersistentTrackID_Invalid
         ) {
        try? audioTrack.insertTimeRange(sourceRange, of: sourceAudio, at: .zero)
      }
    } catch {
      result(FlutterError(code: "composition_failed", message: error.localizedDescription, details: nil))
      return
    }

    let preset = AVAssetExportPreset1280x720
    guard let exporter = AVAssetExportSession(asset: composition, presetName: preset) else {
      result(FlutterError(code: "export_unavailable", message: "Could not create video exporter", details: nil))
      return
    }

    if portraitCrop {
      let target = CGSize(width: 720, height: 1280)
      let natural = sourceVideo.naturalSize
      let preferred = sourceVideo.preferredTransform
      let transformedRect = CGRect(origin: .zero, size: natural).applying(preferred)
      let oriented = CGSize(width: abs(transformedRect.width), height: abs(transformedRect.height))

      if oriented.width > 0, oriented.height > 0 {
        let scale = max(target.width / oriented.width, target.height / oriented.height)
        let scaledWidth = oriented.width * scale
        let scaledHeight = oriented.height * scale
        let overflowX = max(0, scaledWidth - target.width)
        let overflowY = max(0, scaledHeight - target.height)

        // Normalize the preferred orientation first, then scale and shift into
        // a 9:16 render canvas. cropX=0 shows the left side, 1 shows the right.
        var transform = preferred
        transform = transform.concatenating(
          CGAffineTransform(translationX: -transformedRect.minX, y: -transformedRect.minY)
        )
        transform = transform.concatenating(CGAffineTransform(scaleX: scale, y: scale))
        transform.tx -= overflowX * CGFloat(cropX)
        transform.ty -= overflowY * 0.5

        let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        layer.setTransform(transform, at: .zero)
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: rangeDuration)
        instruction.layerInstructions = [layer]

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = target
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        videoComposition.instructions = [instruction]
        exporter.videoComposition = videoComposition
      }
    }

    let outputURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("swipess_\(UUID().uuidString).mp4")
    try? FileManager.default.removeItem(at: outputURL)

    exporter.outputURL = outputURL
    exporter.outputFileType = .mp4
    exporter.shouldOptimizeForNetworkUse = true
    exporter.exportAsynchronously {
      DispatchQueue.main.async {
        switch exporter.status {
        case .completed:
          let attributes = try? FileManager.default.attributesOfItem(atPath: outputURL.path)
          let size = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
          guard size > 64 else {
            result(FlutterError(code: "empty_export", message: "Video export produced no data", details: nil))
            return
          }
          result([
            "path": outputURL.path,
            "name": outputURL.lastPathComponent,
            "mimeType": "video/mp4",
            "size": size,
          ])
        case .failed, .cancelled:
          result(FlutterError(
            code: "video_export_failed",
            message: exporter.error?.localizedDescription ?? "Could not optimize video",
            details: nil
          ))
        default:
          result(FlutterError(code: "video_export_failed", message: "Video export did not complete", details: nil))
        }
      }
    }
  }
}

private extension CMTime {
  init(milliseconds: Int64) {
    self.init(value: milliseconds, timescale: 1000)
  }
}
