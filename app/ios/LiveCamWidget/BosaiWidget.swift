import SwiftUI
import WidgetKit

// MARK: - データ

/// 1回の取得結果。取得失敗時に前回分を出せるよう App Group に保存する
struct BosaiSnapshot: Codable {
  var fetchedAt: Date
  var warnings: [PrefWarnings]
  var quakes: [QuakeInfo]
  /// 利用者がいま居る都道府県（JIS 2桁。本体が書いた最後の位置から。不明なら nil）。
  /// この県の行を先頭に出す（2026-11-04 ユーザー要望）
  var viewerPref: String? = nil

  var viewerPrefName: String? { viewerPref.flatMap { JmaClient.prefectureNames[$0] } }

  /// 現在地の県に発表中の警報（無ければ nil）
  var viewerWarnings: PrefWarnings? {
    guard let p = viewerPref else { return nil }
    return warnings.first { $0.pref == p }
  }

  /// 表示順: 現在地の県 → 残りは重い順（元の順）
  var orderedWarnings: [PrefWarnings] {
    guard let v = viewerWarnings else { return warnings }
    return [v] + warnings.filter { $0.pref != v.pref }
  }

  static let cacheFile = "bosai-snapshot.json"

  static func loadCached() -> BosaiSnapshot? {
    guard let url = SharedStore.cacheURL(cacheFile),
          let data = try? Data(contentsOf: url) else { return nil }
    return try? JSONDecoder().decode(BosaiSnapshot.self, from: data)
  }

  func save() {
    guard let url = SharedStore.cacheURL(Self.cacheFile),
          let data = try? JSONEncoder().encode(self) else { return }
    try? data.write(to: url, options: .atomic)
  }

  /// 見出し（small / ロック画面用の1行）。
  /// 現在地の県に警報があればそれを最優先。無ければ
  /// 特別警報 > 震度5弱以上 > 危険警報 > 震度4 > 警報 > 発表なし
  var headline: Headline {
    if let v = viewerWarnings {
      return Headline(text: "\(v.top) \(v.prefName)",
                      level: v.rank == 0 ? .special : (v.rank == 1 ? .danger : .warning),
                      isViewer: true)
    }
    let topWarning = warnings.first
    let topQuake = quakes.max { JmaClient.intensityRank($0.maxIntensity) < JmaClient.intensityRank($1.maxIntensity) }
    func warningHeadline(_ w: PrefWarnings) -> Headline {
      Headline(text: "\(w.top) \(w.prefName)", level: w.rank == 0 ? .special : (w.rank == 1 ? .danger : .warning))
    }
    func quakeHeadline(_ q: QuakeInfo) -> Headline {
      Headline(text: "\(JmaClient.intensityLabel(q.maxIntensity)) \(q.placeOrUnknown) \(TimeText.hm.string(from: q.at))",
               level: JmaClient.intensityRank(q.maxIntensity) >= 5 ? .special : .danger)
    }
    if let w = topWarning, w.rank == 0 { return warningHeadline(w) }
    if let q = topQuake, JmaClient.intensityRank(q.maxIntensity) >= 5 { return quakeHeadline(q) }
    if let w = topWarning, w.rank == 1 { return warningHeadline(w) }
    if let q = topQuake { return quakeHeadline(q) }
    if let w = topWarning { return warningHeadline(w) }
    return Headline(text: "発表なし", level: .none)
  }

  struct Headline {
    enum Level { case special, danger, warning, none }
    let text: String
    let level: Level
    /// 現在地の県の警報
    var isViewer: Bool = false

    var color: Color {
      switch level {
      case .special: return Color(red: 0.85, green: 0.19, blue: 0.15)
      case .danger: return Color(red: 0.58, green: 0.20, blue: 0.90)
      case .warning: return Color(red: 0.95, green: 0.60, blue: 0.0)
      case .none: return Color(white: 0.55)
      }
    }

    var symbol: String {
      switch level {
      case .special, .danger: return "exclamationmark.triangle.fill"
      case .warning: return "exclamationmark.circle.fill"
      case .none: return "checkmark.circle"
      }
    }
  }

  /// 現在地の県の1行（medium の先頭行・small の補足）。現在地が不明なら nil
  var viewerLine: String? {
    guard let name = viewerPrefName else { return nil }
    if let v = viewerWarnings { return "\(name)  \(v.names.joined(separator: "・"))" }
    return "\(name)  発表なし"
  }
}

struct BosaiSettings {
  /// 対象都道府県JISコード。空=全国（Flutter側 notify_warning_prefs と同じ意味）
  let prefs: Set<String>

  static func load() -> BosaiSettings {
    guard let obj = SharedStore.jsonObject(forKey: SharedStore.bosaiSettingsKey) as? [String: Any],
          let list = obj["prefs"] as? [String] else { return BosaiSettings(prefs: []) }
    return BosaiSettings(prefs: Set(list))
  }
}

