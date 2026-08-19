import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../app_state.dart';
import '../models/camera.dart';
import '../util/geo.dart';
import '../util/prefectures.dart';
import 'detail_screen.dart';

/// 気象庁の公開JSONから直近の地震を表示し、震源周辺のカメラへ誘導する。
/// 無料・認証不要のエンドポイントのみ使用（SPEC C2）。取得はこの画面を
/// 開いたときだけ（ポーリングしない）。
class BosaiScreen extends StatefulWidget {
  const BosaiScreen({super.key, required this.app});

  static const quakeListUrl =
      'https://www.jma.go.jp/bosai/quake/data/list.json';
  static const tsunamiListUrl =
      'https://www.jma.go.jp/bosai/tsunami/data/list.json';
  static const warningMapUrl =
      'https://www.jma.go.jp/bosai/warning/data/warning/map.json';

  final AppState app;

  @override
  State<BosaiScreen> createState() => _BosaiScreenState();
}

class _Quake {
  const _Quake({
    required this.place,
    required this.magnitude,
    required this.maxIntensity,
    required this.at,
    required this.lat,
    required this.lng,
    this.isTsunami = false,
  });

  final String place;
  final String magnitude;
  final String maxIntensity;
  final DateTime at;
  final double lat;
  final double lng;
  final bool isTsunami;
}

/// 気象警報コード → 表示名（警報・特別警報のみ。注意報は対象外）
const _warningNames = {
  '02': '暴風雪警報', '03': '大雨警報', '04': '洪水警報', '05': '暴風警報',
  '06': '大雪警報', '07': '波浪警報', '08': '高潮警報',
  '32': '暴風雪特別警報', '33': '大雨特別警報', '35': '暴風特別警報',
  '36': '大雪特別警報', '37': '波浪特別警報', '38': '高潮特別警報',
};

class _BosaiScreenState extends State<BosaiScreen> {
  List<_Quake>? _quakes;
  String? _error;
  // 都道府県コード → 発表中の警報名セット（特別警報を先頭に）
  Map<String, List<String>>? _warnings;
  String? _warningError;

  @override
  void initState() {
    super.initState();
    _load();
    _loadWarnings();
  }

  Future<void> _loadWarnings() async {
    setState(() {
      _warnings = null;
      _warningError = null;
    });
    try {
      final resp = await http
          .get(Uri.parse(BosaiScreen.warningMapUrl))
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
      final offices = jsonDecode(utf8.decode(resp.bodyBytes)) as List;
      final byPref = <String, Set<String>>{};
      for (final office in offices.cast<Map<String, dynamic>>()) {
        final areaTypes = office['areaTypes'] as List? ?? const [];
        if (areaTypes.isEmpty) continue;
        // 先頭のareaType=府県予報区レベルを使う
        for (final area in (areaTypes.first['areas'] as List? ?? const [])
            .cast<Map<String, dynamic>>()) {
          final code = area['code'] as String? ?? '';
          if (code.length < 2) continue;
          final pref = code.substring(0, 2);
          if (!prefectureNames.containsKey(pref)) continue;
          for (final w in (area['warnings'] as List? ?? const [])
              .cast<Map<String, dynamic>>()) {
            final status = w['status'] as String? ?? '';
            if (status == '解除') continue;
            final name = _warningNames[w['code'] as String? ?? ''];
            if (name != null) {
              byPref.putIfAbsent(pref, () => {}).add(name);
            }
          }
        }
      }
      final result = <String, List<String>>{};
      for (final e in byPref.entries) {
        final list = e.value.toList()
          ..sort((a, b) {
            final ae = a.contains('特別') ? 0 : 1;
            final be = b.contains('特別') ? 0 : 1;
            return ae != be ? ae.compareTo(be) : a.compareTo(b);
          });
        result[e.key] = list;
      }
      if (mounted) setState(() => _warnings = result);
    } catch (e) {
      if (mounted) setState(() => _warningError = '取得に失敗しました');
    }
  }

  // "+37.5+137.2-10000/" 形式の震源座標をパースする
  static final _codRe = RegExp(r'^([+-][\d.]+)([+-][\d.]+)');

