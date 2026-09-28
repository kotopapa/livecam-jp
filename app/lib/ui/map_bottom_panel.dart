import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

/// 地図上部に浮かせる検索ピル（Googleマップ風レイアウト。2026-09-27）。
///
/// 高さ48の白い浮きピル。文字入力欄ではなく、タップで既存の検索シートを開く入口。
/// 地図の Stack 内で top 固定にして使う
class MapSearchPill extends StatelessWidget {
  const MapSearchPill({super.key, required this.hint, required this.onTap});

  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 端末の文字サイズ設定が大きくてもピルが伸びすぎないよう拡大率は 1.3 で頭打ち
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: SizedBox(
        height: 48,
        child: Material(
          color: scheme.surface,
          elevation: 3,
          shadowColor: Colors.black45,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            key: const Key('map_panel_search'),
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.search, size: 20, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      hint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// シートを開いたときの操作行。下部タブと同じ「アイコンの下に文字」のボタンを
/// 横に並べる（レイヤー／絞り込み／お気に入り／ルート）。「…」に隠すと使われない
/// ため、よく使う入口は直接並べる（2026-09-27 要望）。
class MapBottomPanel extends StatelessWidget {
  const MapBottomPanel({
    super.key,
    required this.onLayers,
    required this.onFilter,
    required this.onFavorites,
    this.onRoute,
    this.layerActive = false,
    this.filterActive = false,
    this.filterCount = 0,
    this.routeActive = false,
  });

  final VoidCallback onLayers;
  final VoidCallback onFilter;
  final VoidCallback onFavorites;

  /// ルート沿いのカメラ（経路のキーが無いときは null＝ボタンを出さない）
  final VoidCallback? onRoute;

  final bool layerActive;
  final bool filterActive;

  /// 効いている絞り込み条件の数（1以上ならアイコンにバッジ）
  final int filterCount;

  /// ルート沿い表示中
  final bool routeActive;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.2,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
        child: Row(
          children: [
            Expanded(
              child: _PanelButton(
                key: const Key('map_panel_layers'),
                icon: Icons.layers_outlined,
                label: l10n.mapPanelLayers,
                active: layerActive,
                onTap: onLayers,
              ),
            ),
            Expanded(
              child: _PanelButton(
                key: const Key('map_panel_filter'),
                icon: Icons.tune,
                label: l10n.mapPanelFilter,
                active: filterActive,
                badge: filterCount > 0 ? '$filterCount' : null,
                onTap: onFilter,
              ),
            ),
            Expanded(
              child: _PanelButton(
                key: const Key('map_panel_favorites'),
                icon: Icons.star_outline,
                label: l10n.tabFavorites,
                active: false,
                onTap: onFavorites,
              ),
            ),
            if (onRoute != null)
              Expanded(
                child: _PanelButton(
                  key: const Key('map_panel_route'),
                  icon: Icons.route_outlined,
                  label: l10n.mapPanelRoute,
                  active: routeActive,
                  onTap: onRoute!,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 下部タブと同じ形のボタン（アイコンを丸い背景に入れ、その下に文字）
class _PanelButton extends StatelessWidget {
  const _PanelButton({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = active ? scheme.onSecondaryContainer : scheme.onSurfaceVariant;
    Widget pill = Container(
      width: 56,
      height: 30,
      decoration: BoxDecoration(
        color: active ? scheme.secondaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(15),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 22, color: fg),
    );
    if (badge != null) {
      pill = Stack(clipBehavior: Clip.none, children: [
        pill,
        Positioned(
          right: 8,
          top: -2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            decoration: BoxDecoration(color: scheme.error, borderRadius: BorderRadius.circular(8)),
            alignment: Alignment.center,
            child: Text(badge!,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: scheme.onError)),
          ),
        ),
      ]);
    }
    return Semantics(
      button: true,
      selected: active,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 58,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            pill,
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
                color: active ? scheme.onSurface : scheme.onSurfaceVariant,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