// MARK: - Timeline

struct BosaiEntry: TimelineEntry {
  let date: Date
  let snapshot: BosaiSnapshot
  /// 取得に失敗し前回分を表示している
  let stale: Bool
  let prefsCount: Int

  static var placeholder: BosaiEntry {
    BosaiEntry(
      date: Date(),
      snapshot: BosaiSnapshot(
        fetchedAt: Date(),
        warnings: [PrefWarnings(pref: "16", prefName: "富山県", names: ["大雨特別警報", "土砂災害危険警報"])],
        quakes: []),
      stale: false, prefsCount: 0)
  }
}

struct BosaiProvider: TimelineProvider {
  /// 10分ごとに再取得
  static let refreshInterval: TimeInterval = 10 * 60

  func placeholder(in context: Context) -> BosaiEntry { .placeholder }

  func getSnapshot(in context: Context, completion: @escaping (BosaiEntry) -> Void) {
    if context.isPreview {
      completion(.placeholder)
      return
    }
    if var cached = BosaiSnapshot.loadCached() {
      cached.viewerPref = SharedStore.loadViewerLocation()?.pref
      completion(BosaiEntry(date: Date(), snapshot: cached, stale: false,
                            prefsCount: BosaiSettings.load().prefs.count))
    } else {
      completion(BosaiEntry(date: Date(), snapshot: BosaiSnapshot(fetchedAt: Date(), warnings: [], quakes: []),
                            stale: false, prefsCount: 0))
    }
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<BosaiEntry>) -> Void) {
    Task {
      let settings = BosaiSettings.load()
      let cached = BosaiSnapshot.loadCached()
      let viewerPref = SharedStore.loadViewerLocation()?.pref
      // 対象県を絞っていても、いま居る県は必ず含める
      let prefs: Set<String> = {
        guard !settings.prefs.isEmpty, let v = viewerPref else { return settings.prefs }
        return settings.prefs.union([v])
      }()
      async let w = try? JmaClient.fetchWarnings(prefs: prefs)
      async let q = try? JmaClient.fetchQuakes()
      let warnings = await w
      let quakes = await q
      let now = Date()
      let stale = warnings == nil || quakes == nil
      var snapshot: BosaiSnapshot
      if warnings == nil && quakes == nil, let cached {
        snapshot = cached  // 完全失敗: 前回分を維持
      } else {
        snapshot = BosaiSnapshot(
          fetchedAt: stale ? (cached?.fetchedAt ?? now) : now,
          warnings: warnings ?? cached?.warnings ?? [],
          quakes: quakes ?? cached?.quakes ?? [])
        if !stale { snapshot.save() }
      }
      snapshot.viewerPref = viewerPref
      let entry = BosaiEntry(date: now, snapshot: snapshot, stale: stale,
                             prefsCount: settings.prefs.count)
      completion(Timeline(entries: [entry],
                          policy: .after(now.addingTimeInterval(Self.refreshInterval))))
    }
  }
}

// MARK: - Widget

struct BosaiWidget: Widget {
  static let kind = "BosaiWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: Self.kind, provider: BosaiProvider()) { entry in
      BosaiView(entry: entry)
        .containerBackground(for: .widget) { Color("WidgetBackground") }
        .widgetURL(SharedStore.bosaiURL)
    }
    .configurationDisplayName("災害速報")
    .description("気象庁の特別警報・危険警報と震度4以上の地震を、いま居る都道府県を先頭に表示します（10分ごとに更新）")
    .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
  }
}

struct BosaiView: View {
  @Environment(\.widgetFamily) private var family
  let entry: BosaiEntry

  private var headline: BosaiSnapshot.Headline { entry.snapshot.headline }

  private var updatedText: String {
    let t = TimeText.hm.string(from: entry.snapshot.fetchedAt)
    return entry.stale ? "更新 \(t)（取得失敗）" : "更新 \(t)"
  }

  var body: some View {
    switch family {
    case .accessoryRectangular:
      accessory
    case .systemMedium:
      medium
    default:
      small
    }
  }

