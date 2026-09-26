import 'package:flutter/material.dart';

import '../models/camera.dart';
import '../models/status.dart';

/// カテゴリ別ピン色（SPEC 9.2②・デザイン確定版の割当）。
/// 景観の橙は白い記号(categoryIcon)が読みにくいため、少し濃い 0xFFE07B00 にしている
/// （2026-09-27 ピンへのカテゴリ記号追加時に調整）
const Map<String, Color> categoryColors = {
  'river': Color(0xFF1E6FD9),   // 河川=青
  'road': Color(0xFF616E7C),    // 道路=灰
  'volcano': Color(0xFFD93025), // 火山=赤
  'dam': Color(0xFF188038),     // ダム=緑
  'coast': Color(0xFF12B5CB),   // 海岸=水色
  'port': Color(0xFF7B3FE4),    // 港湾=紫
  'scenic': Color(0xFFE07B00),  // 景観=橙（濃）
  'healing': Color(0xFFEC5F9B), // 癒し=ピンク（動物・星空など）
  'other': Color(0xFF8D6E63),   // その他=茶
};

/// カテゴリ別の記号（ピン中央・絞り込みチップに白で描く）。
/// Material Icons に完全一致が無いものは近いものを使う
IconData categoryIcon(String key) => switch (key) {
      'river' => Icons.waves,
      'road' => Icons.signpost_outlined,
      'volcano' => Icons.local_fire_department,
      'dam' => Icons.water_drop,
      'coast' => Icons.beach_access,
      'port' => Icons.anchor,
      'scenic' => Icons.landscape,
      'healing' => Icons.spa,
      _ => Icons.videocam, // 'other' 及び未知キー
    };

/// カテゴリキーの表示順（凡例・フィルタで使う）。
/// 表示名は多言語化のため `l10n/l10n.dart` の `categoryLabelOf(l10n, key)` で解決する
/// （docs/research_2026-09-01/i18n_languages.md 8.6: データ層はキーのまま持つ）
const List<String> categoryKeys = [
  'river',
  'road',
  'volcano',
  'dam',
  'coast',
  'port',
  'scenic',
  'healing',
  'other',
];

/// 位置未確定（coord_accuracy が exact 以外）の縁取り色（SPEC 9.2②）
const Color uncertainBorderColor = Color(0xFFFFC400);

/// 動画LIVEドットの色
const Color liveDotColor = Color(0xFFE53935);

Color categoryColor(String category) =>
    categoryColors[category] ?? categoryColors['other']!;

/// ピンの見た目の直径（タップ領域は Marker 側で 44×44 に広げる。地図画面参照）
const double pinDiameter = 26;

/// カメラ1台分のピン。
/// - カテゴリ色の丸ピン＋中央にカテゴリ記号（白）
/// - 位置未確定は黄色の縁取り
/// - frozen は半透明（SPEC 5.2 表示ルール）
class CameraPin extends StatelessWidget {
  const CameraPin({
    super.key,
    required this.camera,
    this.state = CameraState.unknown,
    this.selected = false,
    this.favorite = false,
  });

  final Camera camera;
  final CameraState state;
  final bool selected;
  final bool favorite;

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(camera.category);
    final uncertain = camera.coordAccuracy.isUncertain;
    final pin = Container(
      width: pinDiameter,
      height: pinDiameter,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: uncertain
              ? uncertainBorderColor
              : (selected ? Colors.black87 : Colors.white),
          width: uncertain ? 3 : 2,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      // 記号は丸の直径の約55%
      child: Icon(categoryIcon(camera.category),
          size: pinDiameter * 0.55, color: Colors.white),
    );
    final badges = <Widget>[
      // 動画カメラは右上に赤ドット（LIVEインジケータ）
      if (camera.isVideo)
        Positioned(
          top: -2,
          right: -2,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: liveDotColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
          ),
        ),
      // お気に入りは左上に金の星
      if (favorite)
        const Positioned(
          top: -5,
          left: -5,
          child: Icon(Icons.star, size: 13, color: Color(0xFFFFB300),
              shadows: [Shadow(color: Colors.black45, blurRadius: 2)]),
        ),
    ];
    return Opacity(
      opacity: state == CameraState.frozen ? 0.45 : 1.0,
      child: badges.isEmpty
          ? pin
          : Stack(clipBehavior: Clip.none, children: [pin, ...badges]),
    );
  }
}

/// クラスタピンの見た目の直径（タップ領域は Marker 側で 44×44 に広げる）
const double clusterPinDiameter = 40;

/// クラスタ（件数バッジ）ピン。
class ClusterPin extends StatelessWidget {
  const ClusterPin({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: clusterPinDiameter,
      height: clusterPinDiameter,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF1E6FD9),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Text(
        count >= 1000 ? '${count ~/ 1000}k' : '$count',
        style: const TextStyle(
            color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}
