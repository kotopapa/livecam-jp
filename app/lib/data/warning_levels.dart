import 'package:flutter/painting.dart';

/// 気象警報・注意報コードの段階と色（災害速報タブとカメラ詳細の警報バッジで共用）。
/// 表示名は気象庁「多言語辞書」準拠 → l10n/l10n.dart の warningNameOf()

/// 扱う気象警報コード（警報・危険警報・特別警報）
const warningCodes = {
  '02', '03', '04', '05', '06', '07', '08', '09',
  // 2026-05-28の新体系で追加された「危険警報」(警戒レベル4相当。コード=警報+40)
  '43', '44', '48', '49',
  '32', '33', '34', '35', '36', '37', '38', '39',
};

/// 特別警報（警戒レベル5相当）のコード
const emergencyCodes = {'32', '33', '34', '35', '36', '37', '38', '39'};

/// 危険警報（警戒レベル4相当）のコード
const dangerCodes = {'43', '44', '48', '49'};

/// 扱う気象注意報コード
const advisoryCodes = {
  '10', '12', '13', '14', '15', '16', '17', '18',
  '19', '20', '21', '22', '23', '24', '25', '26',
  // 2026-05-28新体系で追加（土砂災害系が大雨から独立した）
  '29',
};

/// 警報コード → 表示色（特別=赤 / 危険警報=紫(レベル4) / 警報=オレンジ）
Color warningLevelColor(String code) {
  if (emergencyCodes.contains(code)) return const Color(0xFFD93025);
  if (dangerCodes.contains(code)) return const Color(0xFF9334E6);
  return const Color(0xFFF29900);
}

/// 並び順ランク（特別→危険→警報）
int warningLevelRank(String code) {
  if (emergencyCodes.contains(code)) return 0;
  if (dangerCodes.contains(code)) return 1;
  return 2;
}

/// 警戒レベル相当（特別警報=5 / 危険警報=4 / 警報=3 / 注意報=2）。扱わないコードは 0
int warningLevelOf(String code) {
  if (emergencyCodes.contains(code)) return 5;
  if (dangerCodes.contains(code)) return 4;
  if (warningCodes.contains(code)) return 3;
  if (advisoryCodes.contains(code)) return 2;
  return 0;
}

/// 警戒レベルのバッジ色（5=紫黒 / 4=紫 / 3=赤 / 2=黄）
Color warningBadgeColor(int level) => switch (level) {
      5 => const Color(0xFF2B0A3D),
      4 => const Color(0xFF9334E6),
      3 => const Color(0xFFD93025),
      _ => const Color(0xFFF2C200),
    };

/// バッジ色の上の文字色（黄だけ黒）
Color warningBadgeTextColor(int level) =>
    level == 2 ? const Color(0xFF1A1A1A) : const Color(0xFFFFFFFF);
