/// 備蓄品の「選び方」と定番商品（配信JSON `/v1/stockpile/products.json`）。
///
/// **アプリに商品を埋め込まない**。廃番・在庫切れ・リコールが頻繁に起きるため、
/// 台帳（cameras.json）と同じくGitHub Pagesの配信JSONから読む。
/// これによりApp Store申請なしで差し替え・削除ができる。
/// 生成: `data/stockpile/products.json`／月次点検: `tools/stockpile_check.py`
///
/// 取得できなかったときは `null` のまま画面を組み立てる（アプリ内の
/// [StockpileItemSpec.searchKeyword] にフォールバックするので機能は落ちない）。
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config.dart';

/// 出典・製品ページなどのリンク1件
class ProductLink {
  const ProductLink({required this.name, required this.url});

  final String name;
  final String url;

  static ProductLink? fromJson(Map<String, dynamic> j) {
    final name = (j['name'] ?? j['title']) as String?;
    final url = j['url'] as String?;
    if (name == null ||
        name.isEmpty ||
        url == null ||
        !url.startsWith('http')) {
      return null;
    }
    return ProductLink(name: name, url: url);
  }
}

/// 具体的な商品1件（いまはメーカー公式の製品ページのみ）
class ProductRef {
  const ProductRef({
    required this.shop,
    required this.title,
    required this.url,
    this.checkedAt,
  });

  /// `official` = メーカー公式ページ。将来モール商品URLを載せる場合は店舗キー
  final String shop;
  final String title;
  final String url;

  /// 最後にURLの生存を確認した日（YYYY-MM-DD）
  final String? checkedAt;

  /// 提携ショップで検索するときの語。タイトルの括弧以降（仕様の補足）を落とす
  /// 例: 「尾西食品 尾西の白飯 100g（保存5年…）」→「尾西食品 尾西の白飯 100g」
  String get searchKeyword {
    var t = title.trim();
    for (final sep in const ['（', '(', '【', '［', '[']) {
      final i = t.indexOf(sep);
      if (i > 0) t = t.substring(0, i);
    }
    t = t.trim();
    return t.isEmpty ? title.trim() : t;
  }

  static ProductRef? fromJson(Map<String, dynamic> j) {
    final title = j['title'] as String?;
    final url = j['url'] as String?;
    if (title == null ||
        title.isEmpty ||
        url == null ||
        !url.startsWith('http')) {
      return null;
    }
    return ProductRef(
      shop: j['shop'] as String? ?? 'official',
      title: title,
      url: url,
      checkedAt: j['checked_at'] as String?,
    );
  }
}

/// 認証・規格（防災製品等推奨品・JIS・国家検定など）
class ProductCert {
  const ProductCert({required this.name, this.no, this.url});

  final String name;
  final String? no;
  final String? url;

  static ProductCert? fromJson(Map<String, dynamic> j) {
    final name = j['name'] as String?;
    if (name == null || name.isEmpty) return null;
    return ProductCert(
      name: name,
      no: j['no'] as String?,
      url: j['url'] as String?,
    );
  }
}

/// 1品目分の「選び方」＋商品
class StockpileProductGuide {
  const StockpileProductGuide({
    required this.id,
    required this.name,
    required this.spec,
    required this.why,
    required this.sources,
    required this.search,
    required this.products,
    this.cert,
  });

  /// [StockpileItemSpec.id] と同じキー
  final String id;
  final String name;

  /// 数値で比べられる仕様（保存年数・容量・入数など）
  final String spec;

  /// なぜこの仕様を選ぶのか（公的資料の根拠）
  final String why;

  final List<ProductLink> sources;

  /// 店舗キー（`yahoo` / `rakuten` / `amazon`）→ 検索語
  final Map<String, String> search;

  final List<ProductRef> products;
  final ProductCert? cert;

