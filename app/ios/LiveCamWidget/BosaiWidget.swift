import SwiftUI
import WidgetKit

// MARK: - データ

/// 1回の取得結果。取得失敗時に前回分を出せるよう App Group に保存する
struct BosaiSnapshot: Codable {
  var fetchedAt: Date
  var warnings: [PrefWarnings]
  var quakes: [QuakeInfo]

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
  /// 特別警報 > 震度5弱以上 > 危険警報 > 震度4 > 警報 > 発表なし
  var headline: Headline {
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
    if let cached = BosaiSnapshot.loadCached() {
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
      async let w = try? JmaClient.fetchWarnings(prefs: settings.prefs)
      async let q = try? JmaClient.fetchQuakes()
      let warnings = await w
      let quakes = await q
      let now = Date()
      let stale = warnings == nil || quakes == nil
      let snapshot: BosaiSnapshot
      if warnings == nil && quakes == nil, let cached {
        snapshot = cached  // 完全失敗: 前回分を維持
      } else {
        snapshot = BosaiSnapshot(
          fetchedAt: stale ? (cached?.fetchedAt ?? now) : now,
          warnings: warnings ?? cached?.warnings ?? [],
          quakes: quakes ?? cached?.quakes ?? [])
        if !stale { snapshot.save() }
      }
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
    .description("気象庁の特別警報・危険警報と震度4以上の地震を表示します（10分ごとに更新）")
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
        Image(systemName: headline.symbol)
        Text("災害速報")
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
        .lineLimit(3)
        .minimumScaleFactor(0.8)
      Spacer(minLength: 0)
      footer
    }
    .padding(12)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  private var medium: some View {
    let snap = entry.snapshot
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
      if snap.warnings.isEmpty && snap.quakes.isEmpty {
        Text("発表なし")
          .font(.system(size: 16, weight: .bold))
          .foregroundStyle(.white)
      } else {
        ForEach(snap.warnings.prefix(3), id: \.pref) { w in
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
        if snap.warnings.count > 3 {
          Text("ほか\(snap.warnings.count - 3)都道府県")
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
