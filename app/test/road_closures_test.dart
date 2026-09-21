import 'package:flutter_test/flutter_test.dart';
import 'package:livecam_jp/data/road_closures.dart';
import 'package:livecam_jp/data/road_regulation.dart';
import 'package:livecam_jp/data/underpass.dart';

void main() {
  test('原因の分類: 冠水・土砂・気象・その他', () {
    expect(classifyCause('冠水'), ClosureCause.flood);
    expect(classifyCause('越波'), ClosureCause.flood);
    expect(classifyCause('土砂崩れ'), ClosureCause.landslide);
    expect(classifyCause('道路損壊'), ClosureCause.landslide);
    expect(classifyCause('大雨'), ClosureCause.weather);
    expect(classifyCause('高波'), ClosureCause.weather);
    expect(classifyCause('災害等'), ClosureCause.other);
    expect(classifyCause('事故'), ClosureCause.other);
  });

  test('冠水センサーと国交省の規制を1つに統合する', () {
    final up = UnderpassStatus.parse({
      'version': 'v',
      'sources': [
        {'id': 'saitama', 'name': 'さいたま市', 'operator': 'さいたま市', 'prefecture': '11', 'url': 'https://s', 'attribution': '出典：さいたま市',
         'points': [
           {'id': '1', 'name': '馬込地下道', 'lat': 35.9, 'lng': 139.6, 'level': 2, 'label': '警戒水位超過', 'at': '10:00'},
           {'id': '2', 'name': '宮原町4丁目地下道', 'lat': 35.95, 'lng': 139.6, 'level': 0, 'label': '平常水位', 'at': '10:00'},
         ]},
        {'id': 'shizuoka_pref', 'name': '静岡県', 'operator': '静岡県', 'prefecture': '22', 'url': 'https://p', 'attribution': '出典：静岡県',
         'points': [
           {'id': 'k1', 'name': '国道414号（下田市）', 'lat': 34.6, 'lng': 138.9, 'level': 2, 'label': '冠水による通行規制', 'at': ''},
         ]},
      ],
    });
    final reg = RoadRegulationStatus.parse({
      'version': 'v',
      'sources': [
        {'id': 'mlit', 'name': '国交省', 'url': 'https://m', 'attribution': '出典：国交省', 'items': [
          {'id': 'a', 'name': '国道152号', 'section': '大鹿村', 'cause': '土砂崩れ', 'content': '通行止', 'lat': 35.5, 'lng': 138.0, 'level': 2, 'label': '通行止（土砂崩れ）'},
          {'id': 'b', 'name': '国道1号', 'cause': '越波', 'content': '入口閉鎖', 'lat': 35.0, 'lng': 138.5, 'level': 1, 'label': '入口閉鎖（越波）'},
        ]},
      ],
    });
    final items = RoadClosures.merge(up, reg);
    expect(items.length, 5);
    expect(items.where((i) => i.cause == ClosureCause.flood).length, 4);
    expect(items.firstWhere((i) => i.id == 'mlit:a').cause, ClosureCause.landslide);
    expect(items.firstWhere((i) => i.id == 'saitama:2').level, 0);
    expect(items.firstWhere((i) => i.id == 'saitama:1').isSensor, isTrue);
    expect(items.firstWhere((i) => i.id == 'mlit:b').isSensor, isFalse);
  });
}
