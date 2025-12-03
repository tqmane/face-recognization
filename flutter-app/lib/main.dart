import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/home_screen.dart';
import 'services/settings_service.dart';
import 'services/firebase_sync_service.dart';
import 'services/firebase_init.dart';
import 'services/download_notification_service.dart';

bool get _isMobile {
  if (kIsWeb) return false;
  try {
    return Platform.isAndroid || Platform.isIOS;
  } catch (e) {
    return false;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase初期化（モバイルのみ）
  if (_isMobile) {
    await initializeFirebase();
  }
  
  // 通知サービス初期化
  await DownloadNotificationService.instance.initialize();
  
  await SettingsService.instance.init();
  
  // サインイン済みなら同期を開始（モバイルのみ）
  if (_isMobile && FirebaseSyncService.instance.isSignedIn) {
    FirebaseSyncService.instance.setupRealtimeSync();
  }
  
  runApp(const SimilarityQuizApp());
}

class SimilarityQuizApp extends StatelessWidget {
  const SimilarityQuizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '判別クイズ',
      debugShowCheckedModeBanner: false,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }

  // ライトモードテーマ
  ThemeData _buildLightTheme() {
    const primaryColor = Color(0xFF007AFF);
    const backgroundColor = Color(0xFFF2F2F7);
    const surfaceColor = Color(0xFFFFFFFF);
    const cardColor = Color(0xFFFFFFFF);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: Color(0xFF5856D6),
        surface: surfaceColor,
        error: Color(0xFFFF3B30),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Color(0xFF000000),
        onError: Colors.white,
        surfaceContainerHighest: backgroundColor,
      ),
      scaffoldBackgroundColor: backgroundColor,
      cardTheme: const CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceColor,
        foregroundColor: Color(0xFF000000),
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE5E5EA),
        thickness: 1,
      ),
      textTheme: GoogleFonts.notoSansJpTextTheme(
        ThemeData.light().textTheme,
      ),
    );
  }

  // ダークモードテーマ
  ThemeData _buildDarkTheme() {
    const primaryColor = Color(0xFF0A84FF);
    const backgroundColor = Color(0xFF000000);
    const surfaceColor = Color(0xFF1C1C1E);
    const cardColor = Color(0xFF2C2C2E);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: Color(0xFF5E5CE6),
        surface: surfaceColor,
        error: Color(0xFFFF453A),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Color(0xFFFFFFFF),
        onError: Colors.white,
        surfaceContainerHighest: surfaceColor,
      ),
      scaffoldBackgroundColor: backgroundColor,
      cardTheme: const CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceColor,
        foregroundColor: Color(0xFFFFFFFF),
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF38383A),
        thickness: 1,
      ),
      textTheme: GoogleFonts.notoSansJpTextTheme(
        ThemeData.dark().textTheme,
      ),
    );
  }
}
