import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    guard let controller = window?.rootViewController as? FlutterViewController,
      let splash = UIStoryboard(name: "LaunchScreen", bundle: nil)
        .instantiateInitialViewController()?.view
    else { return }

    // Flutter's default native splash fades over the first Flutter frame,
    // ghosting the logo over ready content (or over our own 180ms bridge).
    // Own a fresh storyboard view: clearing Flutter's splash animates and
    // removes its old view, so that view cannot safely be reparented.
    // Keep ours until the first rendered frame, then remove it once,
    // without adding another animation or waiting for session bootstrap.
    controller.splashScreenView = nil
    splash.frame = controller.view.bounds
    splash.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    controller.view.addSubview(splash)
    controller.setFlutterViewDidRenderCallback { [weak splash] in
      splash?.removeFromSuperview()
    }
  }
}
