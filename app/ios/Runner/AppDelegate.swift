import Flutter
import ObjectiveC
import Speech
import UIKit

/// Explicit-engine AppDelegate (engine created here, started + plugins in SceneDelegate).
///
/// Why not the stock implicit-engine + Main.storyboard path:
/// on iOS 26 ProMotion, storyboard `FlutterViewController.viewDidLoad` races the
/// implicit engine shell and SIGSEGVs in `VSyncClient` (flutter/flutter#190030).
///
/// Why plugins are NOT registered here:
/// registering against a bare `FlutterEngine` in `didFinishLaunching` SIGSEGVs
/// inside Swift plugins (seen: `connectivity_plus` → `swift_getObjectType`) on
/// device cold starts. SceneDelegate registers against the
/// `FlutterViewController` after `init(engine:)` attaches a live shell.
@main
@objc class AppDelegate: FlutterAppDelegate {
  private(set) var flutterEngine: FlutterEngine!

  private var speechChannel: FlutterMethodChannel?
  private var widgetSecretsChannel: FlutterMethodChannel?
  private var pluginsRegistered = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Belt-and-suspenders for ProMotion devices: never deref a null
    // task runner inside Flutter's VSync helpers (touch-rate + keyboard).
    FlutterViewController.rd_installProMotionVSyncGuards()

    flutterEngine = FlutterEngine(name: "io.readendar.flutter")
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// Registers plugins + the speech channel once the engine is attached to a VC.
  func registerPlugins(with registry: FlutterPluginRegistry) {
    guard !pluginsRegistered else { return }
    pluginsRegistered = true
    GeneratedPluginRegistrant.register(with: registry)

    let messenger: FlutterBinaryMessenger
    if let controller = registry as? FlutterViewController {
      messenger = controller.binaryMessenger
    } else if let engine = registry as? FlutterEngine {
      messenger = engine.binaryMessenger
    } else {
      messenger = flutterEngine.binaryMessenger
    }

    speechChannel = FlutterMethodChannel(
      name: "readendar/speech",
      binaryMessenger: messenger
    )
    speechChannel?.setMethodCallHandler { call, result in
      guard call.method == "isOnDeviceRecognitionAvailable" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let arguments = call.arguments as? [String: Any]
      let requested = arguments?["localeId"] as? String
      let locale = requested.map(Locale.init(identifier:)) ?? Locale.current
      result(SFSpeechRecognizer(locale: locale)?.supportsOnDeviceRecognition == true)
    }

    widgetSecretsChannel = FlutterMethodChannel(
      name: "readendar/widget_secrets",
      binaryMessenger: messenger
    )
    widgetSecretsChannel?.setMethodCallHandler { call, result in
      switch call.method {
      case "write":
        let args = call.arguments as? [String: Any]
        let access = args?["access"] as? String ?? ""
        let refresh = args?["refresh"] as? String ?? ""
        result(WidgetKeychain.writeTokens(access: access, refresh: refresh))
      case "read":
        result([
          "access": WidgetKeychain.read("wdg_access") as Any? ?? NSNull(),
          "refresh": WidgetKeychain.read("wdg_refresh") as Any? ?? NSNull(),
        ])
      case "clear":
        result(WidgetKeychain.clearTokens())
      case "flushDefaults":
        UserDefaults(suiteName: "group.com.readendar.readendar")?.synchronize()
        result(true)
      case "clearShared":
        let args = call.arguments as? [String: Any]
        let keys = args?["keys"] as? [String] ?? []
        guard let defaults = UserDefaults(suiteName: "group.com.readendar.readendar") else {
          result(false)
          return
        }
        for key in keys {
          defaults.removeObject(forKey: key)
          defaults.removeObject(forKey: "flutter.\(key)")
        }
        defaults.synchronize()
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    SpotlightBridge.register(with: messenger)
  }
}

private extension FlutterViewController {
  /// No-ops Flutter VSync helpers that SIGSEGV on ProMotion when a task runner
  /// is still null (flutter/flutter#183900, #187565).
  ///
  /// Touch-rate correction runs in `viewDidLoad`. Keyboard animation VSync runs
  /// when the IME hides, which is exactly Apple's review path: email → code →
  /// Continuar on an iPad Air (M3). Skipping both only drops 120 Hz touch
  /// sampling and IME-synced inset interpolation. Layout still settles on the
  /// animation completion callback.
  static func rd_installProMotionVSyncGuards() {
    rd_noopInstanceMethod("createTouchRateCorrectionVSyncClientIfNeeded")
    rd_noopInstanceMethod("setUpKeyboardAnimationVsyncClient:")
  }

  static func rd_noopInstanceMethod(_ name: String) {
    let sel = NSSelectorFromString(name)
    guard let method = class_getInstanceMethod(FlutterViewController.self, sel) else {
      return
    }
    let block: @convention(block) (AnyObject) -> Void = { _ in }
    method_setImplementation(method, imp_implementationWithBlock(block))
  }
}
