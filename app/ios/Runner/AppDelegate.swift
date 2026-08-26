import Flutter
import UIKit
import UserNotifications
import FirebaseMessaging
import MetricKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate,
    MXMetricManagerSubscriber {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 新しいFlutterテンプレート(scene lifecycle)ではfirebase_messagingの
    // 自動登録が効かないことがあるため、APNs登録を明示的に行う
    application.registerForRemoteNotifications()
    // アプリを開いたら通知センターに残った配信済み通知とバッジを消す。
    // scene lifecycle構成でも届く didBecomeActive 通知で拾う
    NotificationCenter.default.addObserver(
      forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
    ) { _ in
      UNUserNotificationCenter.current().removeAllDeliveredNotifications()
      UNUserNotificationCenter.current().setBadgeCount(0)
    }
    // クラッシュ記録が残らない強制終了(メモリ/ウォッチドッグ等)を捕獲する。
    // 診断は次回起動時に配送され、Documents/mx_diagnostics に保存される
    MXMetricManager.shared.add(self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  // APNsトークンをFirebase Messagingへ明示的に紐付ける
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Messaging.messaging().apnsToken = deviceToken
    super.application(application,
        didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  // MetricKit: クラッシュ・ハング・メモリ強制終了などの診断を保存する
  func didReceive(_ payloads: [MXDiagnosticPayload]) {
    let dir = FileManager.default.urls(
        for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("mx_diagnostics")
    try? FileManager.default.createDirectory(
        at: dir, withIntermediateDirectories: true)
    let fmt = ISO8601DateFormatter()
    for payload in payloads {
      let name = "diag-\(fmt.string(from: payload.timeStampEnd)).json"
      try? payload.jsonRepresentation()
          .write(to: dir.appendingPathComponent(name))
    }
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    NSLog("APNs登録失敗: \(error.localizedDescription)")
    super.application(application,
        didFailToRegisterForRemoteNotificationsWithError: error)
  }
}
