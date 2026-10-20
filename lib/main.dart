import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/providers.dart';
import 'database/open_database.dart';
import 'features/calendar/calendar_page.dart';
import 'platform/windows/desktop_host.dart';
import 'repositories/settings_repository.dart';
import 'repositories/sqlite_note_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final db = await openDatabase();
    final settingsRepository = SettingsRepository(db);
    var settings = await settingsRepository.load();
    final host = DesktopHost();
    if (Platform.isWindows) {
      final attached = await host.initialize(settings);
      if (settings.desktopMode && !attached) {
        settings = settings.copyWith(desktopMode: false);
        await settingsRepository.save(settings);
      }
    }
    runApp(
      ProviderScope(
        overrides: [
          noteRepositoryProvider.overrideWithValue(SqliteNoteRepository(db)),
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          settingsProvider.overrideWith((ref) => settings),
          desktopHostProvider.overrideWithValue(host),
          shutdownDatabaseProvider.overrideWithValue(db.close),
        ],
        child: const CalendarApp(),
      ),
    );
  } catch (error) {
    // Never overwrite/reset a database that failed to open or migrate.
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SelectableText('시작하지 못했습니다. 데이터베이스는 초기화하지 않았습니다.\n$error'),
          ),
        ),
      ),
    );
  }
}

class CalendarApp extends StatelessWidget {
  const CalendarApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: '오프라인 캘린더',
    theme: ThemeData(
      useMaterial3: true,
      colorSchemeSeed: Colors.teal,
      scaffoldBackgroundColor: Colors.transparent,
      fontFamily: Platform.isWindows ? 'Malgun Gothic' : null,
    ),
    home: const CalendarPage(),
  );
}
