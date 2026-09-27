/// 地図の検索（Googleマップ風の全画面検索。2026-09-27）。
///
/// 上部の戻る＋入力欄＋クリアのピル、入力中はデバウンス付きの候補リスト
/// （台帳のカメラ名 → Google Places Autocomplete (New)）、キーボードの
/// 「検索」確定時は Google Places Text Search（失敗時は国土地理院
/// AddressSearch）の結果を表示する。入力が空のときは最近の検索を出す。
///
/// 選択結果は [Navigator.pop] の戻り値（[PlaceSearchResult]）で呼び出し側
/// （map_screen.dart）へ返す。地図の移動・ピンの選択動作は呼び出し側が持つ
/// （このウィジェットは地図の状態を知らない）
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_state.dart';
import '../data/analytics.dart';
import '../data/places_search.dart';
import '../l10n/l10n.dart';
import '../models/camera.dart';
import '../util/geo.dart' show distanceMeters;
import 'pin_style.dart';

/// [PlaceSearchScreen] の選択結果
sealed class PlaceSearchResult {}

/// 場所（地名・住所）が選ばれた
class PlacePickResult extends PlaceSearchResult {
  PlacePickResult(this.point, this.label);
  final LatLng point;
  final String label;
}

/// 台帳のカメラが選ばれた
class CameraPickResult extends PlaceSearchResult {
  CameraPickResult(this.camera);
  final Camera camera;
}

const _recentSearchesKey = 'recent_place_searches';
const _maxRecent = 10;

/// 最近の検索1件（場所 or カメラ）
class _RecentEntry {
  _RecentEntry.place({required this.label, required this.point})
    : camera = null;
  _RecentEntry.camera(Camera c) : camera = c, label = c.name, point = null;

  final String label;
  final LatLng? point;
  final Camera? camera;

  bool get isCamera => camera != null;

  Map<String, Object?> toJson() => camera != null
      ? {'type': 'camera', 'id': camera!.id}
      : {
          'type': 'place',
          'label': label,
          'lat': point!.latitude,
          'lng': point!.longitude,
        };

  /// 同一項目の判定（重複を先頭へ寄せるためのキー）
  String get dedupeKey => camera != null ? 'c:${camera!.id}' : 'p:$label';
}

/// 距離のGoogleマップ風表示（1km未満はm、それ以上はkm）
String formatSearchDistance(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  final km = meters / 1000;
  return km < 10 ? '${km.toStringAsFixed(1)} km' : '${km.round()} km';
}

class PlaceSearchScreen extends StatefulWidget {
  const PlaceSearchScreen({
    super.key,
    required this.app,
    required this.center,
    required this.searchCameras,
    this.autocomplete = PlacesSearch.autocomplete,
    this.details = PlacesSearch.details,
    this.textSearch = PlacesSearch.textSearch,
    this.addressSearch = PlacesSearch.addressSearch,
  });

  final AppState app;

  /// 距離表示・オートコンプリートの起点（地図の現在の中心）
  final LatLng center;

  /// 台帳のカメラ名検索（map_screen._searchCameras 相当。呼び出し側から渡す）
  final List<Camera> Function(String query) searchCameras;

  /// 以下は Google Places 呼び出し（テストで差し替えるための注入。既定は実装本体）
  final Future<List<PlacePrediction>?> Function(
    String input, {
    LatLng? bias,
    String languageCode,
    required String sessionToken,
  })
  autocomplete;
  final Future<LatLng?> Function(String placeId, {required String sessionToken})
  details;
  final Future<List<(String, LatLng)>?> Function(
    String query, {
    LatLng? bias,
    String languageCode,
  })
  textSearch;
  final Future<List<(String, LatLng)>> Function(String query) addressSearch;

  @override
  State<PlaceSearchScreen> createState() => _PlaceSearchScreenState();
}

