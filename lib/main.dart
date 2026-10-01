import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'providers/app.dart';
import 'screens/home.dart';
import 'theme.dart';

Future<void> _initDatabaseFactory() async {
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initDatabaseFactory();
  await initializeDateFormatting('id_ID', null);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  final app = App();
  await app.init();
  // Jangan di-await  jangan sampai backup yang besar menunda splash/UI.
  app.checkAndRunScheduledBackupIfDue();

  runApp(ChangeNotifierProvider.value(
    value: app,
    child: const NgicalApp(),
  ));
}

class NgicalApp extends StatelessWidget {
  const NgicalApp({super.key});

  /// Skala teks berdasarkan lebar layar (halus, biar layout tidak pecah).
  /// Digabung dengan text scale sistem (aksesibilitas).
  static double _screenTextScale(double width) {
    if (width >= 1400) return 1.12;
    if (width >= 1100) return 1.08;
    if (width >= 900) return 1.04;
    return 1.0;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ngical',
      debugShowCheckedModeBanner: false,
      theme: appTheme(),
      // Navigator key agar toast bisa akses overlay dari mana saja
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final screenScale = _screenTextScale(mq.size.width);
        // Pertahankan skala aksesibilitas sistem, lalu kalikan skala layar
        final systemScale = mq.textScaler.scale(1.0);
        final combined = (systemScale * screenScale).clamp(0.85, 1.35);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(combined)),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const _AppShell(),
    );
  }
}

/// Shell utama  diperlukan agar Overlay tersedia untuk AppToast
class _AppShell extends StatelessWidget {
  const _AppShell();

  @override
  Widget build(BuildContext context) {
    return const HomePage();
  }
}
