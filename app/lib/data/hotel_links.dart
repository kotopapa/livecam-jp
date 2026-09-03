/// カメラ詳細「この付近の宿を探す」のリンク組み立て（1.5.0）。
///
/// 各社の検索URLは 2026-09-03 に curl で実測して決めた
/// （docs/research_2026-09-03/hotel_deeplinks.md）。要点:
/// - **楽天トラベル**: スマホ版「現在地から探す」と同じ `searchVacant`。座標は
///   **日本測地系の秒**（f_ido/f_kdo）。宿泊日が必須なので「JSTの明日から1泊」
/// - **JTB**: 県ごとの一覧に `lat/lng/sort=location`（距離が近い順）。県パスが
///   無いと全国ランキングになる
/// - **じゃらん**: Web版に座標検索が無いので市区町村名のキーワード検索。
///   キーワードは **Shift_JIS のパーセントエンコード**限定（UTF-8 は0件になる）
///   なので、`tools/hotel_keywords.py` が生成したアセット
///   `assets/data/municipalities.json` の値を使う（[MunicipalityNames]）
/// - **Expedia**: `Hotel-Search?latLong=`。海外カメラ向け
///
/// 表示条件（画面側で判定）:
/// - 観光系カテゴリ（[HotelLinks.tourismCategories]）と海外カメラのみ。
///   河川・道路・ダムの防災カメラには出さない
/// - その県に特別警報・危険警報が出ている間は出さない（`AppState.alertPrefectures`）
/// - アフィリエイトのリンクは必ず外部ブラウザで開く（affiliate.dart の注意と同じ）
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../config.dart';
import '../models/camera.dart';
import 'affiliate.dart';

class HotelLink {
  const HotelLink({required this.site, required this.url});

  final HotelSite site;
  final Uri url;
}

class HotelLinks {
  const HotelLinks._();

  /// 宿の導線を出すカテゴリ（観光目的で見られるもの）
  static const Set<String> tourismCategories = {
    'scenic',
    'coast',
    'volcano',
    'healing',
  };

  /// このカメラに宿の導線を出してよいか（警報の判定は画面側）
  static bool eligible(Camera c) =>
      c.hasLocation && (c.isWorld || tourismCategories.contains(c.category));

  /// 配信フラグ（`AffiliateLinks.remoteFlags`。products.json の merchants）を
  /// 反映したサイト一覧
  static List<HotelSite> sitesWith(Map<String, bool> flags) => [
    for (final s in hotelSites)
      flags.containsKey(s.key)
          ? HotelSite(
              key: s.key,
              name: s.name,
              nameEn: s.nameEn,
              pid: s.pid,
              enabled: flags[s.key]!,
              domestic: s.domestic,
              world: s.world,
            )
          : s,
  ];

  static List<HotelSite> get sites => sitesWith(AffiliateLinks.remoteFlags);

  /// [camera] 用のリンク一覧。[checkIn] は JST の壁時計（`jstNow()` 由来）の
  /// チェックイン日。[jalanKeyword] は Shift_JIS エンコード済みの市区町村名
  /// （無ければじゃらんは出さない）。
  static List<HotelLink> linksFor(
    Camera camera, {
    required DateTime checkIn,
    String? jalanKeyword,
    List<HotelSite>? sites,
  }) {
    if (!eligible(camera)) return const [];
    final out = <HotelLink>[];
    for (final s in sites ?? HotelLinks.sites) {
      if (!s.enabled) continue;
      if (camera.isWorld ? !s.world : !s.domestic) continue;
      final dest = destinationFor(
        s.key,
        camera,
        checkIn: checkIn,
        jalanKeyword: jalanKeyword,
      );
      if (dest == null) continue;
      final url = s.isAffiliate && vcSid.isNotEmpty
          ? AffiliateLinks.referral(sid: vcSid, pid: s.pid, destination: dest)
          : dest;
      out.add(HotelLink(site: s, url: url));
    }
    return out;
  }

  /// サイトごとの遷移先（リファラルで包む前）。組み立てられなければ null
  static Uri? destinationFor(
    String key,
    Camera camera, {
    required DateTime checkIn,
    String? jalanKeyword,
  }) {
    final lat = camera.lat;
    final lng = camera.lng;
    if (lat == null || lng == null) return null;
    switch (key) {
      case 'rakuten_travel':
        return rakutenTravelUrl(lat, lng, checkIn: checkIn);
      case 'jtb':
        return jtbUrl(lat, lng, camera.prefecture);
      case 'jalan':
        return jalanKeyword == null || jalanKeyword.isEmpty
            ? null
            : jalanUrl(jalanKeyword);
      case 'expedia':
        return expediaUrl(lat, lng);
    }
    return null;
  }

  // --- 楽天トラベル ---------------------------------------------------------

  /// WGS84（度）→ 日本測地系（秒）。楽天トラベルのスマホ版 JS
  /// （share/themes/ds/smart/js/area.js）の式そのまま。小数2桁で切り捨て
  static (double ido, double kdo) tokyoDatumSeconds(double lat, double lng) {
    double trunc2(double v) => (v * 100).truncateToDouble() / 100;
    final ido = trunc2(3600 * (1.000106961 * lat - 0.000017467 * lng - 0.004602017));
    final kdo = trunc2(3600 * (1.000083049 * lng + 0.000046047 * lat - 0.010041046));
    return (ido, kdo);
  }

  /// 検索半径（km）。楽天の既定は2.0だが、景勝地は宿が離れがちなので上限の3.0
  static const double rakutenRadiusKm = 3.0;