  Future<void> _load() async {
    setState(() {
      _quakes = null;
      _error = null;
    });
    try {
      final resp = await http
          .get(Uri.parse(BosaiScreen.quakeListUrl))
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}');
      }
      final list = jsonDecode(utf8.decode(resp.bodyBytes)) as List;
      final since = DateTime.now().subtract(const Duration(hours: 72));
      final seen = <String>{};
      final quakes = <_Quake>[];
      // 津波予報・警報（直近72時間）を先に取り込む
      try {
        final tresp = await http
            .get(Uri.parse(BosaiScreen.tsunamiListUrl))
            .timeout(const Duration(seconds: 15));
        if (tresp.statusCode == 200) {
          for (final e in (jsonDecode(utf8.decode(tresp.bodyBytes)) as List)
              .cast<Map<String, dynamic>>()) {
            final at = DateTime.tryParse(e['at'] as String? ?? '');
            final cod = _codRe.firstMatch(e['cod'] as String? ?? '');
            final eid = 'tsunami-${e['eid']}';
            if (at == null || cod == null || at.isBefore(since)) continue;
            if (!seen.add(eid)) continue;
            quakes.add(_Quake(
              place: '【${e['ttl'] ?? '津波情報'}】${e['anm'] ?? ''}',
              magnitude: e['mag'] as String? ?? '-',
              maxIntensity: '津波',
              at: at,
              lat: double.parse(cod.group(1)!),
              lng: double.parse(cod.group(2)!),
              isTsunami: true,
            ));
          }
        }
      } catch (_) {
        // 津波リストが取れなくても地震は表示する
      }
      for (final e in list.cast<Map<String, dynamic>>()) {
        final at = DateTime.tryParse(e['at'] as String? ?? '');
        final cod = _codRe.firstMatch(e['cod'] as String? ?? '');
        final maxi = e['maxi'] as String? ?? '';
        final eid = e['eid'] as String? ?? '';
        if (at == null || cod == null || maxi.isEmpty) continue;
        if (at.isBefore(since)) continue;
        if (!seen.add(eid)) continue; // 同一地震の続報をまとめる
        quakes.add(_Quake(
          place: e['anm'] as String? ?? '不明',
          magnitude: e['mag'] as String? ?? '-',
          maxIntensity: maxi,
          at: at,
          lat: double.parse(cod.group(1)!),
          lng: double.parse(cod.group(2)!),
        ));
      }
      // 震度の大きい順 → 新しい順
      quakes.sort((a, b) {
        if (a.isTsunami != b.isTsunami) return a.isTsunami ? -1 : 1;
        final ci = _intensityRank(b.maxIntensity)
            .compareTo(_intensityRank(a.maxIntensity));
        return ci != 0 ? ci : b.at.compareTo(a.at);
      });
      if (mounted) setState(() => _quakes = quakes.take(30).toList());
    } catch (e) {
      if (mounted) setState(() => _error = '取得に失敗しました（$e）');
    }
  }

  static int _intensityRank(String maxi) => switch (maxi) {
        '7' => 9,
        '6+' => 8,
        '6-' => 7,
        '5+' => 6,
        '5-' => 5,
        _ => int.tryParse(maxi) ?? 0,
      };

  static Color _intensityColor(String maxi) {
    if (maxi == '津波') return const Color(0xFF1E6FD9);
    return switch (_intensityRank(maxi)) {
      >= 5 => const Color(0xFFD93025),
      >= 3 => const Color(0xFFF29900),
      _ => const Color(0xFF616E7C),
    };
  }

  String _when(DateTime at) {
    final d = DateTime.now().difference(at);
    if (d.inMinutes < 60) return '${d.inMinutes}分前';
    if (d.inHours < 24) return '${d.inHours}時間前';
    return '${at.month}月${at.day}日 ${at.hour}時頃';
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('災害速報'),
          actions: [
            IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  _load();
                  _loadWarnings();
                }),
          ],
          bottom: const TabBar(tabs: [
            Tab(text: '地震・津波'),
            Tab(text: '気象警報'),
          ]),
        ),
        body: TabBarView(children: [
          _buildQuakeTab(),
          _buildWarningTab(),
        ]),
      ),
    );
  }

  Widget _buildQuakeTab() {
    return _error != null
          ? Center(child: Text(_error!))
          : _quakes == null
              ? const Center(child: CircularProgressIndicator())
              : _quakes!.isEmpty
                  ? const Center(child: Text('直近72時間の地震情報はありません'))
                  : ListView.separated(
                      itemCount: _quakes!.length + 1,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              '出典：気象庁 地震情報（直近72時間）。タップすると震源周辺のライブカメラ一覧を表示します。',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[600]),
                            ),
                          );
                        }
                        final q = _quakes![i - 1];
                        return ListTile(
                          leading: Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _intensityColor(q.maxIntensity),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                                q.isTsunami ? '津波' : '震度\n${q.maxIntensity}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    height: 1.2)),
                          ),
                          title: Text(q.place),
                          subtitle: Text(
                              'M${q.magnitude} · ${_when(q.at)}',
                              style: const TextStyle(fontSize: 12)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => NearbyCamerasScreen(
                                app: widget.app,
                                title: '${q.place}周辺のカメラ',
                                lat: q.lat,
                                lng: q.lng,
                              ),
                            ),
                          ),
                        );
                      },
                    );
  }

  Widget _buildWarningTab() {
    if (_warningError != null) return Center(child: Text(_warningError!));
    if (_warnings == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_warnings!.isEmpty) {
      return const Center(child: Text('現在、発表中の警報・特別警報はありません'));
    }
    final prefs = _warnings!.keys.toList()
      ..sort((a, b) {
        final ae = _warnings![a]!.any((w) => w.contains('特別')) ? 0 : 1;
        final be = _warnings![b]!.any((w) => w.contains('特別')) ? 0 : 1;
        return ae != be ? ae.compareTo(be) : a.compareTo(b);
      });
    return ListView.separated(
      itemCount: prefs.length + 1,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              '出典：気象庁 気象警報・注意報（警報・特別警報のみ表示）。タップするとその都道府県のカメラ一覧を表示します。',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          );
        }
        final pref = prefs[i - 1];
        final names = _warnings![pref]!;
        final emergency = names.any((w) => w.contains('特別'));
        return ListTile(
          leading: Icon(
            emergency ? Icons.warning : Icons.warning_amber_outlined,
            color: emergency
                ? const Color(0xFFD93025)
                : const Color(0xFFF29900),
          ),
          title: Text(prefectureNames[pref] ?? pref),
          subtitle: Wrap(spacing: 4, runSpacing: 2, children: [
            for (final n in names)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: n.contains('特別')
                      ? const Color(0xFFD93025)
                      : const Color(0xFFF29900),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(n,
                    style:
                        const TextStyle(color: Colors.white, fontSize: 11)),
              ),
          ]),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => PrefCamerasScreen(
                  app: widget.app,
                  pref: pref,
                  title:
                      '${prefectureNames[pref] ?? pref}のカメラ（警報発表中）'))),
        );
      },
    );
  }
}

