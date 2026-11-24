import 'package:flutter/material.dart';

import '../app_state.dart';
import '../l10n/l10n.dart';

/// カメラの台帳がまだ 1 件も無いとき（初回起動で取得中・取得に失敗）に出す案内。
/// 以前は何も出さず、地図が空のまま・一覧は「条件に合うカメラがありません」に
/// なっていた（2026-11 のレビュー「何も表示されない」）。台帳が入れば消える
class CatalogLoadBanner extends StatelessWidget {
  const CatalogLoadBanner({super.key, required this.app});

  final AppState app;

  /// 出すべき状態か（起動時の復元が済んでいて、台帳が空）
  static bool shouldShow(AppState app) =>
      app.initialized && app.repository.cameras.isEmpty;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final loading = app.refreshing;
    return Material(
      color: scheme.secondaryContainer,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      loading ? l10n.catalogLoading : l10n.catalogLoadFailed,
                      key: const ValueKey('catalog_load_message'),
                      style: TextStyle(color: scheme.onSecondaryContainer),
                    ),
                  ),
                  if (!loading)
                    TextButton(
                      key: const ValueKey('catalog_load_retry'),
                      onPressed: app.refresh,
                      child: Text(l10n.commonRetry),
                    ),
                ],
              ),
            ),
            if (loading) const LinearProgressIndicator(minHeight: 3),
          ],
        ),
      ),
    );
  }
}
