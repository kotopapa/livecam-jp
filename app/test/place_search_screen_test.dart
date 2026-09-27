import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n_test_app.dart';
import 'package:livecam_jp/app_state.dart';
import 'package:livecam_jp/data/api_client.dart';
import 'package:livecam_jp/data/cache_store.dart';
import 'package:livecam_jp/data/camera_repository.dart';
import 'package:livecam_jp/data/places_search.dart';
import 'package:livecam_jp/models/camera.dart';
import 'package:livecam_jp/ui/place_search_screen.dart';

const _center = LatLng(35.0, 139.0);

Camera cam(String id, String name, {double lat = 35.01, double lng = 139.01}) =>
    Camera(
      id: id,
      name: name,
      category: 'scenic',
      prefecture: '13',
      feed: const Feed(type: FeedType.mlitRoadinfo, url: 'u', cameraRef: 'r'),
      operator: 'テスト運営者',
      attribution: 'x',
      lat: lat,
      lng: lng,
      coordAccuracy: CoordAccuracy.exact,
    );

Future<AppState> buildApp() async {
  final app = AppState(
    CameraRepository(
      api: ApiClient(client: MockClient((_) async => http.Response('x', 404))),
      cache: CacheStore(Directory(Directory.systemTemp.path)),
    ),
  );
  return app;
}

/// [PlaceSearchScreen] を push し、結果（Navigator.pop の戻り値）を追える
/// テスト用の入れ物
class SearchHarness {
  SearchHarness(this.result);
  PlaceSearchResult? result;
}