  static Uri rakutenTravelUrl(
    double lat,
    double lng, {
    required DateTime checkIn,
  }) {
    final (ido, kdo) = tokyoDatumSeconds(lat, lng);
    final out = checkIn.add(const Duration(days: 1));
    return Uri.https('search.travel.rakuten.co.jp', '/ds/vacant/searchVacant', {
      'f_ido': _num(ido),
      'f_kdo': _num(kdo),
      'f_landmark_name_id': 'APP_NGPS',
      'f_km': rakutenRadiusKm.toStringAsFixed(1),
      'f_nen1': '${checkIn.year}',
      'f_tuki1': '${checkIn.month}',
      'f_hi1': '${checkIn.day}',
      'f_nen2': '${out.year}',
      'f_tuki2': '${out.month}',
      'f_hi2': '${out.day}',
      'f_adult_su': '1',
      'f_otona_su': '1',
      'f_heya_su': '1',
      'f_kin2': '1',
      'f_sort': 'hotel',
      'f_image': '1',
      'f_hyoji': '10',
      'f_page': '1',
    });
  }

  static String _num(double v) {
    final s = v.toStringAsFixed(2);
    return s.endsWith('.00')
        ? s.substring(0, s.length - 3)
        : s.endsWith('0')
            ? s.substring(0, s.length - 1)
            : s;
  }

  // --- JTB -------------------------------------------------------------------

  /// JTB 国内宿泊の県パス（2026-09-03 に一覧ページのリンクから採取）
  static const Map<String, String> jtbPrefSlugs = {
    '01': 'hokkaido', '02': 'aomori', '03': 'iwate', '04': 'miyagi',
    '05': 'akita', '06': 'yamagata', '07': 'fukushima', '08': 'ibaraki',
    '09': 'tochigi', '10': 'gunma', '11': 'saitama', '12': 'chiba',
    '13': 'tokyo', '14': 'kanagawa', '15': 'niigata', '16': 'toyama',
    '17': 'ishikawa', '18': 'fukui', '19': 'yamanashi', '20': 'nagano',
    '21': 'gifu', '22': 'shizuoka', '23': 'aichi', '24': 'mie',
    '25': 'shiga', '26': 'kyoto', '27': 'osaka', '28': 'hyogo',
    '29': 'nara', '30': 'wakayama', '31': 'tottori', '32': 'shimane',
    '33': 'okayama', '34': 'hiroshima', '35': 'yamaguchi', '36': 'tokushima',
    '37': 'kagawa', '38': 'ehime', '39': 'kochi', '40': 'fukuoka',
    '41': 'saga', '42': 'nagasaki', '43': 'kumamoto', '44': 'oita',
    '45': 'miyazaki', '46': 'kagoshima', '47': 'okinawa',
  };

  static Uri? jtbUrl(double lat, double lng, String prefecture) {
    final slug = jtbPrefSlugs[prefecture];
    if (slug == null) return null;
    return Uri.https('www.jtb.co.jp', '/kokunai-hotel/list/$slug/', {
      'lat': _coord(lat),
      'lng': _coord(lng),
      'sort': 'location',
      'dateunspecified': '1',
      'room': '1',
      'roomassign': 'm2',
      'staynight': '1',
    });
  }

  static String _coord(double v) => v.toStringAsFixed(5);

  // --- じゃらん --------------------------------------------------------------

  /// [sjisKeyword] は Shift_JIS でパーセントエンコード済みの検索語
  /// （`%95x%8Em...`）。Uri のクエリ組み立てを通すと二重エンコードされるので
  /// 文字列で連結する
  static Uri jalanUrl(String sjisKeyword) => Uri.parse(
    'https://www.jalan.net/uw/uwp2011/uww2011init.do?keyword=$sjisKeyword',
  );

  // --- Expedia ---------------------------------------------------------------

  static Uri expediaUrl(double lat, double lng) =>
      Uri.https('www.expedia.co.jp', '/Hotel-Search', {
        'latLong': '${_coord(lat)},${_coord(lng)}',
        'adults': '2',
      });
}

/// 市区町村コード（JIS 5桁）→ 名称と Shift_JIS エンコード済み検索語。
/// `assets/data/municipalities.json`（`tools/hotel_keywords.py` 生成）を1回だけ読む
class MunicipalityNames {
  const MunicipalityNames._();

  static Map<String, List<String>>? _table;
  static Future<void>? _loading;

  static bool get isLoaded => _table != null;

  static Future<void> load() => _loading ??= _load();

  static Future<void> _load() async {
    try {
      final raw = await rootBundle.loadString('assets/data/municipalities.json');
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final m = (j['municipalities'] as Map<String, dynamic>? ?? const {});
      _table = {
        for (final e in m.entries)
          if (e.value is List && (e.value as List).length >= 2)
            e.key: [(e.value as List)[0] as String, (e.value as List)[1] as String],
      };
    } catch (_) {
      _table = const {};
    }
  }

  /// テスト用にテーブルを差し替える
  static void setTable(Map<String, List<String>>? table) {
    _table = table;
    _loading = table == null ? null : Future.value();
  }

  static List<String>? _lookup(String? code) {
    final t = _table;
    if (t == null || code == null || code.length != 5) return null;
    final hit = t[code];
    if (hit != null) return hit;
    // 政令指定都市の区（14104 横浜市中区）は市（14100）に丸める
    return t['${code.substring(0, 3)}00'];
  }

  static String? nameOf(String? code) => _lookup(code)?[0];

  static String? sjisKeywordOf(String? code) => _lookup(code)?[1];
}
