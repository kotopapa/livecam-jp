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
  /// 利用者の最後の位置（JSON文字列。lat/lng/pref/at）。本体が許可済みの最後の
  /// 既知位置を書く。ウィジェット自身は位置情報を取らない（2026-11-04 方式B）
  static let viewerLocationKey = "viewer_location_json"

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

  static func loadViewerLocation(now: Date = Date()) -> ViewerLocation? {
    guard let obj = jsonObject(forKey: viewerLocationKey) as? [String: Any],
          let lat = obj["lat"] as? Double, let lng = obj["lng"] as? Double else { return nil }
    let loc = ViewerLocation(lat: lat, lng: lng, pref: obj["pref"] as? String,
                             at: (obj["at"] as? String).flatMap { JmaClient.iso.date(from: $0) })
    return loc.isUsable(now: now) ? loc : nil
  }
}

/// 利用者の最後の位置（本体アプリが書く）。
/// 「現在地を先頭に」の並べ替えに使う。pref は JIS 2桁（海上・国外・未解決は nil）
struct ViewerLocation: Codable, Hashable {
  let lat: Double
  let lng: Double
  let pref: String?
  let at: Date?

  /// 古すぎる位置は使わない（本体を長く開いていない）
  static let maxAge: TimeInterval = 7 * 24 * 3600

  func isUsable(now: Date = Date()) -> Bool {
    guard let at else { return true }
    return now.timeIntervalSince(at) <= Self.maxAge
  }

  /// 2点間の距離（m、ハーバサイン）
  func distanceMeters(toLat lat2: Double, lng lng2: Double) -> Double {
    let r = 6371000.0
    func rad(_ d: Double) -> Double { d * .pi / 180 }
    let dLat = rad(lat2 - lat), dLng = rad(lng2 - lng)
    let a = sin(dLat / 2) * sin(dLat / 2) + cos(rad(lat)) * cos(rad(lat2)) * sin(dLng / 2) * sin(dLng / 2)
    return r * 2 * atan2(sqrt(a), sqrt(1 - a))
  }

  var prefName: String? { pref.flatMap { JmaClient.prefectureNames[$0] } }
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
