import 'package:flutter/material.dart';

/// 広告バーのプレースホルダ。
///
/// 将来 AdMob 等を導入する際は、このウィジェットの build を広告SDKの
/// バナーに差し替える（呼び出し側の変更は不要）。標準バナー相当の高さを確保。
class AdBannerPlaceholder extends StatelessWidget {
  const AdBannerPlaceholder({super.key});

  static const double bannerHeight = 60;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: bannerHeight,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[400]!, style: BorderStyle.solid),
      ),
      alignment: Alignment.center,
      child: Text(
        'AD ― 広告スペース（テスト枠 320×50）',
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
    );
  }
}
