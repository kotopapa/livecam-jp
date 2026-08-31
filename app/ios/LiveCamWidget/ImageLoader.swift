import Foundation
import ImageIO
import UIKit

/// カメラ静止画の取得＋ダウンサンプリング。
/// ウィジェット拡張のメモリ上限(約30MB)を超えないよう、元画像を丸ごと
/// デコードせず ImageIO のサムネイル生成で縮小してから UIImage にする。
/// 取得失敗時は App Group 内に残した前回画像を返す。
enum ImageLoader {
  static let session: URLSession = {
    let cfg = URLSessionConfiguration.ephemeral
    cfg.timeoutIntervalForRequest = 12
    cfg.timeoutIntervalForResource = 20
    cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
    cfg.httpAdditionalHeaders = ["User-Agent": "LiveCamJP-Widget/1.3 (iOS)"]
    return URLSession(configuration: cfg)
  }()

  /// 画像を取得して縮小する。失敗時は前回画像（あれば）
  static func load(url: URL, headers: [String: String], cacheName: String,
                   maxPixel: CGFloat) async -> UIImage? {
    var req = URLRequest(url: url)
    for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }
    if let (data, resp) = try? await session.data(for: req),
       (resp as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? true,
       let img = downsample(data: data, maxPixel: maxPixel) {
      if let file = SharedStore.cacheURL(cacheName),
         let jpeg = img.jpegData(compressionQuality: 0.8) {
        try? jpeg.write(to: file, options: .atomic)
      }
      return img
    }
    return cached(cacheName: cacheName, maxPixel: maxPixel)
  }

  static func cached(cacheName: String, maxPixel: CGFloat) -> UIImage? {
    guard let file = SharedStore.cacheURL(cacheName),
          let data = try? Data(contentsOf: file) else { return nil }
    return downsample(data: data, maxPixel: maxPixel)
  }

  static func downsample(data: Data, maxPixel: CGFloat) -> UIImage? {
    let srcOpts = [kCGImageSourceShouldCache: false] as CFDictionary
    guard let src = CGImageSourceCreateWithData(data as CFData, srcOpts) else { return nil }
    let opts: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceShouldCacheImmediately: true,
      kCGImageSourceThumbnailMaxPixelSize: Int(maxPixel),
    ]
    guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else {
      return nil
    }
    return UIImage(cgImage: cg)
  }
}
