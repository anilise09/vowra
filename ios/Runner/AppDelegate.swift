import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
#if targetEnvironment(simulator)
  private var accessibilityDebugChannel: FlutterMethodChannel?
#endif

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
#if targetEnvironment(simulator)
    let channel = FlutterMethodChannel(
      name: "com.projectember.emberApp/debug-accessibility",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "isReduceMotionEnabled" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(UIAccessibility.isReduceMotionEnabled)
    }
    accessibilityDebugChannel = channel
#endif
  }
}
