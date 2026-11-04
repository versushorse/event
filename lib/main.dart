// 週末お出かけ・イベント提案Androidアプリのエントリーポイント
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const WeekendOutingApp());
}

class WeekendOutingApp extends StatelessWidget {
  const WeekendOutingApp({super.key});

  /// Android標準フォントで漢字（「直」「近」「週」など）が中国語字形（中華フォント）に
  /// なるのを防ぐため、すべてのテキストスタイルに日本語ロケール（ja_JP）を適用する
  TextTheme _applyJapaneseLocale(TextTheme base) {
    const jaLocale = Locale('ja', 'JP');
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(locale: jaLocale),
      displayMedium: base.displayMedium?.copyWith(locale: jaLocale),
      displaySmall: base.displaySmall?.copyWith(locale: jaLocale),
      headlineLarge: base.headlineLarge?.copyWith(locale: jaLocale),
      headlineMedium: base.headlineMedium?.copyWith(locale: jaLocale),
      headlineSmall: base.headlineSmall?.copyWith(locale: jaLocale),
      titleLarge: base.titleLarge?.copyWith(locale: jaLocale),
      titleMedium: base.titleMedium?.copyWith(locale: jaLocale),
      titleSmall: base.titleSmall?.copyWith(locale: jaLocale),
      bodyLarge: base.bodyLarge?.copyWith(locale: jaLocale),
      bodyMedium: base.bodyMedium?.copyWith(locale: jaLocale),
      bodySmall: base.bodySmall?.copyWith(locale: jaLocale),
      labelLarge: base.labelLarge?.copyWith(locale: jaLocale),
      labelMedium: base.labelMedium?.copyWith(locale: jaLocale),
      labelSmall: base.labelSmall?.copyWith(locale: jaLocale),
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF00796B),
        brightness: Brightness.light,
      ),
    );

    return MaterialApp(
      title: '週末どこ行く？AIお出かけナビ',
      debugShowCheckedModeBanner: false,
      theme: baseTheme.copyWith(
        textTheme: _applyJapaneseLocale(baseTheme.textTheme),
        cardTheme: const CardThemeData(
          surfaceTintColor: Colors.white,
        ),
      ),
      builder: (context, child) {
        return DefaultTextStyle.merge(
          style: const TextStyle(locale: Locale('ja', 'JP')),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const HomeScreen(),
    );
  }
}
