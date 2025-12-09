import Flutter
import UIKit
import UserNotifications

/// NOTE: 설계도 v1.1 기준 iOS A안(APNs → 탭 → 포그라운드 → 재생)을 위한
/// PTT Push 브리지 구현. B안(PushToTalk 프레임워크)는 이 파일에서 다루지 않는다.
/// 현재 리포는 Windows + Android 환경에서만 실제 실행/테스트 되었으며,
/// 이 iOS 코드는 Mac + Xcode 환경에서 나중에 빌드/검증 및 튜닝이 필요하다.
@main
@objc class AppDelegate: FlutterAppDelegate {
  private var pttPushChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      pttPushChannel = FlutterMethodChannel(
        name: "mjtalk.ptt.push",
        binaryMessenger: controller.binaryMessenger
      )
    }

    // iOS A안: APNs → 탭 → 포그라운드 → 재생을 위해
    // UNUserNotificationCenter delegate를 FlutterAppDelegate (self)에 위임.
    UNUserNotificationCenter.current().delegate = self

    return super.application(
      application,
      didFinishLaunchingWithOptions: launchOptions
    )
  }

  /// Manual test – iOS A안 PTT Push (APNs → 탭 → 포그라운드 → 재생)
  ///
  /// 1) 앱을 종료한 상태에서 PTT APNs를 보낸다.
  ///    - payload 예시:
  ///      { "type": "ptt", "friendId": "u1", "pttMode": "walkie", "messageId": "m123" }
  /// 2) 알림을 탭하면 앱이 실행되고,
  ///    userNotificationCenter(_:didReceive:withCompletionHandler:)가 호출된다.
  /// 3) 이 메서드가 payload를 Dart 쪽 "mjtalk.ptt.push" 채널의
  ///    "handlePttPush" 메서드로 전달한다.
  /// 4) Flutter에서는 PttPushHandler가 해당 friendId의 채팅 화면으로 이동하고,
  ///    정책(FF.iosModeA_PushTapPlay)에 따라 자동 재생/표시를 결정한다.
  /// 5) 앱이 백그라운드/포그라운드 상태여도 동일하게
  ///    탭 시 payload가 Dart로 전달되는지 확인한다.

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo

    if let type = userInfo["type"] as? String, type == "ptt" {
      var payload: [String: Any] = [:]
      if let friendId = userInfo["friendId"] as? String {
        payload["friendId"] = friendId
      }
      if let mode = userInfo["pttMode"] as? String {
        payload["pttMode"] = mode
      }
      if let messageId = userInfo["messageId"] as? String {
        payload["messageId"] = messageId
      }
      payload["source"] = "notification_tap"

      pttPushChannel?.invokeMethod("handlePttPush", arguments: payload)
    }

    super.userNotificationCenter(
      center,
      didReceive: response,
      withCompletionHandler: completionHandler
    )
  }
}
