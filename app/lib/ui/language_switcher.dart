import 'package:flutter/material.dart';

import '../data/locale_controller.dart';
import '../l10n/l10n.dart';

/// 言語名は「その言語自身の表記（自称）」で出す（どの言語の話者にも読めるように、
/// どのロケールでも同じ7つのラベルを並べる）。
String languageDisplayName(AppLanguage language) => switch (language) {
      AppLanguage.ja => '日本語',
      AppLanguage.jaHira => 'やさしい日本語',
      AppLanguage.en => 'English',
      AppLanguage.zhHans => '简体中文',
      AppLanguage.zhHant => '繁體中文',
      AppLanguage.ko => '한국어',
      AppLanguage.vi => 'Tiếng Việt',
    };

/// オンボーディング1画面目に常設する言語切替ボタン。押すと即座に切り替わる。
///
/// 7言語あり狭い端末では1行に収まらないため**横スクロール**にしている
/// （Wrap で折り返すとオンボーディングの縦レイアウトが崩れるため）。
/// 選択中のチップが画面外にならないよう、初回表示時にそこまでスクロールする。
class LanguageSwitcher extends StatefulWidget {
  const LanguageSwitcher({super.key, required this.controller});

  final LocaleController controller;

  @override
  State<LanguageSwitcher> createState() => _LanguageSwitcherState();
}

class _LanguageSwitcherState extends State<LanguageSwitcher> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealSelected());
  }

  /// 選択中のチップがだいたい見える位置まで寄せる（正確な位置合わせは不要）
  void _revealSelected() {
    if (!_scroll.hasClients) return;
    final i = AppLanguage.values.indexOf(widget.controller.language);
    if (i < 0) return;
    final max = _scroll.position.maxScrollExtent;
    if (max <= 0) return; // 全部見えている
    final target = (i / (AppLanguage.values.length - 1)) * max;
    _scroll.jumpTo(target.clamp(0.0, max));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => SingleChildScrollView(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final lang in AppLanguage.values) ...[
              ChoiceChip(
                label: Text(languageDisplayName(lang),
                    style: const TextStyle(fontSize: 12)),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                selected: widget.controller.language == lang,
                onSelected: (_) => widget.controller.setLanguage(lang),
              ),
              const SizedBox(width: 6),
            ],
          ],
        ),
      ),
    );
  }
}

/// 設定画面の「言語 / Language」項目。現在の言語を表示し、タップで選択させる
class LanguageSettingTile extends StatelessWidget {
  const LanguageSettingTile({super.key, required this.controller});

  final LocaleController controller;

  Future<void> _pick(BuildContext context) async {
    final l10n = context.l10n;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(l10n.languageChooseTitle),
        children: [
          for (final lang in AppLanguage.values)
            ListTile(
              leading: Icon(controller.language == lang
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked),
              title: Text(languageDisplayName(lang)),
              onTap: () {
                controller.setLanguage(lang);
                Navigator.of(dialogContext).pop();
              },
            ),
          ListTile(
            leading: const Icon(Icons.smartphone),
            title: Text(l10n.languageFollowSystem),
            enabled: controller.isExplicit,
            onTap: () {
              controller.followSystem();
              Navigator.of(dialogContext).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => ListTile(
        leading: const Icon(Icons.language),
        title: Text(context.l10n.languageSettingTitle),
        subtitle: Text(languageDisplayName(controller.language)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _pick(context),
      ),
    );
  }
}
