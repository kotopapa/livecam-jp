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

/// 言語選択シート。オンボーディングと設定画面で共通。
///
/// 選んだらシートを閉じてから切り替える（切り替えは MaterialApp ごと作り直すため、
/// 開いたままのルートが残らないように順序を固定する）。
Future<void> showLanguageSheet(
  BuildContext context,
  LocaleController controller, {
  bool showFollowSystem = false,
}) {
  final l10n = context.l10n;
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              // 今の言語が読めない人にも分かるよう英語を併記する
              controller.language == AppLanguage.en
                  ? l10n.languageChooseTitle
                  : '${l10n.languageChooseTitle} / Language',
              style: Theme.of(sheetContext).textTheme.titleMedium,
            ),
          ),
          for (final lang in AppLanguage.values)
            ListTile(
              title: Text(languageDisplayName(lang)),
              trailing: controller.language == lang
                  ? Icon(
                      Icons.check,
                      color: Theme.of(sheetContext).colorScheme.primary,
                    )
                  : null,
              selected: controller.language == lang,
              onTap: () {
                Navigator.of(sheetContext).pop();
                controller.setLanguage(lang);
              },
            ),
          if (showFollowSystem) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.smartphone),
              title: Text(l10n.languageFollowSystem),
              enabled: controller.isExplicit,
              onTap: () {
                Navigator.of(sheetContext).pop();
                controller.followSystem();
              },
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// オンボーディングに常設する言語切替ボタン。
///
/// 「🌐 現在の言語 ▾」の1ボタンで、押すと全言語の一覧シートが開く。
/// 以前はチップを横スクロールで並べていたが、端で見切れて他の言語があると
/// 分からず、画面上部を占有していたため、標準的なドロップダウン型に変更した。
class LanguageSwitcher extends StatelessWidget {
  const LanguageSwitcher({super.key, required this.controller});

  final LocaleController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Align(
        alignment: Alignment.centerRight,
        child: OutlinedButton.icon(
          onPressed: () => showLanguageSheet(context, controller),
          icon: const Icon(Icons.language, size: 20),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(languageDisplayName(controller.language)),
              const Icon(Icons.arrow_drop_down, size: 20),
            ],
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.fromLTRB(12, 0, 6, 0),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ),
    );
  }
}

/// 設定画面の「言語 / Language」項目。現在の言語を表示し、タップで選択させる
class LanguageSettingTile extends StatelessWidget {
  const LanguageSettingTile({super.key, required this.controller});

  final LocaleController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => ListTile(
        leading: const Icon(Icons.language),
        title: Text(context.l10n.languageSettingTitle),
        subtitle: Text(languageDisplayName(controller.language)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () =>
            showLanguageSheet(context, controller, showFollowSystem: true),
      ),
    );
  }
}
