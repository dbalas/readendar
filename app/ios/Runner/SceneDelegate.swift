import Flutter
import UIKit

/// Programmatic scene setup with an explicit engine + VC-scoped plugin registration.
///
/// Do not subclass `FlutterSceneDelegate` / load Main.storyboard: that reintroduces
/// the iOS 26 ProMotion VSync SIGSEGV. Do not register plugins on a bare
/// `FlutterEngine` in `didFinishLaunching`: that SIGSEGVs Swift plugins on device
/// cold start. `FlutterViewController(engine:)` attaches/runs the shell first;
/// plugins then register against the VC.
class SceneDelegate: UIResponder, UIWindowSceneDelegate, FlutterSceneLifeCycleProvider {
  var window: UIWindow?

  private let _sceneLifeCycleDelegate = FlutterPluginSceneLifeCycleDelegate()
  var sceneLifeCycleDelegate: FlutterPluginSceneLifeCycleDelegate {
    _sceneLifeCycleDelegate
  }

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene else { return }
    // iPad can reconnect the same session (Stage Manager, keyboard, rotation).
    // A second FlutterViewController on the shared engine SIGSEGVs.
    if window != nil {
      sceneLifeCycleDelegate.scene(
        scene,
        willConnectTo: session,
        options: connectionOptions
      )
      return
    }
    guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
    guard let engine = appDelegate.flutterEngine else { return }

    // Run the isolate before attaching the VC so platformTaskRunner is live
    // when ProMotion touch-rate VSync runs in viewDidLoad.
    if engine.viewController == nil {
      engine.run()
    }
    let flutterViewController = FlutterViewController(
      engine: engine,
      nibName: nil,
      bundle: nil
    )
    appDelegate.registerPlugins(with: flutterViewController)

    let window = UIWindow(windowScene: windowScene)
    window.rootViewController = flutterViewController
    window.makeKeyAndVisible()
    self.window = window

    sceneLifeCycleDelegate.scene(
      scene,
      willConnectTo: session,
      options: connectionOptions
    )
  }

  func sceneDidDisconnect(_ scene: UIScene) {
    sceneLifeCycleDelegate.sceneDidDisconnect(scene)
  }

  func sceneDidBecomeActive(_ scene: UIScene) {
    sceneLifeCycleDelegate.sceneDidBecomeActive(scene)
  }

  func sceneWillResignActive(_ scene: UIScene) {
    sceneLifeCycleDelegate.sceneWillResignActive(scene)
  }

  func sceneWillEnterForeground(_ scene: UIScene) {
    sceneLifeCycleDelegate.sceneWillEnterForeground(scene)
  }

  func sceneDidEnterBackground(_ scene: UIScene) {
    sceneLifeCycleDelegate.sceneDidEnterBackground(scene)
  }

  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    sceneLifeCycleDelegate.scene(scene, openURLContexts: URLContexts)
  }

  func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    sceneLifeCycleDelegate.scene(scene, continue: userActivity)
  }

  func windowScene(
    _ windowScene: UIWindowScene,
    performActionFor shortcutItem: UIApplicationShortcutItem,
    completionHandler: @escaping (Bool) -> Void
  ) {
    sceneLifeCycleDelegate.windowScene(
      windowScene,
      performActionFor: shortcutItem,
      completionHandler: completionHandler
    )
  }
}
