import 'package:flutter/material.dart';

import '../data/locale_controller.dart';
import '../l10n/l10n.dart';

/// 言語名は「その言語自身の表記」で出す（英語話者にも日本語話者にも読めるように、
/// どのロケールでも同じ3つのラベルを並べる）。
String languageDisplayName(AppLanguage language) => switch (language) {
      AppLanguage.ja => '日本語',
      AppLanguage.jaHira => 'やさしい日本語',
      AppLanguage.en => 'English',
    };

/// オンボーディング1画面目に常設する言語切替ボタン。押すと即座に切り替わる。
class LanguageSwitcher extends StatelessWidget {
  const LanguageSwitcher({super.key, required this.controller});

  final LocaleController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final lang in AppLanguage.values)
            ChoiceChip(
              label: Text(languageDisplayName(lang),
                  style: const TextStyle(fontSize: 12)),
              visualDensity: VisualDensity.compact,
              selected: controller.language == lang,
              onSelected: (_) => controller.setLanguage(lang),
            ),
        ],
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
