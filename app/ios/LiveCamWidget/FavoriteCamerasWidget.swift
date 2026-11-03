import SwiftUI
import WidgetKit

// MARK: - 共有データ（Flutter側 widget_bridge.dart が書くJSON）

struct WidgetCamera: Decodable, Hashable {
  let id: String
  let name: String
  let imageUrl: String?
  let category: String?
  let prefecture: String?
  let operatorName: String?
  let updatedAt: String?
  let headers: [String: String]?
  let lat: Double?
  let lng: Double?

  enum CodingKeys: String, CodingKey {
    case id, name, category, prefecture, headers, lat, lng
    case imageUrl = "image_url"
    case operatorName = "operator"
    case updatedAt = "updated_at"
  }
}

struct FavoritesPayload: Decodable {
  let generatedAt: String?
  let cameras: [WidgetCamera]

  enum CodingKeys: String, CodingKey {
    case cameras
    case generatedAt = "generated_at"
  }

  static func load() -> FavoritesPayload? {
    guard let s = SharedStore.string(forKey: SharedStore.favoritesKey),
          let data = s.data(using: .utf8) else { return nil }
    return try? JSONDecoder().decode(FavoritesPayload.self, from: data)
  }

  /// 表示順。現在地が分かれば近い順（座標の無いカメラは元の順で末尾）、
  /// 分からなければ本体のお気に入り順のまま。距離（m）を添える
  func ordered(by viewer: ViewerLocation?) -> [(camera: WidgetCamera, distance: Double?)] {
    guard let viewer else { return cameras.map { ($0, nil) } }
    var near: [(WidgetCamera, Double)] = []
    var rest: [WidgetCamera] = []
    for c in cameras {
      if let lat = c.lat, let lng = c.lng {
        near.append((c, viewer.distanceMeters(toLat: lat, lng: lng)))
      } else {
        rest.append(c)
      }
    }
    near.sort { $0.1 < $1.1 }
    return near.map { ($0.0, $0.1) } + rest.map { ($0, nil) }
  }
}

// MARK: - Timeline

struct FavoriteItem {
  let camera: WidgetCamera
  let image: UIImage?
  /// 現在地からの距離（m）。現在地が分からないか座標が無ければ nil
  var distance: Double? = nil

  var distanceText: String? {
    guard let d = distance else { return nil }
    if d < 950 { return "\(Int((d / 100).rounded()) * 100)m" }
    if d < 9950 { return String(format: "%.1fkm", d / 1000) }
    return "\(Int((d / 1000).rounded()))km"
  }
}

struct FavoritesEntry: TimelineEntry {
  let date: Date
  let items: [FavoriteItem]
  /// お気に入りが1件も登録されていない（案内文を出す）
  let hasFavorites: Bool
  /// 本体アプリがまだ一度もデータを書いていない（初回インストール直後等）
  let isPlaceholder: Bool

  static let placeholder = FavoritesEntry(
    date: Date(),
    items: [
      FavoriteItem(camera: WidgetCamera(id: "p1", name: "サンプルカメラ", imageUrl: nil,
                                        category: "river", prefecture: "13",
                                        operatorName: nil, updatedAt: nil, headers: nil,
                                        lat: nil, lng: nil),
                   image: nil),
    ],
    hasFavorites: true, isPlaceholder: true)
}

struct FavoritesProvider: TimelineProvider {
  /// 15分ごとに再取得（SPEC C3: 一次ソースへ礼儀正しく。1台あたり15分に1回）
  static let refreshInterval: TimeInterval = 15 * 60

  static func count(for family: WidgetFamily) -> Int {
    switch family {
    case .systemSmall: return 1
    case .systemMedium: return 2
    default: return 4
    }
  }

  static func maxPixel(for family: WidgetFamily) -> CGFloat {
    switch family {
    case .systemSmall: return 480
    case .systemMedium: return 480
    default: return 400
    }
  }

  func placeholder(in context: Context) -> FavoritesEntry { .placeholder }

  func getSnapshot(in context: Context, completion: @escaping (FavoritesEntry) -> Void) {
    if context.isPreview {
      completion(.placeholder)
      return
    }
    // ギャラリー以外のスナップショットはネットワークを待たず前回画像で返す
    let n = Self.count(for: context.family)
    let px = Self.maxPixel(for: context.family)
    guard let payload = FavoritesPayload.load() else {
      completion(.placeholder)
      return
    }
    let items = payload.ordered(by: SharedStore.loadViewerLocation()).prefix(n).map {
      FavoriteItem(camera: $0.camera,
                   image: ImageLoader.cached(cacheName: "cam-\($0.camera.id).jpg", maxPixel: px),
                   distance: $0.distance)
    }
    completion(FavoritesEntry(date: Date(), items: items,
                              hasFavorites: !payload.cameras.isEmpty, isPlaceholder: false))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<FavoritesEntry>) -> Void) {
    let n = Self.count(for: context.family)
    let px = Self.maxPixel(for: context.family)
    Task {
      let payload = FavoritesPayload.load()
      let ordered = payload?.ordered(by: SharedStore.loadViewerLocation()) ?? []
      var items: [FavoriteItem] = []
      // 逐次取得（同時接続を増やさない）。1台ずつ縮小してから次へ進む。
      // 画像を取るのは表示する分（現在地に近い順の先頭 n 台）だけ
      for (cam, distance) in ordered.prefix(n) {
        var image: UIImage? = nil
        if let s = cam.imageUrl, let url = URL(string: s) {
          image = await ImageLoader.load(url: url, headers: cam.headers ?? [:],
                                         cacheName: "cam-\(cam.id).jpg", maxPixel: px)
        }
        items.append(FavoriteItem(camera: cam, image: image, distance: distance))
      }
      let now = Date()
      let entry = FavoritesEntry(date: now, items: items,
                                 hasFavorites: !(payload?.cameras.isEmpty ?? true),
                                 isPlaceholder: payload == nil)
      completion(Timeline(entries: [entry],
                          policy: .after(now.addingTimeInterval(Self.refreshInterval))))
    }
  }
}

