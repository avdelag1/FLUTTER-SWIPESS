import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var privacyChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Cap `@capacitor-community/privacy-screen` — see PrivacyScreen.swift.
    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "swipess-privacy-screen")
    if let messenger = registrar?.messenger() {
      let channel = FlutterMethodChannel(
        name: "swipess/privacy_screen",
        binaryMessenger: messenger
      )
      channel.setMethodCallHandler { call, result in
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
      privacyChannel = channel
    }
  }
}
