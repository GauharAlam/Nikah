import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private static let privacyShieldChannel = "com.barkat.nikah/privacy_shield"

  /// Hosts the window's layer inside a secure text field's layer, which iOS
  /// leaves out of screenshots and recordings. iOS has no FLAG_SECURE.
  private var shieldField: UITextField?
  private var shieldRequested = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // PrivacyShield.enable() runs in main(), usually before a window exists.
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(applyShield),
      name: UIWindow.didBecomeKeyNotification,
      object: nil
    )
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: AppDelegate.privacyShieldChannel,
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "enable":
        self?.shieldRequested = true
        self?.applyShield()
        result(true)
      case "disable":
        self?.shieldRequested = false
        self?.applyShield()
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// The app uses a SceneDelegate, so the key window lives on the scene.
  private var keyWindow: UIWindow? {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }
  }

  @objc private func applyShield() {
    if let field = shieldField {
      field.isSecureTextEntry = shieldRequested
      return
    }
    guard shieldRequested, let window = keyWindow else { return }
    let field = UITextField()
    field.isSecureTextEntry = true
    field.isUserInteractionEnabled = false
    window.addSubview(field)
    window.layer.superlayer?.addSublayer(field.layer)
    field.layer.sublayers?.last?.addSublayer(window.layer)
    shieldField = field
  }
}
