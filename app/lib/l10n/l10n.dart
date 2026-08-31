/// 多言語対応のUI側ヘルパー（1.4.0）。
///
/// `lib/data/` `lib/util/` は BuildContext を持たないためカテゴリ・都道府県・
/// 警報名を「キー（コード）」のまま保持し、表示名の解決はここ（UI層）で行う。
/// docs/research_2026-09-01/i18n_languages.md 8.6 の方針。
///
/// 防災用語の各言語訳は気象庁「気象情報等に関する多言語辞書」(2026-03-26版)
/// に準拠する。出典：気象庁（https://www.data.jma.go.jp/developer/multilingual.html）
/// 公共データ利用規約（第1.0版）＝CC BY 4.0 互換。**自由訳しないこと。**
library;

import 'package:flutter/widgets.dart';

import '../data/heat_alert.dart' show HeatAlertLevel;
import '../data/wbgt.dart' show WbgtLevel;
import 'gen/app_localizations.dart';

export 'gen/app_localizations.dart';

/// `context.l10n.xxx` で文言を引くための糖衣構文
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// カテゴリキー（SPEC 9.2② の9種）→ 表示名
String categoryLabelOf(AppLocalizations l10n, String category) =>
    switch (category) {
      'river' => l10n.categoryRiver,
      'road' => l10n.categoryRoad,
      'volcano' => l10n.categoryVolcano,
      'dam' => l10n.categoryDam,
      'coast' => l10n.categoryCoast,
      'port' => l10n.categoryPort,
      'scenic' => l10n.categoryScenic,
      'healing' => l10n.categoryHealing,
      _ => l10n.categoryOther,
    };

/// JIS都道府県コード（01〜47）→ 表示名。
/// 英語表記は気象庁「多言語辞書」の Prefecture 名から接尾辞を除いたもの
String prefectureNameOf(AppLocalizations l10n, String code) =>
    switch (code) {
      '01' => l10n.pref01,
      '02' => l10n.pref02,
      '03' => l10n.pref03,
      '04' => l10n.pref04,
      '05' => l10n.pref05,
      '06' => l10n.pref06,
      '07' => l10n.pref07,
      '08' => l10n.pref08,
      '09' => l10n.pref09,
      '10' => l10n.pref10,
      '11' => l10n.pref11,
      '12' => l10n.pref12,
      '13' => l10n.pref13,
      '14' => l10n.pref14,
      '15' => l10n.pref15,
      '16' => l10n.pref16,
      '17' => l10n.pref17,
      '18' => l10n.pref18,
      '19' => l10n.pref19,
      '20' => l10n.pref20,
      '21' => l10n.pref21,
      '22' => l10n.pref22,
      '23' => l10n.pref23,
      '24' => l10n.pref24,
      '25' => l10n.pref25,
      '26' => l10n.pref26,
      '27' => l10n.pref27,
      '28' => l10n.pref28,
      '29' => l10n.pref29,
      '30' => l10n.pref30,
      '31' => l10n.pref31,
      '32' => l10n.pref32,
      '33' => l10n.pref33,
      '34' => l10n.pref34,
      '35' => l10n.pref35,
      '36' => l10n.pref36,
      '37' => l10n.pref37,
      '38' => l10n.pref38,
      '39' => l10n.pref39,
      '40' => l10n.pref40,
      '41' => l10n.pref41,
      '42' => l10n.pref42,
      '43' => l10n.pref43,
      '44' => l10n.pref44,
      '45' => l10n.pref45,
      '46' => l10n.pref46,
      '47' => l10n.pref47,
      _ => code,
    };

/// 気象警報コード → 表示名（出典：気象庁 多言語辞書）。
/// 未知のコードは null（呼び出し側でコードのまま表示しない判断ができるように）
String? warningNameOf(AppLocalizations l10n, String code) => switch (code) {
      '02' => l10n.warning02,
      '03' => l10n.warning03,
      '04' => l10n.warning04,
      '05' => l10n.warning05,
      '06' => l10n.warning06,
      '07' => l10n.warning07,
      '08' => l10n.warning08,
      '09' => l10n.warning09,
      '43' => l10n.warning43,
      '44' => l10n.warning44,
      '48' => l10n.warning48,
      '49' => l10n.warning49,
      '32' => l10n.warning32,
      '33' => l10n.warning33,
      '34' => l10n.warning34,
      '35' => l10n.warning35,
      '36' => l10n.warning36,
      '37' => l10n.warning37,
      '38' => l10n.warning38,
      '39' => l10n.warning39,
      _ => null,
    };

/// 気象注意報コード → 表示名（出典：気象庁 多言語辞書）
String? advisoryNameOf(AppLocalizations l10n, String code) => switch (code) {
      '10' => l10n.advisory10,
      '12' => l10n.advisory12,
      '13' => l10n.advisory13,
      '14' => l10n.advisory14,
      '15' => l10n.advisory15,
      '16' => l10n.advisory16,
      '17' => l10n.advisory17,
      '18' => l10n.advisory18,
      '19' => l10n.advisory19,
      '20' => l10n.advisory20,
      '21' => l10n.advisory21,
      '22' => l10n.advisory22,
      '23' => l10n.advisory23,
      '24' => l10n.advisory24,
      '25' => l10n.advisory25,
      '26' => l10n.advisory26,
      '29' => l10n.advisory29,
      _ => null,
    };

