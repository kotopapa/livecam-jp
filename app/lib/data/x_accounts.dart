/// 自治体・国の機関の災害情報 X（旧Twitter）アカウント一覧（配信JSON `/v1/x_accounts.json`）。
///
/// **アプリ内にポストは表示しない**（X API は従量課金、埋め込みは未ログインで
/// 表示されない）。外部ブラウザでプロフィールを開く導線だけを提供する。
///
/// 一覧は `data/x_accounts.json` を site/build.py（tools/x_accounts_publish.py）が
/// 公開用に絞ったもの。運営主体の種別（自治体公式・国の機関など）は誤認防止のため
/// **必ず併記する**（2026-09-06 ユーザー決定）。
///
/// 取得できなかったときは `null`（画面は「読み込めない」表示）。
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config.dart';

/// 運営主体の種別。表示名は `xAccountTypeLabelOf(l10n, type)`
enum XAccountType {
  official('official'),
  govRelated('gov_related'),
  national('national'),
  company('company'),
  organization('organization'),
  individual('individual'),
  otherArea('other_area'),
  unknown('unknown');

  const XAccountType(this.key);
  final String key;

  static XAccountType fromKey(String? k) =>
      XAccountType.values.firstWhere((t) => t.key == k,
          orElse: () => XAccountType.unknown);
}

/// アカウント1件
class XAccount {
  const XAccount({
    required this.areaCodes,
    required this.areaName,
    required this.handle,
    required this.displayName,
    required this.type,
    this.operator = '',
    this.profile = '',
    this.dedicated = true,
    this.source,
  });

  /// 対象地域の都道府県JISコード（2桁）。国の機関は複数県にまたがる
  final List<String> areaCodes;

  /// 対象地域の名称（都道府県名・市区町村名・管轄の説明）
  final String areaName;
  final String handle;
  final String displayName;
  final XAccountType type;

  /// 運営部署（例: 埼玉県 県土整備部 河川砂防課）
  final String operator;

  /// プロフィール本文（配信側で短縮済み）
  final String profile;

  /// 防災専用アカウントか。false は県の総合アカウント（防災専用が無い県の代替）
  final bool dedicated;

  /// 公式性を確認した一次ソース（自治体サイトのSNS一覧など）
  final String? source;

  Uri get url => Uri.parse('https://x.com/$handle');

  bool coversPrefecture(String pref) => areaCodes.contains(pref);

  static XAccount? fromJson(Map<String, dynamic> j) {
    final handle = j['handle'] as String?;
    final name = j['display_name'] as String?;
    if (handle == null ||
        handle.isEmpty ||
        !RegExp(r'^[A-Za-z0-9_]{1,15}$').hasMatch(handle) ||
        name == null ||
        name.isEmpty) {
      return null;
    }
    final codes = <String>[
      if (j['area_code'] is String) j['area_code'] as String,
      for (final c in (j['area_codes'] as List? ?? const []))
        if (c is String) c,
    ];
    return XAccount(
      areaCodes: codes,
      areaName: j['area_name'] as String? ?? '',
      handle: handle,
      displayName: name,
      type: XAccountType.fromKey(j['type'] as String?),
      operator: j['operator'] as String? ?? '',
      profile: j['profile'] as String? ?? '',
      dedicated: j['dedicated'] as bool? ?? true,
      source: j['source'] as String?,
    );
  }
}

/// 配信JSON全体
class XAccounts {
  const XAccounts({
    required this.generated,
    required this.prefectures,
    required this.municipalities,
    required this.nationalOffices,
  });

  final String generated;

  /// 都道府県（JISコード順）
  final List<XAccount> prefectures;
  final List<XAccount> municipalities;

  /// 国の機関（国交省の河川事務所など）
  final List<XAccount> nationalOffices;

  bool get isEmpty =>
      prefectures.isEmpty && municipalities.isEmpty && nationalOffices.isEmpty;

  /// ある都道府県に関係するアカウント（県 → 国の機関 → 市区町村の順）
  List<XAccount> forPrefecture(String pref) => [
        for (final a in prefectures)
          if (a.coversPrefecture(pref)) a,
        for (final a in nationalOffices)
          if (a.coversPrefecture(pref)) a,
        for (final a in municipalities)
          if (a.coversPrefecture(pref)) a,
      ];

  static XAccounts? fromJson(Map<String, dynamic> j) {
    List<XAccount> parse(String key) => [
          for (final e in (j[key] as List? ?? const []))
            if (e is Map<String, dynamic>) ?XAccount.fromJson(e),
        ];
    final p = parse('prefectures')
      ..sort((a, b) => a.areaCodes.join().compareTo(b.areaCodes.join()));
    final out = XAccounts(
      generated: j['generated'] as String? ?? '',
      prefectures: p,
      municipalities: parse('municipalities'),
      nationalOffices: parse('national_offices'),
    );
    return out.isEmpty ? null : out;
  }
}

/// 取得元。ネットワーク → 失敗したらディスクの控え。
/// アカウントの廃止・なりすまし判明時に**消える方が重要**なので、控えより
/// 配信側を優先する（stockpile_products と同じ方針）
class XAccountsRepository {
  XAccountsRepository({http.Client? client, this.cacheDir})
      : _client = client ?? http.Client();

  static const String url = '${apiBaseUrl}x_accounts.json';
  static const String _cacheName = 'x_accounts.json';

  final http.Client _client;
  final Directory? cacheDir;

  static const Map<String, String> _ua = {
    'User-Agent': 'livecam-jp/$appVersion (iOS app)',
  };

  /// 同一プロセス内の控え（画面を開くたびの再取得を避ける）
  static XAccounts? _memory;
  static DateTime? _memoryAt;
  static const Duration _memoryTtl = Duration(hours: 6);

  File? get _file =>
      cacheDir == null ? null : File('${cacheDir!.path}/$_cacheName');

  Future<XAccounts?> load() async {
    final m = _memory;
    final at = _memoryAt;
    if (m != null &&
        at != null &&
        DateTime.now().difference(at) < _memoryTtl) {
      return m;
    }
    final fetched = await _fetch();
    if (fetched != null) {
      _memory = fetched;
      _memoryAt = DateTime.now();
      return fetched;
    }
    return m ?? await _readDisk();
  }

  Future<XAccounts?> _fetch() async {
    try {
      final r = await _client
          .get(Uri.parse(url), headers: _ua)
          .timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) return null;
      final raw = utf8.decode(r.bodyBytes);
      final p = XAccounts.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      if (p != null) await _writeDisk(raw);
      return p;
    } catch (_) {
      return null;
    }
  }

  Future<XAccounts?> _readDisk() async {
    try {
      final f = _file;
      if (f == null || !await f.exists()) return null;
      return XAccounts.fromJson(
          jsonDecode(await f.readAsString()) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeDisk(String raw) async {
    try {
      final f = _file;
      if (f == null) return;
      await f.parent.create(recursive: true);
      await f.writeAsString(raw);
    } catch (_) {}
  }

  /// テスト用: プロセス内の控えを捨てる
  static void resetMemory() {
    _memory = null;
    _memoryAt = null;
  }
}
