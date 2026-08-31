import Foundation

/// 気象庁の公開JSON（無料・認証不要。SPEC C2）から警報と地震を取得する。
/// 解釈ロジックは Flutter 本体 lib/ui/bosai_screen.dart と揃える:
/// - r8/map.json は官署×報種別(dataTypeCode)ごとに最新報を採って合算する
///   （官署単位に絞ると土砂災害報(VPWW56)が落ちる）
/// - quake/list.json は同一地震(eid)が複数報並ぶ。震源名・Mが埋まった報を優先
enum JmaClient {
  static let warningMapURL = "https://www.jma.go.jp/bosai/warning/data/r8/map.json"
  static let quakeListURL = "https://www.jma.go.jp/bosai/quake/data/list.json"

  /// 警報コード → 表示名（bosai_screen.dart の _warningNames と同一）
  static let warningNames: [String: String] = [
    "02": "暴風雪警報", "03": "大雨警報", "04": "洪水警報", "05": "暴風警報",
    "06": "大雪警報", "07": "波浪警報", "08": "高潮警報", "09": "土砂災害警報",
    // 2026-05-28新体系の「危険警報」(警戒レベル4相当。コード=警報+40)
    "43": "大雨危険警報", "44": "洪水危険警報", "48": "高潮危険警報",
    "49": "土砂災害危険警報",
    "32": "暴風雪特別警報", "33": "大雨特別警報", "34": "洪水特別警報",
    "35": "暴風特別警報", "36": "大雪特別警報", "37": "波浪特別警報",
    "38": "高潮特別警報", "39": "土砂災害特別警報",
  ]

  /// JIS都道府県コード → 表示名
  static let prefectureNames: [String: String] = [
    "01": "北海道", "02": "青森県", "03": "岩手県", "04": "宮城県", "05": "秋田県",
    "06": "山形県", "07": "福島県", "08": "茨城県", "09": "栃木県", "10": "群馬県",
    "11": "埼玉県", "12": "千葉県", "13": "東京都", "14": "神奈川県", "15": "新潟県",
    "16": "富山県", "17": "石川県", "18": "福井県", "19": "山梨県", "20": "長野県",
    "21": "岐阜県", "22": "静岡県", "23": "愛知県", "24": "三重県", "25": "滋賀県",
    "26": "京都府", "27": "大阪府", "28": "兵庫県", "29": "奈良県", "30": "和歌山県",
    "31": "鳥取県", "32": "島根県", "33": "岡山県", "34": "広島県", "35": "山口県",
    "36": "徳島県", "37": "香川県", "38": "愛媛県", "39": "高知県", "40": "福岡県",
    "41": "佐賀県", "42": "長崎県", "43": "熊本県", "44": "大分県", "45": "宮崎県",
    "46": "鹿児島県", "47": "沖縄県",
  ]

  /// 並び順ランク（特別=0 → 危険=1 → 警報=2）。bosai_screen.dart の warningLevelRank
  static func warningLevelRank(_ name: String) -> Int {
    if name.contains("特別") { return 0 }
    if name.contains("危険警報") { return 1 }
    return 2
  }

  /// 震度文字列 → 大小比較用ランク
  static func intensityRank(_ maxi: String) -> Int {
    switch maxi {
    case "7": return 9
    case "6+": return 8
    case "6-": return 7
    case "5+": return 6
    case "5-": return 5
    default: return Int(maxi) ?? 0
    }
  }

  static func intensityLabel(_ maxi: String) -> String {
    switch maxi {
    case "5-": return "震度5弱"
    case "5+": return "震度5強"
    case "6-": return "震度6弱"
    case "6+": return "震度6強"
    default: return "震度\(maxi)"
    }
  }

  static let session: URLSession = {
    let cfg = URLSessionConfiguration.ephemeral
    cfg.timeoutIntervalForRequest = 15
    cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
    return URLSession(configuration: cfg)
  }()

