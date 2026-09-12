import ActivityKit
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LiveActivityLink") {
      LiveActivityLink.register(messenger: registrar.messenger())
    }
  }
}

/// live_activities 플러그인·위젯 확장과 같은 이름의 속성 타입.
/// ActivityKit은 이 이름으로 활동을 찾으므로, 여기서는 id만 읽는다.
@available(iOS 16.1, *)
struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
  struct ContentState: Codable, Hashable {}
  var id: UUID
}

/// 서버가 푸시로 띄운 Live Activity의 갱신 토큰이 어느 경기 것인지 잇는다.
/// 플러그인은 토큰과 함께 시스템 활동 id만 주므로, 시스템 id → attributes.id
/// (서버가 경기 키로 만든 UUID)를 앱(lib/services/live_score_push.dart)에 알려준다.
enum LiveActivityLink {
  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "basketit/live_activity_link", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "attributeIds" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard #available(iOS 16.1, *) else {
        result([String: String]())
        return
      }
      var ids: [String: String] = [:]
      for activity in Activity<LiveActivitiesAppAttributes>.activities {
        ids[activity.id] = activity.attributes.id.uuidString.lowercased()
      }
      result(ids)
    }
  }
}
