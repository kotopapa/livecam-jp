import 'package:flutter/material.dart';

import '../models/camera.dart';
import '../models/status.dart';

/// カテゴリ別ピン色（SPEC 9.2②・デザイン確定版の割当）。
const Map<String, Color> categoryColors = {
  'river': Color(0xFF1E6FD9),   // 河川=青
  'road': Color(0xFF616E7C),    // 道路=灰
  'volcano': Color(0xFFD93025), // 火山=赤
  'dam': Color(0xFF188038),     // ダム=緑
  'coast': Color(0xFF12B5CB),   // 海岸=水色
  'port': Color(0xFF7B3FE4),    // 港湾=紫
  'scenic': Color(0xFFF29900),  // 景観=橙
  'healing': Color(0xFFEC5F9B), // 癒し=ピンク（動物・星空など）
  'other': Color(0xFF8D6E63),   // その他=茶
};

/// カテゴリの表示名（凡例・フィルタで使う）
const Map<String, String> categoryLabels = {
  'river': '河川',
  'road': '道路',
  'volcano': '火山',
  'dam': 'ダム',
  'coast': '海岸',
  'port': '港湾',
  'scenic': '景観',
  'healing': '癒し',
  'other': 'その他',
};

/// 位置未確定（coord_accuracy が exact 以外）の縁取り色（SPEC 9.2②）
const Color uncertainBorderColor = Color(0xFFFFC400);

/// 動画LIVEドットの色
const Color liveDotColor = Color(0xFFE53935);

Color categoryColor(String category) =>
    categoryColors[category] ?? categoryColors['other']!;

/// カメラ1台分のピン。
/// - カテゴリ色の丸ピン
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

/// クラスタ（件数バッジ）ピン。
class ClusterPin extends StatelessWidget {
  const ClusterPin({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
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
