import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:livecam_jp/data/stockpile.dart';
import 'package:livecam_jp/data/stockpile_products.dart';

/// 配信JSONの実体（`data/stockpile/products.json`）。
/// テストは `app/` を作業ディレクトリとして走る
File get _deliveredFile => File('../data/stockpile/products.json');

Map<String, dynamic> _sample({
  List<Map<String, dynamic>>? items,
  String version = '2026-09-01T00:00:00Z',
}) =>
    {
      'version': version,
      'notice': '商品リンクにはアフィリエイトプログラムを利用しています。',
      'disclaimer': '推奨・保証するものではありません。',
      'cert_note': 'cert が無いことは非認定を意味しない。',
      'sources': [
        {'name': '内閣府', 'url': 'https://www.bousai.go.jp/'},
      ],
      'categories': [
        {
          'key': 'waterFood',
          'name': '水・食料',
          'items': items ??
              [
                {
                  'id': 'water',
                  'name': '長期保存水',
                  'spec': '500ml×24本 / 保存5年',
                  'why': '1人1日3L・3日分',
                  'sources': [
                    {'name': '農林水産省', 'url': 'https://www.maff.go.jp/'},
                  ],
                  'search': {
                    'yahoo': '保存水 5年 ヤフー',
                    'rakuten': '保存水 5年 楽天',
                  },
                  'products': [
                    {
                      'shop': 'official',
                      'title': '富士ミネラルウォーター 非常用5年保存水',
                      'url': 'https://www.fujimineral.jp/products/hijou/',
                      'checked_at': '2026-09-01',
                    },
                  ],
                  'cert': {
                    'name': '防災製品等推奨品',
                    'url': 'https://www.bousai-anzen.com/',
                  },
                },
              ],
        },
      ],
    };