  // ロック画面: 1〜2行
  private var accessory: some View {
    VStack(alignment: .leading, spacing: 1) {
      HStack(spacing: 4) {
        Image(systemName: headline.isViewer ? "location.fill" : headline.symbol)
        Text(headline.isViewer ? "災害速報（現在地）" : "災害速報")
      }
      .font(.system(size: 12, weight: .semibold))
      Text(headline.text)
        .font(.system(size: 13, weight: .bold))
        .lineLimit(1)
      Text("\(TimeText.hm.string(from: entry.snapshot.fetchedAt)) 気象庁")
        .font(.system(size: 10))
        .opacity(0.8)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var small: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 4) {
        Image(systemName: headline.symbol)
          .foregroundStyle(headline.color)
        Text("災害速報")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(.white.opacity(0.85))
        Spacer()
      }
      Text(headline.text)
        .font(.system(size: 16, weight: .bold))
        .foregroundStyle(.white)
        .lineLimit(headline.isViewer || viewerLineForSmall == nil ? 3 : 2)
        .minimumScaleFactor(0.8)
      if headline.isViewer {
        Text("現在地")
          .font(.system(size: 10))
          .foregroundStyle(.white.opacity(0.7))
      } else if let line = viewerLineForSmall {
        // 現在地の県には発表が無い: 見出しは全国の最上位、補足に現在地
        HStack(spacing: 3) {
          Image(systemName: "location.fill")
            .font(.system(size: 8))
          Text(line)
        }
        .font(.system(size: 10))
        .foregroundStyle(.white.opacity(0.7))
        .lineLimit(1)
      }
      Spacer(minLength: 0)
      footer
    }
    .padding(12)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  /// small の補足行（現在地の県に発表が無いとき）。例「東京都 発表なし」
  private var viewerLineForSmall: String? {
    guard let name = entry.snapshot.viewerPrefName, entry.snapshot.viewerWarnings == nil else { return nil }
    return "\(name) 発表なし"
  }

  private var medium: some View {
    let snap = entry.snapshot
    // 先頭に現在地の県、続いて残り（重い順）。現在地が不明なら従来どおり
    let others = snap.orderedWarnings.filter { $0.pref != snap.viewerPref }
    let otherRows = snap.viewerPref == nil ? 3 : 2
    return VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 4) {
        Image(systemName: headline.symbol)
          .foregroundStyle(headline.color)
        Text("災害速報")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(.white.opacity(0.85))
        if entry.prefsCount > 0 {
          Text("（対象\(entry.prefsCount)都道府県）")
            .font(.system(size: 10))
            .foregroundStyle(.white.opacity(0.6))
        }
        Spacer()
      }
      if let line = snap.viewerLine {
        let v = snap.viewerWarnings
        HStack(alignment: .top, spacing: 6) {
          Image(systemName: "location.fill")
            .font(.system(size: 9))
            .foregroundStyle(v.map { levelColor($0.rank) } ?? Color(white: 0.65))
            .padding(.top, 3)
          Text(line)
            .font(.system(size: 12, weight: v == nil ? .regular : .bold))
            .foregroundStyle(v == nil ? .white.opacity(0.8) : .white)
            .lineLimit(1)
        }
      }
      if others.isEmpty && snap.quakes.isEmpty {
        if snap.viewerPref == nil {
          Text("発表なし")
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.white)
        } else {
          Text("ほかの都道府県も発表なし")
            .font(.system(size: 11))
            .foregroundStyle(.white.opacity(0.7))
        }
      } else {
        ForEach(others.prefix(otherRows), id: \.pref) { w in
          HStack(alignment: .top, spacing: 6) {
            Circle()
              .fill(levelColor(w.rank))
              .frame(width: 8, height: 8)
              .padding(.top, 4)
            Text("\(w.prefName)  \(w.names.joined(separator: "・"))")
              .font(.system(size: 12, weight: w.rank == 0 ? .bold : .regular))
              .foregroundStyle(.white)
              .lineLimit(1)
          }
        }
        if others.count > otherRows {
          Text("ほか\(others.count - otherRows)都道府県")
            .font(.system(size: 10))
            .foregroundStyle(.white.opacity(0.7))
        }
        if let q = snap.quakes.first {
          HStack(spacing: 6) {
            Image(systemName: "waveform.path.ecg")
              .foregroundStyle(JmaClient.intensityRank(q.maxIntensity) >= 5
                               ? BosaiSnapshot.Headline.Level.special.colorValue
                               : BosaiSnapshot.Headline.Level.danger.colorValue)
            Text("\(JmaClient.intensityLabel(q.maxIntensity)) \(q.placeOrUnknown) M\(q.magnitude.isEmpty ? "-" : q.magnitude) \(TimeText.mdhm.string(from: q.at))")
              .font(.system(size: 12))
              .foregroundStyle(.white)
              .lineLimit(1)
          }
          .padding(.top, 2)
        }
      }
      Spacer(minLength: 0)
      footer
    }
    .padding(12)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  private var footer: some View {
    HStack {
      Text(updatedText)
      Spacer()
      Text("出典: 気象庁")
    }
    .font(.system(size: 9))
    .foregroundStyle(.white.opacity(0.6))
  }

  private func levelColor(_ rank: Int) -> Color {
    switch rank {
    case 0: return BosaiSnapshot.Headline.Level.special.colorValue
    case 1: return BosaiSnapshot.Headline.Level.danger.colorValue
    default: return BosaiSnapshot.Headline.Level.warning.colorValue
    }
  }
}

extension BosaiSnapshot.Headline.Level {
  var colorValue: Color { BosaiSnapshot.Headline(text: "", level: self).color }
}
