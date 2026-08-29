import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../app_state.dart';
import '../config.dart';
import '../models/camera.dart';
import 'detail_screen.dart';
import 'pin_style.dart';

enum _RankMode { day, recent, favorites }

/// 全国ランキング画面。全ユーザーの匿名統計（GitHub Pagesの静的JSON）に基づく。
/// 個人の履歴ではなく全国共通のランキングを表示する（毎日1回更新）。
class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key, required this.app});

  final AppState app;

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  _RankMode _mode = _RankMode.day;
  Map<String, List<(String, int)>>? _data; // key -> [(cameraId, count)]
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await http
          .get(Uri.parse('${apiBaseUrl}ranking.json'))
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode == 404) {
        _error = '全国ランキングは準備中です。\n集計は3時間おきに行われます。';
      } else if (resp.statusCode != 200) {
        _error = '取得に失敗しました (HTTP ${resp.statusCode})';
      } else {
        final body =
            jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
        List<(String, int)> parse(String key, String countKey) => [
              for (final e in (body[key] as List? ?? const [])
                  .cast<Map<String, dynamic>>())
                (e['id'] as String, e[countKey] as int),
            ];
        _data = {
          'day': parse('day', 'day'),
          'recent': parse('recent', 'recent'),
          'favorites': parse('favorites', 'count'),
        };
      }
    } catch (_) {
      _error = '取得に失敗しました';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<(Camera, String)> _ranked() {
    final byId = {for (final c in widget.app.repository.cameras) c.id: c};
    final key = switch (_mode) {
      _RankMode.day => 'day',
      _RankMode.recent => 'recent',
      _RankMode.favorites => 'favorites',
    };
    final unit = _mode == _RankMode.favorites ? '件' : '回';
    return [
      for (final (id, n) in _data?[key] ?? const <(String, int)>[])
        if (byId[id] != null) (byId[id]!, '$n$unit'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final ranked = _ranked();
    return Scaffold(
      appBar: AppBar(
        title: const Text('全国ランキング'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Wrap(spacing: 8, children: [
            ChoiceChip(
              label: const Text('いま見られている（24時間 TOP10）'),
              selected: _mode == _RankMode.day,
              onSelected: (_) => setState(() => _mode = _RankMode.day),
            ),
            ChoiceChip(
              label: const Text('よく見られている（7日間 TOP30）'),
              selected: _mode == _RankMode.recent,
              onSelected: (_) => setState(() => _mode = _RankMode.recent),
            ),
            ChoiceChip(
              label: const Text('お気に入り登録数'),
              selected: _mode == _RankMode.favorites,
              onSelected: (_) => setState(() => _mode = _RankMode.favorites),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: Text(
            '全ユーザーの匿名統計に基づくランキングです（毎日更新）',
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(_error!, textAlign: TextAlign.center),
                      ),
                    )
                  : ranked.isEmpty
                      ? const Center(
                          child: Text('まだ集計データがありません（毎日1回更新されます）'))
                      : ListView.separated(
                          itemCount: ranked.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final (camera, label) = ranked[i];
                            final url = widget.app.imageUrlFor(camera);
                            return ListTile(
                              leading: SizedBox(
                                width: 88,
                                child: Row(children: [
                                  SizedBox(
                                    width: 24,
                                    child: Text('${i + 1}',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: i < 3
                                                ? const Color(0xFFF29900)
                                                : Colors.grey[600])),
                                  ),
                                  const SizedBox(width: 4),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: SizedBox(
                                      width: 60,
                                      height: 40,
                                      child: url != null
                                          ? Image.network(url,
                                              fit: BoxFit.cover,
                                              // 60×40表示への縮小デコード
                                              cacheWidth: 180,
                                              errorBuilder: (_, _, _) =>
                                                  Container(
                                                      color: Colors.grey[300]))
                                          : Container(
                                              color: Colors.grey[300],
                                              child: Icon(Icons.videocam,
                                                  size: 16,
                                                  color: Colors.grey[600])),
                                    ),
                                  ),
                                ]),
                              ),
                              title: Text(camera.name,
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text(
                                [if (camera.isVideo) 'LIVE', camera.operator]
                                    .join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: Text(label,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: categoryColor(camera.category),
                                      fontWeight: FontWeight.bold)),
                              onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => DetailScreen(
                                          camera: camera, app: widget.app))),
                            );
                          },
                        ),
        ),
      ]),
    );
  }
}
