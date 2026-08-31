import Foundation

/// App Group 経由でFlutter本体と共有するデータの入口。
/// Flutter側は home_widget パッケージで UserDefaults(suiteName: appGroupId) に
/// JSON文字列を書く（lib/data/widget_bridge.dart のキーと一致させること）。
enum SharedStore {
  static let appGroupId = "group.jp.livecam.livecamJp"

  /// お気に入りカメラ一覧（JSON文字列）
  static let favoritesKey = "favorites_widget_json"
  /// 災害速報ウィジェットの設定（JSON文字列。prefs=対象都道府県JISコード）
  static let bosaiSettingsKey = "bosai_widget_settings_json"

  /// ウィジェットタップで本体を開くURL。home_widget が `homeWidget` クエリを
  /// 目印にFlutter側へ渡す（lib/main.dart の _hookWidgetLinks）
  static let urlScheme = "livecamjp"

  static var defaults: UserDefaults? { UserDefaults(suiteName: appGroupId) }

  static func string(forKey key: String) -> String? {
    defaults?.string(forKey: key)
  }

  static func jsonObject(forKey key: String) -> Any? {
    guard let s = string(forKey: key), let data = s.data(using: .utf8) else { return nil }
    return try? JSONSerialization.jsonObject(with: data)
  }

  /// App Group コンテナ内のキャッシュ置き場（前回画像・前回速報の保持用）
  static func cacheURL(_ name: String) -> URL? {
    guard let base = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: appGroupId) else { return nil }
    let dir = base.appendingPathComponent("Library/Caches/LiveCamWidget", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir.appendingPathComponent(name)
  }

  static func cameraURL(id: String) -> URL? {
    var c = URLComponents()
    c.scheme = urlScheme
    c.host = "camera"
    c.path = "/" + id
    c.queryItems = [URLQueryItem(name: "homeWidget", value: nil)]
    return c.url
  }

  static var bosaiURL: URL {
    URL(string: "\(urlScheme)://bosai?homeWidget")!
  }
}

/// 表示用の時刻（JST・HH:mm）
enum TimeText {
  static let hm: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "ja_JP")
    f.timeZone = TimeZone(identifier: "Asia/Tokyo")
    f.dateFormat = "HH:mm"
    return f
  }()

  static let mdhm: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "ja_JP")
    f.timeZone = TimeZone(identifier: "Asia/Tokyo")
    f.dateFormat = "M/d HH:mm"
    return f
  }()
}