// MARK: - Views

struct FavoriteCamerasWidget: Widget {
  static let kind = "FavoriteCamerasWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: Self.kind, provider: FavoritesProvider()) { entry in
      FavoritesView(entry: entry)
        .containerBackground(for: .widget) { Color("WidgetBackground") }
    }
    .configurationDisplayName("お気に入りカメラ")
    .description("お気に入りに登録したライブカメラの最新画像を、現在地に近い順に表示します（15分ごとに更新）")
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    .contentMarginsDisabled()
  }
}

struct FavoritesView: View {
  @Environment(\.widgetFamily) private var family
  let entry: FavoritesEntry

  var body: some View {
    if entry.isPlaceholder && entry.items.isEmpty || !entry.hasFavorites {
      EmptyFavoritesView(installed: !entry.isPlaceholder)
        .widgetURL(URL(string: "\(SharedStore.urlScheme)://map?homeWidget"))
    } else {
      switch family {
      case .systemSmall:
        if let item = entry.items.first {
          CameraTile(item: item, fetchedAt: entry.date, large: true,
                     placeholder: entry.isPlaceholder)
            .widgetURL(SharedStore.cameraURL(id: item.camera.id))
        }
      case .systemMedium:
        HStack(spacing: 2) {
          ForEach(Array(entry.items.prefix(2).enumerated()), id: \.offset) { _, item in
            linked(item) {
              CameraTile(item: item, fetchedAt: entry.date, large: false,
                         placeholder: entry.isPlaceholder)
            }
          }
        }
      default:
        // 2x2。GeometryReader ベースのタイルが潰れないよう HStack/VStack で全面に広げる
        let items = Array(entry.items.prefix(4))
        VStack(spacing: 2) {
          ForEach(0..<2, id: \.self) { row in
            HStack(spacing: 2) {
              ForEach(0..<2, id: \.self) { col in
                let i = row * 2 + col
                if i < items.count {
                  linked(items[i]) {
                    CameraTile(item: items[i], fetchedAt: entry.date, large: false,
                               placeholder: entry.isPlaceholder)
                  }
                } else {
                  Color(white: 0.15)
                }
              }
            }
          }
        }
      }
    }
  }

  @ViewBuilder
  private func linked<C: View>(_ item: FavoriteItem, @ViewBuilder content: () -> C) -> some View {
    if let url = SharedStore.cameraURL(id: item.camera.id) {
      Link(destination: url) { content() }
    } else {
      content()
    }
  }
}

struct CameraTile: View {
  let item: FavoriteItem
  let fetchedAt: Date
  let large: Bool
  /// ギャラリーのプレビュー用（画像なしでもエラー文言を出さない）
  var placeholder: Bool = false

  var body: some View {
    GeometryReader { geo in
      ZStack(alignment: .bottomLeading) {
        if let img = item.image {
          Image(uiImage: img)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        } else if placeholder {
          ZStack {
            LinearGradient(colors: [Color(red: 0.16, green: 0.36, blue: 0.62), Color(red: 0.08, green: 0.16, blue: 0.30)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: "video.fill")
              .font(.system(size: large ? 30 : 22))
              .foregroundStyle(.white.opacity(0.8))
          }
        } else {
          ZStack {
            Color(white: 0.2)
            VStack(spacing: 4) {
              Image(systemName: "video.slash")
                .font(.system(size: large ? 28 : 20))
              Text("画像を取得できません")
                .font(.system(size: 10))
            }
            .foregroundStyle(.white.opacity(0.7))
          }
        }
        LinearGradient(colors: [.clear, .black.opacity(0.75)],
                       startPoint: .center, endPoint: .bottom)
        VStack(alignment: .leading, spacing: 1) {
          Text(item.camera.name)
            .font(.system(size: large ? 13 : 11, weight: .semibold))
            .lineLimit(large ? 2 : 1)
          HStack(spacing: 4) {
            Text("取得 \(TimeText.hm.string(from: fetchedAt))")
            if let d = item.distanceText {
              Image(systemName: "location.fill")
                .font(.system(size: 7))
              Text(d)
            }
          }
          .font(.system(size: 9))
          .opacity(0.85)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.bottom, 6)
      }
    }
    .clipped()
  }
}

struct EmptyFavoritesView: View {
  let installed: Bool

  var body: some View {
    VStack(spacing: 6) {
      Image(systemName: "star")
        .font(.system(size: 24))
      Text(installed ? "アプリでお気に入りを\n登録してください" : "アプリを一度起動すると\n表示されます")
        .font(.system(size: 12))
        .multilineTextAlignment(.center)
    }
    .foregroundStyle(.white.opacity(0.85))
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding()
  }
}
