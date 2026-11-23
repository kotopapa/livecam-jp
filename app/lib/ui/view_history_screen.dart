import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../l10n/l10n.dart';
import '../models/camera.dart';
import 'camera_thumb.dart';
import 'detail_screen.dart';

/// 閲覧履歴（1.7.6。2026-11-23 ユーザー要望）。
///
/// 詳細画面を開いたカメラを、最後に見た時刻が新しい順に並べる。記録は端末内だけ
/// （data/view_history_store.dart。サーバーへは送らない）。行を横に払うと1台分、
/// 右上のボタンで全部を消せる。台帳から消えたカメラは出さない。
class ViewHistoryScreen extends StatefulWidget {
  const ViewHistoryScreen({super.key, required this.app});

  final AppState app;

  @override
  State<ViewHistoryScreen> createState() => _ViewHistoryScreenState();
}

class _ViewHistoryScreenState extends State<ViewHistoryScreen> {
  List<Camera> get _cameras {
    final byId = {for (final c in widget.app.repository.cameras) c.id: c};
    return [
      for (final id in widget.app.viewHistory.recentIds)
        if (byId[id] != null) byId[id]!,
    ];
  }

  Future<void> _confirmClear() async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(l10n.viewHistoryClearConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            key: const ValueKey('view_history_clear_ok'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.placeSearchClearAll),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await widget.app.viewHistory.clear();
    if (mounted) setState(() {});
  }

  Future<void> _open(Camera camera) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DetailScreen(camera: camera, app: widget.app),
      ),
    );
    // 開いたカメラが先頭へ移る
    if (mounted) setState(() {});
  }

  String _when(DateTime at) {
    final lang = Localizations.localeOf(context).languageCode;
    final now = DateTime.now();
    final sameDay =
        at.year == now.year && at.month == now.month && at.day == now.day;
    return sameDay
        ? DateFormat.Hm(lang).format(at)
        : DateFormat.MMMd(lang).add_Hm().format(at);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final history = widget.app.viewHistory;
    final cameras = _cameras;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.viewHistoryTitle),
        actions: [
          if (cameras.isNotEmpty)
            TextButton(
              key: const ValueKey('view_history_clear'),
              onPressed: _confirmClear,
              child: Text(l10n.placeSearchClearAll),
            ),
        ],
      ),
      body: cameras.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.viewHistoryEmpty, textAlign: TextAlign.center),
              ),
            )
          : ListView.separated(
              itemCount: cameras.length + 1,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                    child: Text(
                      l10n.viewHistoryNote,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                final c = cameras[i - 1];
                final at = history.lastViewedAt(c.id);
                final url = widget.app.thumbUrlFor(c);
                return Dismissible(
                  key: ValueKey('view_history_${c.id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: scheme.errorContainer,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: Icon(
                      Icons.delete_outline,
                      color: scheme.onErrorContainer,
                      semanticLabel: l10n.placeSearchRemoveOne,
                    ),
                  ),
                  onDismissed: (_) async {
                    await history.remove(c.id);
                    if (mounted) setState(() {});
                  },
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        width: 72,
                        height: 48,
                        child: url == null
                            ? Container(
                                color: scheme.surfaceContainerHighest,
                                alignment: Alignment.center,
                                child: Icon(
                                  c.isVideo
                                      ? Icons.play_circle_outline
                                      : Icons.videocam_off,
                                  color: scheme.onSurfaceVariant,
                                ),
                              )
                            : CameraThumb(url: url, iconSize: 24),
                      ),
                    ),
                    title: Text(
                      c.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      [
                        if (at != null) _when(at),
                        '${history.totalCount(c.id)} ${l10n.rankingUnitViews}',
                        c.operator,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                    onTap: () => _open(c),
                  ),
                );
              },
            ),
    );
  }
}
