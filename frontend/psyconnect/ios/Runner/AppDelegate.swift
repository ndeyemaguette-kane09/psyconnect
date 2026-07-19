import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // On crée l'engine Flutter explicitement pour contrôler l'ordre d'init :
    //   1. engine.run()  — démarre Dart
    //   2. GeneratedPluginRegistrant.register() — enregistre les plugins
    //      (Jitsi force-unwrap rootViewController à cette étape)
    //   3. FlutterViewController(engine:) + window setup — la fenêtre existe
    //      AVANT que Jitsi n'y accède → plus de nil-crash
    //
    // On NE fait PAS appel à super pour éviter qu'il crée un deuxième engine
    // (double-init → double mémoire → crash mémoire sur les autres écrans).
    let engine = FlutterEngine(name: "main")
    engine.run()

    let controller = FlutterViewController(engine: engine, nibName: nil, bundle: nil)
    self.window = UIWindow(frame: UIScreen.main.bounds)
    self.window?.rootViewController = controller
    self.window?.makeKeyAndVisible()

    // Jitsi peut maintenant accéder à rootViewController sans planter
    GeneratedPluginRegistrant.register(with: engine)

    return true
  }
}
