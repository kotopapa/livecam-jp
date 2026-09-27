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
          color: Colors.white,
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

/// 下部シートの中身（ボタン行のみ。design/map_ui/PROPOSAL.md 第1段階の名残。
/// 検索バーは [MapSearchPill] へ移動したのでここには置かない）。
///
/// ボタン行「レイヤー」「絞り込み」「…」（高さ44、タップ領域は48以上）。
/// シートの開閉・出典行は呼び出し側（map_screen.dart）が持ち、このウィジェットは
/// 見た目と入口だけを持つ。
class MapBottomPanel extends StatelessWidget {
  const MapBottomPanel({
    super.key,
    required this.onLayers,
    required this.onFilter,
    required this.onMore,
    this.layerActive = false,
    this.filterActive = false,
    this.filterCount = 0,
  });

  final VoidCallback onLayers;
  final VoidCallback onFilter;
  final VoidCallback onMore;

  /// レイヤーを選択中（「表示しない」以外）。ONの文言と塗りに反映する
  final bool layerActive;

  /// 絞り込み条件がある（AppState.hasActiveFilters）
  final bool filterActive;

  /// 効いている絞り込み条件の数（AppState.activeFilterCount）。
  /// 1以上なら「絞り込み {count}」、0なら従来の「絞り込み」を表示する
  final int filterCount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // 端末の文字サイズ設定が大きくてもパネルが地図を食わないよう拡大率は 1.3 で頭打ち
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: _PanelButton(
                key: const Key('map_panel_layers'),
                icon: Icons.layers_outlined,
                label: layerActive
                    ? l10n.mapPanelLayersOn
                    : l10n.mapPanelLayers,
                active: layerActive,
                onTap: onLayers,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _PanelButton(
                key: const Key('map_panel_filter'),
                icon: Icons.tune,
                label: filterCount > 0
                    ? l10n.mapPanelFilterCount(filterCount)
                    : l10n.mapPanelFilter,
                active: filterActive,
                onTap: onFilter,
              ),
            ),
            const SizedBox(width: 8),
            // 「…」はアイコンだけの固定幅（文字付き3等分だと「レイヤー ON」が欠ける）
            SizedBox(
              width: 56,
              child: Tooltip(
                message: l10n.mapPanelMore,
                child: _PanelButton(
                  key: const Key('map_panel_more'),
                  icon: Icons.more_horiz,
                  label: '',
                  semanticsLabel: l10n.mapPanelMore,
                  active: false,
                  onTap: onMore,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ボタン行の1個（見た目の高さ44、タップ領域は48以上）
class _PanelButton extends StatelessWidget {
  const _PanelButton({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.semanticsLabel,
  });

  final IconData icon;
  /// 空文字ならアイコンだけ（読み上げは [semanticsLabel]）
  final String label;
  final bool active;
  final VoidCallback onTap;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: label.isEmpty ? semanticsLabel : null,
      child: SizedBox(
      height: 48,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Align(
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: active
                    ? scheme.primaryContainer
                    : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(22),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: active
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                  if (label.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: active
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: active
                              ? scheme.onPrimaryContainer
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}