/// 震度階級（気象庁の標準形 '5-' 等）→ 表示名（出典：気象庁 多言語辞書）
String intensityLabelOf(AppLocalizations l10n, String code) =>
    switch (code) {
      '5-' || '5弱' => l10n.intensity5Lower,
      '5+' || '5強' => l10n.intensity5Upper,
      '6-' || '6弱' => l10n.intensity6Lower,
      '6+' || '6強' => l10n.intensity6Upper,
      _ => code,
    };

/// 地震通知のしきい値（'5-' / '5+' / '6-'）→ 設定画面の表示名
String quakeLevelLabelOf(AppLocalizations l10n, String code) =>
    switch (code) {
      '5-' => l10n.quakeLevel5Lower,
      '5+' => l10n.quakeLevel5Upper,
      '6-' => l10n.quakeLevel6Lower,
      _ => code,
    };

// ---------------------------------------------------------------------------
// 地図レイヤー系（`lib/data/*_layers.dart` はキーだけを持ち、表示名はここで解決する）
// ---------------------------------------------------------------------------

/// ハザードマップのレイヤー名（`HazardLayers.titleKey()` のキー）
String hazardLayerTitleOf(AppLocalizations l10n, String key) => switch (key) {
      'flood' => l10n.hazardFloodTitle,
      'landslide' => l10n.hazardLandslideTitle,
      'tsunami' => l10n.hazardTsunamiTitle,
      'hightide' => l10n.hazardHightideTitle,
      _ => '',
    };

/// 土砂災害の区分（`HazardLayers.landslideScale` のキー）
String landslideKindOf(AppLocalizations l10n, String key) => switch (key) {
      'steepSlope' => l10n.hazardLandslideSteepSlope,
      'debrisFlow' => l10n.hazardLandslideDebrisFlow,
      'landslide' => l10n.hazardLandslideSlide,
      _ => key,
    };

/// キキクルのレイヤー名（`RiskLayers.titleKey()` のキー。出典：気象庁）
String riskLayerTitleOf(AppLocalizations l10n, String key) => switch (key) {
      'land' => l10n.riskLandTitle,
      'inund' => l10n.riskInundTitle,
      'flood' => l10n.riskFloodTitle,
      _ => '',
    };

/// キキクルのレイヤー説明
String riskLayerSubtitleOf(AppLocalizations l10n, String key) => switch (key) {
      'land' => l10n.riskLandSubtitle,
      'inund' => l10n.riskInundSubtitle,
      'flood' => l10n.riskFloodSubtitle,
      _ => '',
    };

/// キキクルの危険度5段階（`RiskLayers.scale()` のキー。出典：気象庁）
String riskLevelLabelOf(AppLocalizations l10n, String key) => switch (key) {
      'watch' => l10n.riskLevelWatch,
      'caution' => l10n.riskLevelCaution,
      'warning' => l10n.riskLevelWarning,
      'danger' => l10n.riskLevelDanger,
      'critical' => l10n.riskLevelCritical,
      _ => key,
    };

/// 避難場所の災害種別。配信JSONが日本語で送ってくるため、日本語名をキーにする
String shelterHazardLabelOf(AppLocalizations l10n, String jaName) =>
    switch (jaName) {
      '洪水' => l10n.shelterHazardFlood,
      '土砂' => l10n.shelterHazardSediment,
      '高潮' => l10n.shelterHazardHightide,
      '地震' => l10n.shelterHazardEarthquake,
      '津波' => l10n.shelterHazardTsunami,
      '火事' => l10n.shelterHazardFire,
      '内水' => l10n.shelterHazardInlandFlood,
      '火山' => l10n.shelterHazardVolcano,
      _ => jaName,
    };

/// 防災拠点の種別（正式名称）
String facilityKindLabelOf(AppLocalizations l10n, String kind) =>
    switch (kind) {
      'water' => l10n.facilityKindWater,
      'stock' => l10n.facilityKindStock,
      'fire_water' => l10n.facilityKindFireWater,
      _ => kind,
    };

/// 防災拠点の種別（チップ・凡例用の短い名称）
String facilityKindShortOf(AppLocalizations l10n, String kind) =>
    switch (kind) {
      'water' => l10n.facilityKindWaterShort,
      'stock' => l10n.facilityKindStockShort,
      'fire_water' => l10n.facilityKindFireWaterShort,
      _ => kind,
    };

/// 暑さ指数（WBGT）の5段階（出典：環境省）
String wbgtLevelLabelOf(AppLocalizations l10n, WbgtLevel level) =>
    switch (level) {
      WbgtLevel.danger => l10n.wbgtLevelDanger,
      WbgtLevel.severeWarning => l10n.wbgtLevelSevereWarning,
      WbgtLevel.warning => l10n.wbgtLevelWarning,
      WbgtLevel.caution => l10n.wbgtLevelCaution,
      WbgtLevel.safe => l10n.wbgtLevelSafe,
    };

/// 熱中症警戒アラートの区分（出典：環境省／気象庁 多言語辞書）
String heatAlertLabelOf(AppLocalizations l10n, HeatAlertLevel level) =>
    switch (level) {
      HeatAlertLevel.special => l10n.heatAlertSpecial,
      HeatAlertLevel.specialPending => l10n.heatAlertSpecialPending,
      HeatAlertLevel.warning => l10n.heatAlertWarning,
      _ => '',
    };
