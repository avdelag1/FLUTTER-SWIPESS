import Flutter
import UIKit

/// Cap `@capacitor-community/privacy-screen`. iOS cannot block a screenshot, so
/// the plugin does what every banking app does instead: while a protected
/// surface is open (VAP ID card, document vault) it covers the window the moment
/// the app stops being frontmost, which is exactly when iOS grabs the snapshot
/// for the task switcher.
///
/// Screen recording / AirPlay (`UIScreen.isCaptured`) is detectable. While a
/// protected surface is open we paint an opaque cover over the window so the
/// recording does not contain passports, contracts, or Local/VIP ID.
///
/// The app is scene based (`UIApplicationSceneManifest` in Info.plist), so this
/// listens to the `UIScene` notifications; UIKit does not deliver the
/// `UIApplication` lifecycle notifications to scene-based apps.
final class PrivacyScreen {
    static let shared = PrivacyScreen()

    private var isEnabled = false
    private var cover: UIView?
    private var captureCover: UIView?
    var captureSink: FlutterEventSink?

    var isCaptured: Bool { UIScreen.main.isCaptured }

    private init() {
        let center = NotificationCenter.default
        center.addObserver(
            self,
            selector: #selector(hideCover),
            name: UIScene.didActivateNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(showCover(_:)),
            name: UIScene.willDeactivateNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(capturedDidChange),
            name: UIScreen.capturedDidChangeNotification,
            object: nil
        )
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if !enabled {
            hideCover()
            hideCaptureCover()
        } else {
            syncCaptureCover()
        }
    }

    @objc private func showCover(_ notification: Notification) {
        guard isEnabled, cover == nil else { return }
        guard let window = keyWindow(from: notification.object as? UIWindowScene) else { return }

        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterialDark))
        blur.frame = window.bounds
        blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blur.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        window.addSubview(blur)
        cover = blur
    }

    @objc private func hideCover() {
        cover?.removeFromSuperview()
        cover = nil
    }

    @objc private func capturedDidChange() {
        syncCaptureCover()
        captureSink?(isCaptured)
    }

    private func syncCaptureCover() {
        if isEnabled && isCaptured {
            showCaptureCover()
        } else {
            hideCaptureCover()
        }
    }

    private func showCaptureCover() {
        guard captureCover == nil else { return }
        guard let window = keyWindow(from: nil) else { return }
        let overlay = UIView(frame: window.bounds)
        overlay.backgroundColor = UIColor.black
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        let label = UILabel()
        label.text = "CONTENT HIDDEN"
        label.textColor = UIColor.white.withAlphaComponent(0.7)
        label.font = UIFont.systemFont(ofSize: 12, weight: .heavy)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
        ])
        window.addSubview(overlay)
        captureCover = overlay
    }

    private func hideCaptureCover() {
        captureCover?.removeFromSuperview()
        captureCover = nil
    }

    private func keyWindow(from scene: UIWindowScene?) -> UIWindow? {
        if let window = scene?.windows.first(where: { $0.isKeyWindow }) ?? scene?.windows.first {
            return window
        }
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}
