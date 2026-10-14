import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Firebase Analytics DebugView for every debug build. `flutter run`
    // launches through simctl/devicectl, which drops Xcode's
    // `-FIRDebugEnabled` launch argument, so the flags are set directly.
    // Debug-mode events show in DebugView and stay out of the reports.
    #if DEBUG
    UserDefaults.standard.set(true, forKey: "/google/firebase/debug_mode")
    UserDefaults.standard.set(true, forKey: "/google/measurement/debug_mode")
    #endif
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
