import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:livecam_jp/l10n/l10n.dart';

/// ウィジェットテスト用の MaterialApp ラッパ。
/// 1.4.0 以降、画面は `AppLocalizations` を要求するため、テストでも
/// localizationsDelegates を渡す必要がある。既定は日本語。
MaterialApp testApp(Widget home, {Locale locale = const Locale('ja')}) =>
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    );
