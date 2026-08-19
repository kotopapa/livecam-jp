import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../app_state.dart';
import '../config.dart';
import '../models/camera.dart';
import 'detail_screen.dart';
import 'pin_style.dart';

enum _RankMode { everyone, recent, total, favorites }

/// ランキング画面。統計はすべて端末内の履歴に基づく（サーバー集計はしない）。
class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key, required this.app});

  final AppState app;

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  _RankMode _mode = _RankMode.everyone;
  List<(String, int)>? _globalRecent; // (cameraId, 直近7日回数)
  bool _globalLoading = false;
  String? _globalError;

  @override
  void initState() {
    super.initState();
    _loadGlobal();
  }

  Future<void> _loadGlobal() async {
    if (_globalLoading) return;
    setState(() {
      _globalLoading = true;
      _globalError = null;
    });
    try {
      final resp = await http
          .get(Uri.parse('${apiBaseUrl}ranking.json'))
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode == 404) {
        _globalError = '全国ランキングは準備中です（集計データがまだありません）';
      } else if (resp.statusCode != 200) {
        _globalError = '取得に失敗しました (HTTP ${resp.statusCode})';
      } else {
        final body = jsonDecode(utf8.decode(resp.bodyBytes))
            as Map<String, dynamic>;
        _globalRecent = [
          for (final e in (body['recent'] as List).cast<Map<String, dynamic>>())
            (e['id'] as String, e['recent'] as int),
        ];
      }
    } catch (e) {
      _globalError = '取得に失敗しました';
    } finally {
      if (mounted) setState(() => _globalLoading = false);
    }
  }

  List<(Camera, String)> _ranked() {
    final app = widget.app;
    final byId = {for (final c in app.repository.cameras) c.id: c};
    switch (_mode) {
      case _RankMode.everyone:
        return [
          for (final (id, n) in _globalRecent ?? const <(String, int)>[])
            if (byId[id] != null) (byId[id]!, '$n回'),
        ];
      case _RankMode.recent:
      case _RankMode.total:
        final counts = <String, int>{};
        for (final id in app.viewHistory.viewedIds) {
          final n = _mode == _RankMode.recent
              ? app.viewHistory.recentCount(id, days: 3)
              : app.viewHistory.totalCount(id);
          if (n > 0) counts[id] = n;
        }
        final ids = counts.keys.toList()
          ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
        return [
          for (final id in ids)
            if (byId[id] != null) (byId[id]!, '${counts[id]}回'),
        ];
      case _RankMode.favorites:
        return [
          for (final id in app.favorites.newestFirst)
            if (byId[id] != null) (byId[id]!, ''),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final ranked = _ranked();
    return Scaffold(
      appBar: AppBar(title: const Text('ランキング')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Wrap(spacing: 8, children: [
            ChoiceChip(
              label: const Text('みんなのランキング'),
              selected: _mode == _RankMode.everyone,
              onSelected: (_) => setState(() => _mode = _RankMode.everyone),
            ),
            ChoiceChip(
              label: const Text('よく見る（3日間）'),
              selected: _mode == _RankMode.recent,
              onSelected: (_) => setState(() => _mode = _RankMode.recent),
            ),
            ChoiceChip(
              label: const Text('よく見る（累計）'),
              selected: _mode == _RankMode.total,
              onSelected: (_) => setState(() => _mode = _RankMode.total),
            ),
            ChoiceChip(
              label: Text('お気に入り登録順（${widget.app.favorites.ids.length}件）'),
              selected: _mode == _RankMode.favorites,
              onSelected: (_) => setState(() => _mode = _RankMode.favorites),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: Text(
            _mode == _RankMode.everyone
                ? '全ユーザーの直近7日間の閲覧に基づくランキングです（毎日更新）'
                : 'この端末での閲覧・登録に基づくランキングです',
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ),
        Expanded(
          child: _mode == _RankMode.everyone && _globalLoading
              ? const Center(child: CircularProgressIndicator())
              : _mode == _RankMode.everyone && _globalError != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(_globalError!, textAlign: TextAlign.center),
                      ),
                    )
              : ranked.isEmpty
              ? Center(child: Text(
                  _mode == _RankMode.everyone
                      ? '全国ランキングは準備中です'
                      : 'まだ履歴がありません。\nカメラの詳細を開くと記録されます。',
                  textAlign: TextAlign.center))
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
                                      errorBuilder: (_, _, _) =>
                                          Container(color: Colors.grey[300]))
                                  : Container(
                                      color: Colors.grey[300],
                                      child: Icon(Icons.videocam,
                                          size: 16, color: Colors.grey[600])),
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
                      trailing: label.isEmpty
                          ? Icon(Icons.star,
                              size: 18, color: Colors.amber[600])
                          : Text(label,
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