Future<SearchHarness> pushSearch(
  WidgetTester tester, {
  required AppState app,
  required List<Camera> Function(String) searchCameras,
  Future<List<PlacePrediction>?> Function(
    String, {
    LatLng? bias,
    String languageCode,
    required String sessionToken,
  })?
  autocomplete,
  Future<LatLng?> Function(String, {required String sessionToken})? details,
  Future<List<(String, LatLng)>?> Function(
    String, {
    LatLng? bias,
    String languageCode,
  })?
  textSearch,
  Future<List<(String, LatLng)>> Function(String)? addressSearch,
}) async {
  final harness = SearchHarness(null);
  await tester.pumpWidget(
    testApp(
      Builder(
        builder: (context) {
          return ElevatedButton(
            onPressed: () async {
              harness.result = await Navigator.of(context)
                  .push<PlaceSearchResult>(
                    MaterialPageRoute(
                      builder: (_) => PlaceSearchScreen(
                        app: app,
                        center: _center,
                        searchCameras: searchCameras,
                        autocomplete:
                            autocomplete ??
                            (
                              String q, {
                              LatLng? bias,
                              String languageCode = 'ja',
                              required String sessionToken,
                            }) async => null,
                        details:
                            details ??
                            (String id, {required String sessionToken}) async =>
                                null,
                        textSearch:
                            textSearch ??
                            (
                              String q, {
                              LatLng? bias,
                              String languageCode = 'ja',
                            }) async => null,
                        addressSearch:
                            addressSearch ?? (String q) async => const [],
                      ),
                    ),
                  );
            },
            child: const Text('open'),
          );
        },
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return harness;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('入力すると台帳のカメラ候補が最大5件、ラベル・オペレータが出る', (tester) async {
    final app = await buildApp();
    final harness = await pushSearch(
      tester,
      app: app,
      searchCameras: (q) => [
        for (var i = 0; i < 8; i++) cam('c$i', '$q カメラ$i'),
      ],
    );

    await tester.enterText(find.byKey(const Key('place_search_field')), '渋谷');
    await tester.pump();

    // 8件マッチしても表示は5件まで
    expect(find.textContaining('渋谷 カメラ'), findsNWidgets(5));
    expect(find.textContaining('テスト運営者'), findsWidgets);
    expect(harness.result, isNull);
  });

  testWidgets('入力中のオートコンプリート候補が300msデバウンス後に行として出る', (tester) async {
    final app = await buildApp();
    var calls = 0;
    await pushSearch(
      tester,
      app: app,
      searchCameras: (_) => const [],
      autocomplete:
          (q, {bias, languageCode = 'ja', required String sessionToken}) async {
            calls++;
            expect(sessionToken, isNotEmpty);
            return [
              const PlacePrediction(
                placeId: 'p1',
                mainText: '横浜駅',
                secondaryText: '神奈川県横浜市西区',
                distanceMeters: 850,
                types: ['train_station'],
              ),
            ];
          },
    );

    await tester.enterText(find.byKey(const Key('place_search_field')), '横浜');
    await tester.pump();
    expect(find.text('横浜駅'), findsNothing, reason: 'デバウンス中はまだ出ない');

    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('横浜駅'), findsOneWidget);
    expect(find.text('神奈川県横浜市西区'), findsOneWidget);
    expect(find.text('850 m'), findsOneWidget);
  });

  testWidgets('↖ ボタンは候補の文字を入力欄に入れるだけで確定しない', (tester) async {
    final app = await buildApp();
    final harness = await pushSearch(
      tester,
      app: app,
      searchCameras: (_) => const [],
      autocomplete:
          (
            q, {
            bias,
            languageCode = 'ja',
            required String sessionToken,
          }) async => [
            const PlacePrediction(
              placeId: 'p1',
              mainText: '横浜駅',
              secondaryText: '',
            ),
          ],
    );

    await tester.enterText(find.byKey(const Key('place_search_field')), '横浜');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.north_west));
    await tester.pump();

    expect(find.text('横浜駅'), findsWidgets); // 入力欄とタイトルの両方に出る
    final field = tester.widget<TextField>(
      find.byKey(const Key('place_search_field')),
    );
    expect(field.controller!.text, '横浜駅');
    expect(harness.result, isNull, reason: '確定はしない');
  });

  testWidgets('候補（場所）をタップすると details で座標を取り PlacePickResult で戻る', (
    tester,
  ) async {
    final app = await buildApp();
    final harness = await pushSearch(
      tester,
      app: app,
      searchCameras: (_) => const [],
      autocomplete:
          (
            q, {
            bias,
            languageCode = 'ja',
            required String sessionToken,
          }) async => [
            const PlacePrediction(
              placeId: 'p1',
              mainText: '横浜駅',
              secondaryText: '神奈川県',
            ),
          ],
      details: (id, {required String sessionToken}) async {
        expect(id, 'p1');
        return const LatLng(35.4657, 139.622);
      },
    );

    await tester.enterText(find.byKey(const Key('place_search_field')), '横浜');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    await tester.tap(find.text('横浜駅'));
    await tester.pumpAndSettle();

    final result = harness.result;
    expect(result, isA<PlacePickResult>());
    expect((result as PlacePickResult).point, const LatLng(35.4657, 139.622));
    expect(result.label, '横浜駅（神奈川県）');
  });

  testWidgets('カメラ候補をタップすると CameraPickResult で戻る', (tester) async {
    final app = await buildApp();
    final target = cam('a', '渋谷カメラ');
    final harness = await pushSearch(
      tester,
      app: app,
      searchCameras: (q) => [target],
    );

    await tester.enterText(find.byKey(const Key('place_search_field')), '渋谷');
    await tester.pump();

    await tester.tap(find.text('渋谷カメラ'));
    await tester.pumpAndSettle();

    final result = harness.result;
    expect(result, isA<CameraPickResult>());
    expect((result as CameraPickResult).camera.id, 'a');
  });

  testWidgets('入力が空のとき、保存済みの最近の検索が時計アイコンで出る', (tester) async {
    SharedPreferences.setMockInitialValues({
      'recent_place_searches': [
        '{"type":"place","label":"横浜駅（神奈川県）","lat":35.4657,"lng":139.622}',
      ],
    });
    final app = await buildApp();
    await pushSearch(tester, app: app, searchCameras: (_) => const []);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.history), findsOneWidget);
    expect(find.text('横浜駅（神奈川県）'), findsOneWidget);
  });

  testWidgets('入力が空で最近の検索も無ければ何も表示しない', (tester) async {
    final app = await buildApp();
    await pushSearch(tester, app: app, searchCameras: (_) => const []);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.history), findsNothing);
  });

  testWidgets('クリアボタンで入力を消せる', (tester) async {
    final app = await buildApp();
    await pushSearch(tester, app: app, searchCameras: (_) => const []);

    await tester.enterText(find.byKey(const Key('place_search_field')), 'test');
    await tester.pump();
    expect(find.byKey(const Key('place_search_clear')), findsOneWidget);

    await tester.tap(find.byKey(const Key('place_search_clear')));
    await tester.pump();
    final field = tester.widget<TextField>(
      find.byKey(const Key('place_search_field')),
    );
    expect(field.controller!.text, isEmpty);
    expect(find.byKey(const Key('place_search_clear')), findsNothing);
  });

  testWidgets('戻るボタンは null で pop する', (tester) async {
    final app = await buildApp();
    final harness = await pushSearch(
      tester,
      app: app,
      searchCameras: (_) => const [],
    );

    await tester.tap(find.byKey(const Key('place_search_back')));
    await tester.pumpAndSettle();

    expect(harness.result, isNull);
    expect(find.text('open'), findsOneWidget, reason: '元の画面に戻っている');
  });

  testWidgets('キーボードの検索確定で textSearch の結果を表示し、選ぶと確定する', (tester) async {
    final app = await buildApp();
    final harness = await pushSearch(
      tester,
      app: app,
      searchCameras: (_) => const [],
      textSearch: (q, {bias, languageCode = 'ja'}) async => [
        ('富士山', const LatLng(35.36, 138.73)),
      ],
    );

    await tester.enterText(find.byKey(const Key('place_search_field')), '富士山');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('富士山'), findsWidgets);
    await tester.tap(find.text('富士山').last);
    await tester.pumpAndSettle();

    final result = harness.result;
    expect(result, isA<PlacePickResult>());
    expect((result as PlacePickResult).point, const LatLng(35.36, 138.73));
  });

  testWidgets('textSearch が null(失敗)なら addressSearch へフォールバックする', (
    tester,
  ) async {
    final app = await buildApp();
    var addressCalls = 0;
    await pushSearch(
      tester,
      app: app,
      searchCameras: (_) => const [],
      textSearch: (q, {bias, languageCode = 'ja'}) async => null,
      addressSearch: (q) async {
        addressCalls++;
        return [('富士山（山梨県）', const LatLng(35.36, 138.73))];
      },
    );

    await tester.enterText(find.byKey(const Key('place_search_field')), '富士山');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(addressCalls, 1);
    expect(find.text('富士山（山梨県）'), findsOneWidget);
  });

  testWidgets('確定検索が0件なら見つかりませんを表示する', (tester) async {
    final app = await buildApp();
    await pushSearch(
      tester,
      app: app,
      searchCameras: (_) => const [],
      textSearch: (q, {bias, languageCode = 'ja'}) async => null,
      addressSearch: (q) async => const [],
    );

    await tester.enterText(
      find.byKey(const Key('place_search_field')),
      '存在しない場所xyz',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.textContaining('見つかりませんでした'), findsOneWidget);
  });
}
