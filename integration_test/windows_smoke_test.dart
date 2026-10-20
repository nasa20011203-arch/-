// Native-window smoke test for a Windows desktop session. Not a substitute for
// manually checking Win+D, Explorer restart, display scaling, or IME composition.
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:offline_calendar/core/providers.dart';
import 'package:offline_calendar/database/app_database.dart';
import 'package:offline_calendar/main.dart';
import 'package:offline_calendar/models/app_settings.dart';
import 'package:offline_calendar/platform/windows/desktop_host.dart';
import 'package:offline_calendar/repositories/settings_repository.dart';
import 'package:offline_calendar/repositories/sqlite_note_repository.dart';
import 'package:window_manager/window_manager.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Windows normal window and SQLite editor round trip', (
    tester,
  ) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('Run this integration test on Windows');
    }
    final directory = await Directory.systemTemp.createTemp(
      'calendar-integration-',
    );
    final db = AppDatabase(
      NativeDatabase(File('${directory.path}/test.sqlite')),
    );
    final notes = SqliteNoteRepository(db);
    final host = DesktopHost();
    // Set up the real channel without changing the user's startup registry entry.
    await windowManager.ensureInitialized();
    await windowManager.setBackgroundColor(Colors.transparent);
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setAsFrameless();
    await DesktopHost.channel.invokeMethod<bool>(
      'initialize',
      const AppSettings().toJson(),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          noteRepositoryProvider.overrideWithValue(notes),
          settingsRepositoryProvider.overrideWithValue(SettingsRepository(db)),
          desktopHostProvider.overrideWithValue(host),
          shutdownDatabaseProvider.overrideWithValue(db.close),
          monthProvider.overrideWith((ref) => DateTime(2026, 10)),
        ],
        child: const CalendarApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(await windowManager.isAlwaysOnTop(), false);
    final bounds = await windowManager.getBounds();
    expect(bounds.width, greaterThanOrEqualTo(550));
    final cell = find.byKey(const Key('day-2026-10-20'));
    await tester.tap(cell);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(cell);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('note-text')),
      'Windows 한글\n두 줄 !',
    );
    await tester.tap(find.byKey(const Key('close-note')));
    await tester.pumpAndSettle();
    expect((await notes.read('2026-10-20'))!.content, 'Windows 한글\n두 줄 !');
    await tester.pumpWidget(const SizedBox());
    await db.close();
    await directory.delete(recursive: true);
  });
}
