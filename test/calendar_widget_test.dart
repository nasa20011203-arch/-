import 'package:drift/native.dart';
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_calendar/core/providers.dart';
import 'package:offline_calendar/database/app_database.dart';
import 'package:offline_calendar/main.dart';
import 'package:offline_calendar/platform/windows/desktop_host.dart';
import 'package:offline_calendar/models/app_settings.dart';
import 'package:offline_calendar/repositories/settings_repository.dart';
import 'package:offline_calendar/repositories/sqlite_note_repository.dart';

class RecordingHost extends DesktopHost {
  Future<void> Function(MethodCall)? handler;
  bool destroyed = false;
  @override
  void listen(Future<void> Function(MethodCall) callback) {
    handler = callback;
  }

  @override
  Future<void> destroy() async {
    destroyed = true;
  }

  Future<void> requestClose() async {
    await handler!(const MethodCall('closeRequested'));
  }
}

void main() {
  testWidgets(
    'double click edits correct date, auto saves, navigates and deletes',
    (tester) async {
      final db = AppDatabase(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );
      final repo = SqliteNoteRepository(db);
      await tester.binding.setSurfaceSize(const Size(1000, 800));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            noteRepositoryProvider.overrideWithValue(repo),
            settingsRepositoryProvider.overrideWithValue(
              SettingsRepository(db),
            ),
            monthProvider.overrideWith((ref) => DateTime(2026, 10)),
          ],
          child: const CalendarApp(),
        ),
      );
      await tester.pumpAndSettle();
      final cell = find.byKey(const Key('day-2026-10-20'));
      await tester.tap(cell);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tap(cell);
      await tester.pumpAndSettle();
      expect(find.text('2026-10-20 메모'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('note-text')),
        '한글\nEnglish 😀',
      );
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      expect((await repo.read('2026-10-20'))!.content, '한글\nEnglish 😀');
      // A new edit immediately before closing must be flushed, before debounce.
      await tester.enterText(find.byKey(const Key('note-text')), '마지막 수정\n두 줄');
      await tester.tap(find.byKey(const Key('close-note')));
      await tester.pumpAndSettle();
      expect((await repo.read('2026-10-20'))!.content, '마지막 수정\n두 줄');
      await tester.tap(find.byKey(const Key('next-month')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('previous-month')));
      await tester.pumpAndSettle();
      expect(find.text('마지막 수정\n두 줄'), findsOneWidget);
      await tester.tap(cell);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tap(cell);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('note-text')), '');
      await tester.tap(find.byKey(const Key('close-note')));
      await tester.pumpAndSettle();
      expect((await repo.read('2026-10-20'))!.isDeleted, true);
      await tester.pumpWidget(const SizedBox());
      // Let Drift release its stream cache timers before closing the DB.
      await tester.pump();
      await db.close();
      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets('failed close protects draft until SQLite writes recover', (
    tester,
  ) async {
    final db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    final repo = SqliteNoteRepository(db);
    await repo.save('2026-10-20', '기존 데이터');
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          noteRepositoryProvider.overrideWithValue(repo),
          settingsRepositoryProvider.overrideWithValue(SettingsRepository(db)),
          monthProvider.overrideWith((ref) => DateTime(2026, 10)),
        ],
        child: const CalendarApp(),
      ),
    );
    await tester.pumpAndSettle();
    final cell = find.byKey(const Key('day-2026-10-20'));
    await tester.tap(cell);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(cell);
    await tester.pumpAndSettle();
    await db.customStatement('PRAGMA query_only = ON');
    await tester.enterText(
      find.byKey(const Key('note-text')),
      '잃으면 안 되는 내용\n!',
    );
    await tester.tap(find.byKey(const Key('close-note')));
    await tester.pumpAndSettle();
    expect(find.text('저장하지 못했습니다. 입력 내용은 이 창에 남아 있습니다.'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('note-text')))
          .controller!
          .text,
      '잃으면 안 되는 내용\n!',
    );
    expect((await repo.read('2026-10-20'))!.content, '기존 데이터');
    await db.customStatement('PRAGMA query_only = OFF');
    await tester.tap(find.text('저장 재시도'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('close-note')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('note-text')), findsNothing);
    expect((await repo.read('2026-10-20'))!.content, '잃으면 안 되는 내용\n!');
    await tester.pumpWidget(const SizedBox());
    // Let Drift release its stream cache timers before closing the DB.
    await tester.pump();
    await db.close();
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('six week month fits minimum window with maximum font', (
    tester,
  ) async {
    final db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    final repo = SqliteNoteRepository(db);
    await repo.save('2026-07-31', '이전 달 메모');
    await repo.save('2026-08-01', List.filled(30, '긴 한글 메모').join('\n'));
    await tester.binding.setSurfaceSize(const Size(560, 420));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          noteRepositoryProvider.overrideWithValue(repo),
          settingsRepositoryProvider.overrideWithValue(SettingsRepository(db)),
          settingsProvider.overrideWith(
            (ref) => const AppSettings(fontSize: 28),
          ),
          monthProvider.overrideWith((ref) => DateTime(2026, 8)),
        ],
        child: const CalendarApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('day-2026-08-01')), findsOneWidget);
    expect(find.text('이전 달 메모'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    // Let Drift release its stream cache timers before closing the DB.
    await tester.pump();
    await db.close();
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('native close request waits for save and protects failed draft', (
    tester,
  ) async {
    final db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    final repo = SqliteNoteRepository(db);
    final host = RecordingHost();
    String? committedAtShutdown;
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          noteRepositoryProvider.overrideWithValue(repo),
          settingsRepositoryProvider.overrideWithValue(SettingsRepository(db)),
          desktopHostProvider.overrideWithValue(host),
          monthProvider.overrideWith((ref) => DateTime(2026, 10)),
          shutdownDatabaseProvider.overrideWithValue(() async {
            committedAtShutdown = (await repo.read('2026-10-20'))!.content;
            await db.close();
          }),
        ],
        child: const CalendarApp(),
      ),
    );
    await tester.pumpAndSettle();
    final cell = find.byKey(const Key('day-2026-10-20'));
    await tester.tap(cell);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(cell);
    await tester.pumpAndSettle();
    await db.customStatement('PRAGMA query_only = ON');
    await tester.enterText(find.byKey(const Key('note-text')), '종료 직전 한글\n!');
    await host.requestClose();
    await tester.pumpAndSettle();
    expect(host.destroyed, false);
    expect(committedAtShutdown, isNull);
    expect(find.byKey(const Key('note-text')), findsOneWidget);
    await db.customStatement('PRAGMA query_only = OFF');
    await host.requestClose();
    await tester.pumpAndSettle();
    expect(host.destroyed, true);
    expect(committedAtShutdown, '종료 직전 한글\n!');
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.binding.setSurfaceSize(null);
  });
}