class _PlaceSearchScreenState extends State<PlaceSearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  late final String _sessionToken;
  Timer? _debounce;
  int _requestGen = 0;

  List<Camera> _cameraHits = const [];
  List<PlacePrediction> _predictions = const [];

  /// 確定検索（キーボードの「検索」）の結果。null は「未確定/入力中」に戻った状態
  List<(String, LatLng)>? _confirmedPlaces;
  bool _loading = false;
  List<_RecentEntry> _recent = const [];

  @override
  void initState() {
    super.initState();
    Analytics.screen('place_search');
    _sessionToken = PlacesSearch.newSessionToken();
    _controller.addListener(_onTextChanged);
    _loadRecent();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final q = _controller.text.trim();
    setState(() {
      _confirmedPlaces = null;
      _cameraHits = q.isEmpty
          ? const []
          : widget.searchCameras(q).take(5).toList();
      if (q.isEmpty) _predictions = const [];
    });
    _debounce?.cancel();
    if (q.isEmpty) return;
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _runAutocomplete(q),
    );
  }

  Future<void> _runAutocomplete(String query) async {
    final gen = ++_requestGen;
    setState(() => _loading = true);
    List<PlacePrediction>? preds;
    try {
      preds = await widget.autocomplete(
        query,
        bias: widget.center,
        languageCode: Localizations.localeOf(context).languageCode,
        sessionToken: _sessionToken,
      );
    } catch (_) {
      preds = null;
    }
    if (!mounted || gen != _requestGen) return;
    setState(() {
      _predictions = preds ?? const [];
      _loading = false;
    });
  }

  Future<void> _runConfirmedSearch() async {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    _debounce?.cancel();
    final gen = ++_requestGen;
    setState(() => _loading = true);
    var results = const <(String, LatLng)>[];
    try {
      final places = await widget.textSearch(
        q,
        bias: widget.center,
        languageCode: Localizations.localeOf(context).languageCode,
      );
      results = places ?? await widget.addressSearch(q);
    } catch (_) {
      results = const [];
    }
    if (!mounted || gen != _requestGen) return;
    setState(() {
      _confirmedPlaces = results;
      _predictions = const [];
      _loading = false;
    });
  }

  void _fillText(String text) {
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _focusNode.requestFocus();
  }

  Future<void> _pickPlace(String label, LatLng point) async {
    await _saveRecent(_RecentEntry.place(label: label, point: point));
    if (!mounted) return;
    Navigator.of(context).pop(PlacePickResult(point, label));
  }

  Future<void> _pickCamera(Camera camera) async {
    await _saveRecent(_RecentEntry.camera(camera));
    if (!mounted) return;
    Navigator.of(context).pop(CameraPickResult(camera));
  }

  Future<void> _selectPrediction(PlacePrediction p) async {
    setState(() => _loading = true);
    LatLng? point;
    try {
      point = await widget.details(p.placeId, sessionToken: _sessionToken);
    } catch (_) {
      point = null;
    }
    if (!mounted) return;
    setState(() => _loading = false);
    if (point == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.mapSearchNotFound)));
      return;
    }
    final label = p.secondaryText.isEmpty
        ? p.mainText
        : '${p.mainText}（${p.secondaryText}）';
    await _pickPlace(label, point);
  }

  Camera? _findCamera(String id) {
    for (final c in widget.app.displayableCameras) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> _loadRecent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_recentSearchesKey) ?? const [];
      final out = <_RecentEntry>[];
      for (final s in raw) {
        try {
          final m = jsonDecode(s) as Map<String, dynamic>;
          if (m['type'] == 'camera') {
            final id = m['id'] as String?;
            if (id == null) continue;
            final c = _findCamera(id);
            if (c == null) continue; // 削除済み・非表示になったカメラは出さない
            out.add(_RecentEntry.camera(c));
          } else if (m['type'] == 'place') {
            final label = m['label'] as String?;
            final lat = (m['lat'] as num?)?.toDouble();
            final lng = (m['lng'] as num?)?.toDouble();
            if (label == null || lat == null || lng == null) continue;
            out.add(_RecentEntry.place(label: label, point: LatLng(lat, lng)));
          }
        } catch (_) {
          // 1件の壊れたデータで全体を諦めない
        }
      }
      if (!mounted) return;
      setState(() => _recent = out.take(_maxRecent).toList());
    } catch (_) {}
  }

  /// 履歴から1件消す（[entry] が null ならすべて）
  Future<void> _removeRecent(_RecentEntry? entry) async {
    setState(() {
      _recent = entry == null
          ? const []
          : _recent.where((e) => e.dedupeKey != entry.dedupeKey).toList();
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      if (entry == null) {
        await prefs.remove(_recentSearchesKey);
        return;
      }
      final raw = prefs.getStringList(_recentSearchesKey) ?? const [];
      final list = raw.where((s) {
        try {
          final m = jsonDecode(s) as Map<String, dynamic>;
          final key = m['type'] == 'camera' ? 'c:${m['id']}' : 'p:${m['label']}';
          return key != entry.dedupeKey;
        } catch (_) {
          return true;
        }
      }).toList();
      await prefs.setStringList(_recentSearchesKey, list);
    } catch (_) {}
  }

  Future<void> _confirmClearRecent() async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(l10n.placeSearchClearAllConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.commonCancel)),
          TextButton(
            key: const Key('recent_clear_all_ok'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.placeSearchClearAll),
          ),
        ],
      ),
    );
    if (ok == true) await _removeRecent(null);
  }

  Future<void> _saveRecent(_RecentEntry entry) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_recentSearchesKey) ?? const [];
      final list = raw.toList();
      // 同一項目は先頭へ寄せる（重複を残さない）
      list.removeWhere((s) {
        try {
          final m = jsonDecode(s) as Map<String, dynamic>;
          final key = m['type'] == 'camera'
              ? 'c:${m['id']}'
              : 'p:${m['label']}';
          return key == entry.dedupeKey;
        } catch (_) {
          return false;
        }
      });
      list.insert(0, jsonEncode(entry.toJson()));
      await prefs.setStringList(
        _recentSearchesKey,
        list.take(_maxRecent).toList(),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            _searchPill(context),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            Expanded(child: _body(context)),
          ],
        ),
      ),
    );
  }

  Widget _searchPill(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          children: [
            IconButton(
              key: const Key('place_search_back'),
              icon: const Icon(Icons.arrow_back),
              tooltip: l10n.placeSearchBack,
              onPressed: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: TextField(
                key: const Key('place_search_field'),
                controller: _controller,
                focusNode: _focusNode,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: l10n.mapPanelSearchHint,
                ),
                onSubmitted: (_) => _runConfirmedSearch(),
              ),
            ),
            if (_controller.text.isNotEmpty)
              IconButton(
                key: const Key('place_search_clear'),
                icon: const Icon(Icons.close),
                tooltip: l10n.placeSearchClear,
                onPressed: () {
                  _controller.clear();
                  _focusNode.requestFocus();
                },
              ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final l10n = context.l10n;
    final q = _controller.text.trim();
    if (q.isEmpty) {
      if (_recent.isEmpty) return const SizedBox.shrink();
      return ListView.separated(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.only(top: 4),
        itemCount: _recent.length + 1,
        separatorBuilder: (_, i) => i == 0
            ? const SizedBox.shrink()
            : const Divider(height: 1, indent: 72),
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 4, 0),
              child: Row(children: [
                Expanded(
                  child: Text(
                    l10n.placeSearchRecentTitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                TextButton(
                  key: const Key('recent_clear_all'),
                  onPressed: _confirmClearRecent,
                  child: Text(l10n.placeSearchClearAll, style: const TextStyle(fontSize: 12)),
                ),
              ]),
            );
          }
          final e = _recent[i - 1];
          // 左へスワイプで1件削除（Google マップと同じ操作）
          return Dismissible(
            key: ValueKey('recent_dismiss_${e.dedupeKey}'),
            direction: DismissDirection.endToStart,
            background: Container(
              color: Colors.red[400],
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(Icons.delete_outline, color: Colors.white),
            ),
            onDismissed: (_) => _removeRecent(e),
            child: _recentRow(context, e),
          );
        },
      );
    }

    final confirmed = _confirmedPlaces;
    final rows = <Widget>[
      for (final c in _cameraHits) _cameraRow(context, c),
      if (confirmed == null)
        for (final p in _predictions) _predictionRow(context, p),
      if (confirmed != null)
        for (final r in confirmed) _placeRow(context, r.$1, r.$2),
    ];
    if (rows.isEmpty) {
      if (confirmed != null) {
        // 確定検索済みで0件のときだけ「見つかりません」を出す（入力中はまだ何も言わない）
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              l10n.mapSearchNotFound,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        );
      }
      return const SizedBox.shrink();
    }
    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: rows.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
      itemBuilder: (_, i) => rows[i],
    );
  }

  Widget _cameraRow(BuildContext context, Camera c) {
    double? distM;
    if (c.hasLocation) {
      distM = distanceMeters(
        widget.center.latitude,
        widget.center.longitude,
        c.lat!,
        c.lng!,
      );
    }
    final subtitleParts = [
      if (c.prefecture.isNotEmpty) prefectureNameOf(context.l10n, c.prefecture),
      if (c.operator.isNotEmpty) c.operator,
    ];
    return _ResultRow(
      key: ValueKey('camera_${c.id}'),
      leading: Container(
        decoration: BoxDecoration(
          color: categoryColor(c.category),
          shape: BoxShape.circle,
        ),
        child: Center(child: CategoryGlyph(c.category, size: 22)),
      ),
      title: c.name,
      subtitle: subtitleParts.join(' · '),
      distanceLabel: distM == null ? null : formatSearchDistance(distM),
      onTap: () => _pickCamera(c),
      onFill: () => _fillText(c.name),
    );
  }

  Widget _predictionRow(BuildContext context, PlacePrediction p) {
    return _ResultRow(
      key: ValueKey('pred_${p.placeId}'),
      leading: Container(
        decoration: BoxDecoration(
          color: Colors.grey[200],
          shape: BoxShape.circle,
        ),
        child: Icon(
          p.isTransit ? Icons.train : Icons.place_outlined,
          size: 22,
          color: Colors.grey[700],
        ),
      ),
      title: p.mainText,
      subtitle: p.secondaryText,
      distanceLabel: p.distanceMeters == null
          ? null
          : formatSearchDistance(p.distanceMeters!.toDouble()),
      onTap: () => _selectPrediction(p),
      onFill: () => _fillText(p.mainText),
    );
  }

  Widget _placeRow(BuildContext context, String label, LatLng point) {
    final distM = distanceMeters(
      widget.center.latitude,
      widget.center.longitude,
      point.latitude,
      point.longitude,
    );
    return _ResultRow(
      key: ValueKey('place_${point.latitude}_${point.longitude}_$label'),
      leading: Container(
        decoration: BoxDecoration(
          color: Colors.grey[200],
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.place_outlined, size: 22, color: Colors.grey[700]),
      ),
      title: label,
      subtitle: '',
      distanceLabel: formatSearchDistance(distM),
      onTap: () => _pickPlace(label, point),
      onFill: () => _fillText(label),
    );
  }

  Widget _recentRow(BuildContext context, _RecentEntry e) {
    return _ResultRow(
      key: ValueKey('recent_${e.dedupeKey}'),
      leading: Container(
        decoration: BoxDecoration(
          color: Colors.grey[200],
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.history, size: 22, color: Colors.grey[700]),
      ),
      title: e.label,
      subtitle: e.isCamera ? e.camera!.operator : '',
      distanceLabel: null,
      onTap: () =>
          e.isCamera ? _pickCamera(e.camera!) : _pickPlace(e.label, e.point!),
      onFill: () => _fillText(e.label),
      onRemove: () => _removeRecent(e),
      removeTooltip: context.l10n.placeSearchRemoveOne,
    );
  }
}

/// 結果1行（Googleマップと同じ構成）: 左に丸アイコン＋距離、中央に主/副テキスト、
/// 右端に「候補を入力欄に入れる」ボタン
class _ResultRow extends StatelessWidget {
  const _ResultRow({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.distanceLabel,
    required this.onTap,
    required this.onFill,
    this.onRemove,
    this.removeTooltip,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final String? distanceLabel;
  final VoidCallback onTap;
  final VoidCallback onFill;

  /// 最近の検索の行だけ: 履歴から消す×ボタン
  final VoidCallback? onRemove;
  final String? removeTooltip;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 44, height: 44, child: leading),
                    if (distanceLabel != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        distanceLabel!,
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16),
                    ),
                    if (subtitle.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.north_west),
                tooltip: context.l10n.placeSearchFillTooltip,
                onPressed: onFill,
              ),
              if (onRemove != null)
                IconButton(
                  key: ValueKey('recent_remove_$title'),
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: removeTooltip,
                  onPressed: onRemove,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
