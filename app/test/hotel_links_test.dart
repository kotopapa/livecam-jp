import 'package:flutter_test/flutter_test.dart';
import 'package:livecam_jp/config.dart';
import 'package:livecam_jp/data/hotel_links.dart';
import 'package:livecam_jp/models/camera.dart';

Camera _cam({
  String category = 'scenic',
  String prefecture = '19',
  String? municipality = '19430',
  double? lat = 35.5036,
  double? lng = 138.7648,
}) => Camera.tryParse({
  'id': 'x',
  'name': 'x',
  'category': category,
  'prefecture': prefecture,
  'lat': lat,
  'lng': lng,
  'municipality': municipality,
  'feed': {'type': 'still_image', 'url': 'https://example.com/a.jpg'},
  'source': {'page_url': 'https://example.com', 'license': 'unknown'},
  'review': {'status': 'approved'},
})!;

final _checkIn = DateTime(2026, 10, 10);
const _kw = '%95x%8Em%89%CD%8C%FB%8C%CE%92%AC'; // 富士河口湖町 (Shift_JIS)

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('URL組み立て（2026-09-03 実測値と一致）', () {
    test('楽天トラベル: 日本測地系の秒に変換し、明日から1泊の必須日付を付ける', () {
      final (ido, kdo) = HotelLinks.tokyoDatumSeconds(35.5036, 138.7648);
      expect(ido, 127801.33);
      expect(kdo, 499564.5);
      final u = HotelLinks.rakutenTravelUrl(35.5036, 138.7648, checkIn: _checkIn);
      expect(u.host, 'search.travel.rakuten.co.jp');
      expect(u.path, '/ds/vacant/searchVacant');
      final q = u.queryParameters;
      expect(q['f_ido'], '127801.33');
      expect(q['f_kdo'], '499564.5');
      expect(q['f_landmark_name_id'], 'APP_NGPS');
      expect(q['f_km'], '3.0');
      expect(q['f_nen1'], '2026');
      expect(q['f_tuki1'], '10');
      expect(q['f_hi1'], '10');
      expect(q['f_hi2'], '11');
      expect(q['f_otona_su'], '1');
    });

    test('楽天トラベル: 月末のチェックアウトは翌月になる', () {
      final u = HotelLinks.rakutenTravelUrl(35.0, 139.0,
          checkIn: DateTime(2026, 12, 31));
      final q = u.queryParameters;
      expect(q['f_nen2'], '2027');
      expect(q['f_tuki2'], '1');
      expect(q['f_hi2'], '1');
    });

    test('JTB: 県パス＋座標＋距離順。県が引けなければ null', () {
      final u = HotelLinks.jtbUrl(35.5036, 138.7648, '19')!;
      expect(u.toString(), startsWith('https://www.jtb.co.jp/kokunai-hotel/list/yamanashi/?'));
      final q = u.queryParameters;
      expect(q['lat'], '35.50360');
      expect(q['lng'], '138.76480');
      expect(q['sort'], 'location');
      expect(q['dateunspecified'], '1');
      expect(HotelLinks.jtbUrl(35.0, 139.0, '99'), isNull);
      expect(HotelLinks.jtbPrefSlugs.length, 47);
      expect(HotelLinks.jtbPrefSlugs['47'], 'okinawa');
    });

    test('じゃらん: Shift_JIS エンコード済みの検索語を二重エンコードしない', () {
      final u = HotelLinks.jalanUrl(_kw);
      expect(u.toString(),
          'https://www.jalan.net/uw/uwp2011/uww2011init.do?keyword=$_kw');
    });

    test('Expedia: latLong', () {
      final u = HotelLinks.expediaUrl(48.8584, 2.2945);
      expect(u.host, 'www.expedia.co.jp');
      expect(u.queryParameters['latLong'], '48.85840,2.29450');
    });
  });

  group('linksFor', () {
    test('国内の観光系カメラ: じゃらん・楽天トラベル・JTB の順。アフィリエイトだけリファラルで包む', () {
      final links = HotelLinks.linksFor(_cam(), checkIn: _checkIn, jalanKeyword: _kw);
      expect(links.map((l) => l.site.key), ['jalan', 'rakuten_travel', 'jtb']);
      final jalan = links[0].url;
      expect(jalan.host, 'ck.jp.ap.valuecommerce.com');
      expect(jalan.queryParameters['sid'], vcSid);
      expect(jalan.queryParameters['pid'], '892691492');
      expect(jalan.queryParameters['vc_url'],
          'https://www.jalan.net/uw/uwp2011/uww2011init.do?keyword=$_kw');
      // vc_url は「?」「=」「%」まで含めて全体がエンコードされている
      expect(jalan.toString(), contains('vc_url=https%3A%2F%2Fwww.jalan.net%2Fuw%2Fuwp2011%2Fuww2011init.do%3Fkeyword%3D%2595x'));
      expect(links[1].url.host, 'search.travel.rakuten.co.jp'); // アフィリエイト無し
      expect(links[2].url.host, 'ck.jp.ap.valuecommerce.com');
      expect(links[2].url.queryParameters['pid'], '892691495');
    });

    test('じゃらんの検索語が無ければじゃらんだけ落ちる', () {
      final links = HotelLinks.linksFor(_cam(), checkIn: _checkIn);
      expect(links.map((l) => l.site.key), ['rakuten_travel', 'jtb']);
    });

    test('河川・道路・ダムの防災カメラには出さない', () {
      for (final c in ['river', 'road', 'dam', 'port', 'other']) {
        expect(HotelLinks.linksFor(_cam(category: c), checkIn: _checkIn, jalanKeyword: _kw),
            isEmpty, reason: c);
      }
      for (final c in ['scenic', 'coast', 'volcano', 'healing']) {
        expect(HotelLinks.eligible(_cam(category: c)), isTrue, reason: c);
      }
    });

    test('座標が無ければ出さない', () {
      expect(HotelLinks.linksFor(_cam(lat: null, lng: null), checkIn: _checkIn), isEmpty);
    });

    test('海外カメラは Expedia だけ（カテゴリ不問）', () {
      final links = HotelLinks.linksFor(
          _cam(category: 'other', prefecture: '99', municipality: null, lat: 48.8584, lng: 2.2945),
          checkIn: _checkIn);
      expect(links.map((l) => l.site.key), ['expedia']);
      expect(links[0].url.queryParameters['pid'], '892691493');
      expect(links[0].url.queryParameters['vc_url'], contains('expedia.co.jp/Hotel-Search'));
    });

    test('配信フラグで無効にしたサイトは出ない（有効化も同じ経路）', () {
      final sites = HotelLinks.sitesWith({'jalan': false, 'jtb': false});
      final links = HotelLinks.linksFor(_cam(), checkIn: _checkIn, jalanKeyword: _kw, sites: sites);
      expect(links.map((l) => l.site.key), ['rakuten_travel']);
      final on = HotelLinks.sitesWith({'expedia': true});
      expect(on.firstWhere((s) => s.key == 'expedia').enabled, isTrue);
    });

    test('表示名はロケールで切り替わる', () {
      final s = hotelSites.firstWhere((s) => s.key == 'rakuten_travel');
      expect(s.nameFor('ja'), '楽天トラベル');
      expect(s.nameFor('en'), 'Rakuten Travel');
      expect(s.isAffiliate, isFalse);
    });
  });

  group('MunicipalityNames', () {
    test('同梱アセットを読み、Shift_JIS の検索語を返す', () async {
      MunicipalityNames.setTable(null);
      await MunicipalityNames.load();
      expect(MunicipalityNames.isLoaded, isTrue);
      expect(MunicipalityNames.nameOf('47207'), '石垣市');
      expect(MunicipalityNames.sjisKeywordOf('47207'), '%90%CE%8A_%8Es');
      expect(MunicipalityNames.sjisKeywordOf('19430'), _kw);
    });

    test('政令市の区は市に丸める。不明・不正なコードは null', () {
      MunicipalityNames.setTable({
        '14100': ['横浜市', '%89%A1%95l%8Es'],
      });
      expect(MunicipalityNames.nameOf('14104'), '横浜市');
      expect(MunicipalityNames.nameOf('14201'), isNull);
      expect(MunicipalityNames.nameOf(null), isNull);
      expect(MunicipalityNames.nameOf('1410'), isNull);
      MunicipalityNames.setTable(null);
    });
  });
}
