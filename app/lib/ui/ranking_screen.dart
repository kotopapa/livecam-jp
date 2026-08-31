import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../app_state.dart';
import '../l10n/l10n.dart';
import '../config.dart';
import '../models/camera.dart';
import 'ad_banner.dart';
import 'detail_screen.dart';
import 'pin_style.dart';

enum _RankMode { day, recent, favorites }

/// ランキング取得のエラー種別（文言は表示時に l10n で解決する）
enum _RankError { preparing, http, failed }

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
  /// エラーの種類（文言は build 時に l10n で解決する）
  _RankError? _error;
  int _errorHttpCode = 0;

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
        _error = _RankError.preparing;
      } else if (resp.statusCode != 200) {
        _error = _RankError.http;
        _errorHttpCode = resp.statusCode;
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
      _error = _RankError.failed;
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
    final l10n = context.l10n;
    final unit = _mode == _RankMode.favorites
        ? l10n.rankingUnitFavorites
        : l10n.rankingUnitViews;
    return [
      for (final (id, n) in _data?[key] ?? const <(String, int)>[])
        if (byId[id] != null) (byId[id]!, '$n$unit'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ranked = _ranked();
    final errorText = switch (_error) {
      null => null,
      _RankError.preparing => l10n.rankingPreparing,
      _RankError.http => l10n.rankingFetchFailedHttp(_errorHttpCode),
      _RankError.failed => l10n.rankingFetchFailed,
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.rankingTitle),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      bottomNavigationBar: AdFooter(app: widget.app),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Wrap(spacing: 8, children: [
            ChoiceChip(
              label: Text(l10n.rankingModeNow),
              selected: _mode == _RankMode.day,
              onSelected: (_) => setState(() => _mode = _RankMode.day),
            ),
            ChoiceChip(
              label: Text(l10n.rankingModeWeek),
              selected: _mode == _RankMode.recent,
              onSelected: (_) => setState(() => _mode = _RankMode.recent),
            ),
            ChoiceChip(
              label: Text(l10n.rankingModeFavorites),
              selected: _mode == _RankMode.favorites,
              onSelected: (_) => setState(() => _mode = _RankMode.favorites),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: Text(
            l10n.rankingNote,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : errorText != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(errorText, textAlign: TextAlign.center),
                      ),
                    )
                  : ranked.isEmpty
                      ? Center(child: Text(l10n.rankingEmpty))
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