void main() {
  group('StockpileProducts.fromJson', () {
    test('カテゴリを畳んで品目IDで引けるようにする', () {
      final p = StockpileProducts.fromJson(_sample())!;
      expect(p.version, '2026-09-01T00:00:00Z');
      expect(p.byItemId.keys, ['water']);
      final g = p.guideFor('water')!;
      expect(g.name, '長期保存水');
      expect(g.spec, contains('5年'));
      expect(g.sources.single.url, 'https://www.maff.go.jp/');
      expect(g.products.single.checkedAt, '2026-09-01');
      expect(g.cert!.name, '防災製品等推奨品');
    });

    test('品目が1件も無ければ null（空のシートを開かせない）', () {
      expect(StockpileProducts.fromJson({'version': 'x'}), isNull);
      expect(
          StockpileProducts.fromJson({
            'categories': [
              {'key': 'waterFood', 'items': []}
            ]
          }),
          isNull);
    });

    test('壊れた要素は落として残りを読む', () {
      final p = StockpileProducts.fromJson(_sample(items: [
        {'name': 'IDが無い'},
        {
          'id': 'water',
          'sources': [
            {'name': '出典だけでURLが無い'},
            {'name': 'ok', 'url': 'https://example.com/'},
          ],
          'products': [
            {'title': 'URLが無い商品'},
            {'title': 'javascript は弾く', 'url': 'javascript:alert(1)'},
            {'title': 'ok', 'url': 'https://example.com/p'},
          ],
        },
      ]))!;
      final g = p.guideFor('water')!;
      expect(p.byItemId.length, 1);
      expect(g.sources.single.name, 'ok');
      expect(g.products.single.url, 'https://example.com/p');
      expect(g.cert, isNull);
    });
  });

  group('keywordFor', () {
    test('店舗ごとの検索語を返す', () {
      final g = StockpileProducts.fromJson(_sample())!.guideFor('water')!;
      expect(g.keywordFor('yahoo'), '保存水 5年 ヤフー');
      expect(g.keywordFor('rakuten'), '保存水 5年 楽天');
    });

    test('その店舗の検索語が無ければ他店舗の語で代用する', () {
      final g = StockpileProducts.fromJson(_sample())!.guideFor('water')!;
      expect(g.keywordFor('amazon'), isNotNull);
    });

    test('検索語が空なら null（アプリ内の既定語にフォールバックさせる）', () {
      final p = StockpileProducts.fromJson(_sample(items: [
        {
          'id': 'water',
          'search': {'yahoo': '   '},
        },
      ]))!;
      expect(p.guideFor('water')!.keywordFor('yahoo'), isNull);
    });
  });

  group('StockpileProductsRepository', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('stockpile_test'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('取得したJSONを控えに書き、次はオフラインでも読める', () async {
      final body = jsonEncode(_sample());
      final online = StockpileProductsRepository(
        cacheDir: dir,
        client: MockClient((req) async {
          expect(req.url.toString(), StockpileProductsRepository.url);
          return http.Response(body, 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }),
      );
      expect((await online.load())!.guideFor('water'), isNotNull);

      final offline = StockpileProductsRepository(
        cacheDir: dir,
        client: MockClient((_) async => http.Response('', 503)),
      );
      expect((await offline.load())!.guideFor('water'), isNotNull);
    });

    test('控えが無くネットワークも失敗したら null（画面は既定語で動く）', () async {
      final repo = StockpileProductsRepository(
        cacheDir: dir,
        client: MockClient((_) async => http.Response('nope', 404)),
      );
      expect(await repo.load(), isNull);
    });

    test('壊れたJSONを控えに残さない', () async {
      final repo = StockpileProductsRepository(
        cacheDir: dir,
        client: MockClient((_) async => http.Response('{ not json', 200)),
      );
      expect(await repo.load(), isNull);
      expect(File('${dir.path}/stockpile_products.json').existsSync(), isFalse);
    });

    test('cacheDir が無くても取得できる（控えを作らないだけ）', () async {
      final repo = StockpileProductsRepository(
        client: MockClient((_) async => http.Response(jsonEncode(_sample()), 200,
            headers: {'content-type': 'application/json; charset=utf-8'})),
      );
      expect((await repo.load())!.guideFor('water'), isNotNull);
    });
  });

  group('配信データ data/stockpile/products.json', () {
    test('アプリの既定品目がすべて解説を持っている', () {
      if (!_deliveredFile.existsSync()) {
        markTestSkipped('配信データが無い環境（app単独チェックアウト）');
        return;
      }
      final p = StockpileProducts.fromJson(
          jsonDecode(_deliveredFile.readAsStringSync()) as Map<String, dynamic>);
      expect(p, isNotNull, reason: '配信JSONが読めない＝スキーマが変わった');

      final missing = [
        for (final spec in defaultStockpileItems)
          if (p!.guideFor(spec.id) == null) spec.id
      ];
      expect(missing, isEmpty, reason: '解説の無い品目: $missing');
    });

    test('全品目に検索語と出典があり、商品URLはhttpsで価格を持たない', () {
      if (!_deliveredFile.existsSync()) {
        markTestSkipped('配信データが無い環境（app単独チェックアウト）');
        return;
      }
      final raw =
          jsonDecode(_deliveredFile.readAsStringSync()) as Map<String, dynamic>;
      final p = StockpileProducts.fromJson(raw)!;
      for (final g in p.byItemId.values) {
        expect(g.keywordFor('yahoo'), isNotNull, reason: '${g.id} に検索語が無い');
        expect(g.why, isNotEmpty, reason: '${g.id} に選ぶ根拠が無い');
        expect(g.sources, isNotEmpty, reason: '${g.id} に出典が無い');
        for (final pr in g.products) {
          expect(pr.url, startsWith('https://'), reason: '${g.id}: ${pr.url}');
          expect(pr.checkedAt, isNotNull, reason: '${g.id}: 生存確認日が無い');
        }
      }
      // 価格は陳腐化するので配信しない（tools/stockpile_check.py も入れない）
      expect(jsonEncode(raw).contains('"price"'), isFalse);
    });
  });
}