/// 都道府県内のカメラ一覧（警報発表時の導線）。
class PrefCamerasScreen extends StatelessWidget {
  const PrefCamerasScreen(
      {super.key, required this.app, required this.pref, required this.title});

  final AppState app;
  final String pref;
  final String title;

  @override
  Widget build(BuildContext context) {
    final cams = app.repository
        .displayableCameras()
        .where((c) => c.prefecture == pref)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return Scaffold(
      appBar: AppBar(title: Text(title, overflow: TextOverflow.ellipsis)),
      body: cams.isEmpty
          ? const Center(child: Text('この都道府県のカメラがありません'))
          : ListView.builder(
              itemCount: cams.length,
              itemBuilder: (context, i) {
                final camera = cams[i];
                final url = app.imageUrlFor(camera);
                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 72,
                      height: 48,
                      child: url != null
                          ? Image.network(url,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  Container(color: Colors.grey[300]))
                          : Container(
                              color: Colors.grey[300],
                              child: Icon(Icons.videocam,
                                  size: 20, color: Colors.grey[600])),
                    ),
                  ),
                  title: Text(camera.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    [if (camera.isVideo) 'LIVE', camera.operator].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) =>
                          DetailScreen(camera: camera, app: app))),
                );
              },
            ),
    );
  }
}

/// 指定地点の周辺カメラ一覧（距離順・50km以内）。
class NearbyCamerasScreen extends StatelessWidget {
  const NearbyCamerasScreen({
    super.key,
    required this.app,
    required this.title,
    required this.lat,
    required this.lng,
  });

  final AppState app;
  final String title;
  final double lat;
  final double lng;

  @override
  Widget build(BuildContext context) {
    final cams = <(Camera, double)>[];
    for (final c in app.repository.displayableCameras()) {
      if (!c.hasLocation) continue;
      final d = distanceMeters(lat, lng, c.lat!, c.lng!);
      if (d <= 50000) cams.add((c, d));
    }
    cams.sort((a, b) => a.$2.compareTo(b.$2));
    return Scaffold(
      appBar: AppBar(title: Text(title, overflow: TextOverflow.ellipsis)),
      body: cams.isEmpty
          ? const Center(child: Text('50km以内にカメラがありません'))
          : ListView.separated(
              itemCount: cams.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final (camera, dist) = cams[i];
                final url = app.imageUrlFor(camera);
                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 72,
                      height: 48,
                      child: url != null
                          ? Image.network(url,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  Container(color: Colors.grey[300]))
                          : Container(
                              color: Colors.grey[300],
                              child: Icon(Icons.videocam,
                                  size: 20, color: Colors.grey[600])),
                    ),
                  ),
                  title: Text(camera.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    [
                      if (camera.isVideo) 'LIVE',
                      '約${(dist / 1000).toStringAsFixed(dist < 10000 ? 1 : 0)}km',
                      camera.operator,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) =>
                          DetailScreen(camera: camera, app: app))),
                );
              },
            ),
    );
  }
}