  private static func fetchJSONArray(_ base: String) async throws -> [[String: Any]] {
    let ts = Int(Date().timeIntervalSince1970 * 1000)
    guard let url = URL(string: "\(base)?_=\(ts)") else { throw URLError(.badURL) }
    var req = URLRequest(url: url)
    req.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
    let (data, resp) = try await session.data(for: req)
    if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
      throw URLError(.badServerResponse)
    }
    guard let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
      throw URLError(.cannotParseResponse)
    }
    return arr
  }

  // MARK: 警報

  /// 都道府県ごとの発表中の警報（特別/危険/警報のみ。注意報は含めない）。
  /// [prefs] が空でなければその都道府県だけに絞る
  static func fetchWarnings(prefs: Set<String>) async throws -> [PrefWarnings] {
    let reports = try await fetchJSONArray(warningMapURL)
    return parseWarnings(reports: reports, prefs: prefs)
  }

  static func parseWarnings(reports: [[String: Any]], prefs: Set<String>) -> [PrefWarnings] {
    var latestByProduct: [String: [String: Any]] = [:]
    for rep in reports {
      let office = rep["publishingOffice"] as? String ?? ""
      let type = rep["dataTypeCode"] as? String ?? ""
      let dt = rep["reportDatetime"] as? String ?? ""
      let key = "\(office)/\(type)"
      if let cur = latestByProduct[key],
         let cdt = cur["reportDatetime"] as? String, cdt >= dt {
        continue
      }
      latestByProduct[key] = rep
    }
    var byPref: [String: Set<String>] = [:]
    for rep in latestByProduct.values {
      let warning = rep["warning"] as? [String: Any] ?? [:]
      for area in warning["class10Items"] as? [[String: Any]] ?? [] {
        let code = area["areaCode"] as? String ?? ""
        guard code.count >= 6 else { continue }
        let pref = String(code.prefix(2))
        guard prefectureNames[pref] != nil else { continue }
        if !prefs.isEmpty && !prefs.contains(pref) { continue }
        for w in area["kinds"] as? [[String: Any]] ?? [] {
          let status = w["status"] as? String ?? ""
          if status == "解除" || status.contains("なし") { continue }
          guard let name = warningNames[w["code"] as? String ?? ""] else { continue }
          byPref[pref, default: []].insert(name)
        }
      }
    }
    let result = byPref.map { (pref, names) -> PrefWarnings in
      let sorted = names.sorted {
        let ra = warningLevelRank($0), rb = warningLevelRank($1)
        return ra != rb ? ra < rb : $0 < $1
      }
      return PrefWarnings(pref: pref, prefName: prefectureNames[pref] ?? pref, names: sorted)
    }
    // 最上位の警報が重い都道府県順 → コード順
    return result.sorted {
      let ra = $0.rank, rb = $1.rank
      return ra != rb ? ra < rb : $0.pref < $1.pref
    }
  }

  // MARK: 地震

  /// 直近 [hours] 時間の震度 [minRank] 以上の地震（新しい順、eidで重複排除）
  static func fetchQuakes(hours: Double = 24, minRank: Int = 4) async throws -> [QuakeInfo] {
    let entries = try await fetchJSONArray(quakeListURL)
    return parseQuakes(entries: entries, since: Date().addingTimeInterval(-hours * 3600),
                       minRank: minRank)
  }

  static let iso: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
  }()

  static func parseQuakes(entries: [[String: Any]], since: Date, minRank: Int) -> [QuakeInfo] {
    // eid ごとに集約: 最大震度は最大値、震源名・Mは埋まっている報を優先
    var byEid: [String: QuakeInfo] = [:]
    var order: [String] = []
    for e in entries {
      let maxi = e["maxi"] as? String ?? ""
      let eid = e["eid"] as? String ?? ""
      guard !maxi.isEmpty, !eid.isEmpty,
            let at = iso.date(from: e["at"] as? String ?? "") else { continue }
      if at < since { continue }
      let anm = e["anm"] as? String ?? ""
      let mag = e["mag"] as? String ?? ""
      if var cur = byEid[eid] {
        if intensityRank(maxi) > intensityRank(cur.maxIntensity) { cur.maxIntensity = maxi }
        if cur.place.isEmpty && !anm.isEmpty { cur.place = anm }
        if cur.magnitude.isEmpty && !mag.isEmpty { cur.magnitude = mag }
        if at > cur.at { cur.at = at }
        byEid[eid] = cur
      } else {
        byEid[eid] = QuakeInfo(eid: eid, place: anm, magnitude: mag, maxIntensity: maxi, at: at)
        order.append(eid)
      }
    }
    return order.compactMap { byEid[$0] }
      .filter { intensityRank($0.maxIntensity) >= minRank }
      .sorted { $0.at > $1.at }
  }
}

struct PrefWarnings: Codable, Hashable {
  let pref: String
  let prefName: String
  /// 特別→危険→警報の順
  let names: [String]

  var rank: Int { names.map(JmaClient.warningLevelRank).min() ?? 3 }
  var top: String { names.first ?? "" }
}

struct QuakeInfo: Codable, Hashable {
  let eid: String
  var place: String
  var magnitude: String
  var maxIntensity: String
  var at: Date

  var placeOrUnknown: String { place.isEmpty ? "震源調査中" : place }
}
