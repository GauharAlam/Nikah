import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private static let privacyShieldChannel = "com.barkat.nikah/privacy_shield"

  /// Overlay that covers the window in screenshots and screen recordings.
  /// iOS has no FLAG_SECURE equivalent, so we use the documented
  /// `UITextField.isSecureTextEntry` canvas trick: content rendered inside a
  /// secure field's layer is excluded from screen captures.
  private var shieldField: UITextField?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: AppDelegate.privacyShieldChannel,
      binaryMessenger: engineBridge.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "enable":
        result(self?.enableShield() ?? false)
      case "disable":
        result(self?.disableShield() ?? false)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func enableShield() -> Bool {
    guard shieldField == nil, let window = window else { return false }
    let field = UITextField()
    field.isSecureTextEntry = true
    field.isUserInteractionEnabled = false
    // The secure field itself stays off-screen; only its capture-excluding
    // layer is borrowed to host the window's own content layer.
    window.addSubview(field)
    field.centerYAnchor.constraint(equalTo: window.centerYAnchor).isActive = true
    field.centerXAnchor.constraint(equalTo: window.centerXAnchor).isActive = true
    window.layer.superlayer?.addSublayer(field.layer)
    field.layer.sublayers?.last?.addSublayer(window.layer)
    shieldField = field
    return true
  }

  private func disableShield() -> Bool {
    guard let field = shieldField, let window = window else { return false }
    window.layer.superlayer?.addSublayer(window.layer)
    field.removeFromSuperview()
    shieldField = nil
    return true
  }
}
