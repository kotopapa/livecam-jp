import Flutter
import UIKit
import UserNotifications
import FirebaseMessaging
import GoogleMaps
import MetricKit
import Network

/// 端末の「低データモード」（NWPath.isConstrained）を監視する。
/// 通信節約モードの自動判定用（Dart 側の isLowDataMode）。起動直後は最初の更新が
/// 届くまで false を返す（Dart 側は復帰時・回線変化時に取り直す）
final class LowDataMonitor {
  static let shared = LowDataMonitor()
  private let monitor = NWPathMonitor()
  private let lock = NSLock()
  private var constrained = false

  var isConstrained: Bool {
    lock.lock(); defer { lock.unlock() }
    return constrained
  }

  private init() {
    constrained = monitor.currentPath.isConstrained
    monitor.pathUpdateHandler = { [weak self] path in
      guard let self = self else { return }
      self.lock.lock()
      self.constrained = path.isConstrained
      self.lock.unlock()
    }
    monitor.start(queue: DispatchQueue(label: "livecam.lowdata"))
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate,
    MXMetricManagerSubscriber {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Google Maps SDK。キーは Info.plist の GMSApiKey (Secrets.xcconfig 由来)。
    // 未設定（キー控えが無い開発環境）でもビルドが落ちないようログのみ出す
    if let mapsKey = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String,
        !mapsKey.isEmpty {
      GMSServices.provideAPIKey(mapsKey)
    } else {
      NSLog("GMSApiKey が未設定のため Google Maps を初期化しません")
    }
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
    // ルート検索(Google Routes API)・地名検索(Google Places API (New))用:
    // 新しいAPIキーは発行せず、地図表示に使っているGoogle Mapsキー(GMSApiKey)を
    // Dart側へ渡す。キーはバンドルIDで制限されているため、REST呼び出し用に
    // バンドルIDもヘッダー用に返す（lib/data/native_config.dart）
    _ = LowDataMonitor.shared  // 起動時から低データモードの監視を始める
    let configChannel = FlutterMethodChannel(
      name: "livecam/native_config",
      binaryMessenger: engineBridge.applicationRegistrar.messenger())
    configChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "getGoogleMapsApiKey":
        result(Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String ?? "")
      case "getAppRestrictionHeaders":
        result(["X-Ios-Bundle-Identifier": Bundle.main.bundleIdentifier ?? ""])
      case "isLowDataMode":
        result(LowDataMonitor.shared.isConstrained)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
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
