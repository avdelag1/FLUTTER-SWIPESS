import UIKit

/// Cap `@capacitor-community/privacy-screen`. iOS cannot block a screenshot, so
/// the plugin does what every banking app does instead: while a protected
/// surface is open (VAP ID card, document vault) it covers the window the moment
/// the app stops being frontmost, which is exactly when iOS grabs the snapshot
/// for the task switcher.
///
/// The app is scene based (`UIApplicationSceneManifest` in Info.plist), so this
/// listens to the `UIScene` notifications; UIKit does not deliver the
/// `UIApplication` lifecycle notifications to scene-based apps.
final class PrivacyScreen {
    static let shared = PrivacyScreen()

    private var isEnabled = false
    private var cover: UIView?

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
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if !enabled {
            hideCover()
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
