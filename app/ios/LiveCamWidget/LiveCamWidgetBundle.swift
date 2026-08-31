import SwiftUI
import WidgetKit

/// 全国ライブカメラ地図のホーム画面ウィジェット群（1.3.0）。
/// - FavoriteCamerasWidget: お気に入りカメラの最新画像
/// - BosaiWidget: 災害速報（気象庁の警報・地震）
@main
struct LiveCamWidgetBundle: WidgetBundle {
  var body: some Widget {
    FavoriteCamerasWidget()
    BosaiWidget()
  }
}