  /// [merchantKey] 用の検索語。無ければ他店舗の語 → null
  String? keywordFor(String merchantKey) {
    final k = search[merchantKey];
    if (k != null && k.trim().isNotEmpty) return k.trim();
    for (final v in search.values) {
      if (v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  static StockpileProductGuide? fromJson(Map<String, dynamic> j) {
    final id = j['id'] as String?;
    if (id == null || id.isEmpty) return null;
    return StockpileProductGuide(
      id: id,
      name: j['name'] as String? ?? '',
      spec: j['spec'] as String? ?? '',
      why: j['why'] as String? ?? '',
      sources: [
        for (final s in (j['sources'] as List? ?? const []))
          if (s is Map<String, dynamic>) ?ProductLink.fromJson(s),
      ],
      search: {
        for (final e in (j['search'] as Map? ?? const {}).entries)
          if (e.key is String && e.value is String)
            e.key as String: e.value as String,
      },
      products: [
        for (final p in (j['products'] as List? ?? const []))
          if (p is Map<String, dynamic>) ?ProductRef.fromJson(p),
      ],
      cert: j['cert'] is Map<String, dynamic>
          ? ProductCert.fromJson(j['cert'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// 配信JSON全体
class StockpileProducts {
  const StockpileProducts({
    required this.version,
    required this.notice,
    required this.disclaimer,
    required this.certNote,
    required this.sources,
    required this.byItemId,
    this.merchants = const {},
  });

  final String version;

  /// アフィリエイト表記（ステマ規制対応。ARBの文言が既定で、こちらは配信側の上書き）
  final String notice;

  /// 「推奨・保証ではない」旨の注記
  final String disclaimer;

  /// 認証欄の但し書き（cert が無い＝非認定ではない）
  final String certNote;

  final List<ProductLink> sources;

  /// 品目ID → 選び方・商品
  final Map<String, StockpileProductGuide> byItemId;

  /// 提携ショップの有効フラグ（店舗キー → enabled）。配信側で承認状況を反映し、
  /// アプリ更新なしで楽天・Amazon 等を後から有効化できる（1.4.0）。
  /// 無いキーは config.dart の既定値のまま
  final Map<String, bool> merchants;

  StockpileProductGuide? guideFor(String itemId) => byItemId[itemId];

  bool get isEmpty => byItemId.isEmpty;

  static StockpileProducts? fromJson(Map<String, dynamic> j) {
    final guides = <String, StockpileProductGuide>{};
    for (final c in (j['categories'] as List? ?? const [])) {
      if (c is! Map<String, dynamic>) continue;
      for (final i in (c['items'] as List? ?? const [])) {
        if (i is! Map<String, dynamic>) continue;
        final g = StockpileProductGuide.fromJson(i);
        if (g != null) guides[g.id] = g;
      }
    }
    if (guides.isEmpty) return null;
    return StockpileProducts(
      version: j['version'] as String? ?? '',
      notice: j['notice'] as String? ?? '',
      disclaimer: j['disclaimer'] as String? ?? '',
      certNote: j['cert_note'] as String? ?? '',
      sources: [
        for (final s in (j['sources'] as List? ?? const []))
          if (s is Map<String, dynamic>) ?ProductLink.fromJson(s),
      ],
      byItemId: guides,
      merchants: parseMerchants(j['merchants']),
    );
  }

  /// `{"yahoo": {"enabled": true}}` と `{"yahoo": true}` の両方を受け付ける。
  /// 不正な値は無視する（既定値にフォールバック）
  static Map<String, bool> parseMerchants(Object? raw) {
    if (raw is! Map) return const {};
    final out = <String, bool>{};
    for (final e in raw.entries) {
      final k = e.key;
      final v = e.value;
      if (k is! String || k.isEmpty) continue;
      if (v is bool) {
        out[k] = v;
      } else if (v is Map && v['enabled'] is bool) {
        out[k] = v['enabled'] as bool;
      }
    }
    return out;
  }
}

/// 取得元。ネットワーク → 失敗したらディスクの控え、の順で解決する。
///
/// 商品は廃番・リコールで**消えることのほうが重要**なので、控えより新しい方を
/// 優先する（古い控えでリコール品を出し続けない）。オフラインのときだけ控えを使う。
class StockpileProductsRepository {
  StockpileProductsRepository({http.Client? client, this.cacheDir})
    : _client = client ?? http.Client();

  static const String url = '${apiBaseUrl}stockpile/products.json';
  static const String _cacheName = 'stockpile_products.json';

  final http.Client _client;

  /// 控えの置き場（端末の一時ディレクトリ）。null ならディスク保存をしない
  final Directory? cacheDir;

  static const Map<String, String> _ua = {
    'User-Agent': 'livecam-jp/$appVersion (iOS app)',
  };

  File? get _file =>
      cacheDir == null ? null : File('${cacheDir!.path}/$_cacheName');

  Future<StockpileProducts?> _readDisk() async {
    try {
      final f = _file;
      if (f == null || !await f.exists()) return null;
      return StockpileProducts.fromJson(
        jsonDecode(await f.readAsString()) as Map<String, dynamic>,
      );
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
    } catch (_) {
      // 一時ディレクトリに書けなくても表示には影響しない
    }
  }

  Future<StockpileProducts?> _fetch() async {
    try {
      final r = await _client
          .get(Uri.parse(url), headers: _ua)
          .timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) return null;
      final raw = utf8.decode(r.bodyBytes);
      final p = StockpileProducts.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      if (p != null) await _writeDisk(raw);
      return p;
    } catch (_) {
      return null;
    }
  }

  /// ネットワーク優先で取得し、失敗したらディスクの控えを返す。
  /// どちらも無ければ null（画面はアプリ内の検索語にフォールバックする）
  Future<StockpileProducts?> load() async =>
      await _fetch() ?? await _readDisk();
}
