import 'package:flutter_test/flutter_test.dart';
import 'package:livecam_jp/models/camera.dart';

Camera _cam(String? muni) => Camera.tryParse({
      'id': 'x', 'name': 'x', 'category': 'road', 'prefecture': '14',
      'lat': 35.0, 'lng': 139.0, 'municipality': muni,
      'feed': {'type': 'still_image', 'url': 'https://example.com/a.jpg'},
      'source': {'page_url': 'https://example.com', 'license': 'unknown'},
      'review': {'status': 'approved'},
    })!;

void main() {
  test('政令市コードは配下の区を含む', () {
    expect(_cam('14104').inMunicipality('14100'), isTrue); // 横浜市中区
    expect(_cam('14118').inMunicipality('14100'), isTrue); // 都筑区
    expect(_cam('14130').inMunicipality('14100'), isFalse); // 川崎市は別
    expect(_cam('14150').inMunicipality('14130'), isFalse); // 相模原市は川崎の区ではない
    expect(_cam('14131').inMunicipality('14130'), isTrue); // 川崎区
    expect(_cam('14201').inMunicipality('14100'), isFalse); // 横須賀
  });
  test('通常の市は完全一致のみ', () {
    expect(_cam('14201').inMunicipality('14201'), isTrue);
    expect(_cam('14202').inMunicipality('14201'), isFalse);
  });
}
