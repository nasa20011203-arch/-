import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_calendar/database/app_database.dart';
import 'package:offline_calendar/models/app_settings.dart';
import 'package:offline_calendar/repositories/settings_repository.dart';
import 'package:offline_calendar/repositories/sqlite_note_repository.dart';

void main() {
  late Directory directory;
  late File file;
  late AppDatabase db;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('calendar-test-');
    file = File('${directory.path}/test.sqlite');
    db = AppDatabase(NativeDatabase(file));
  });
  tearDown(() async {
    await db.close();
    await directory.delete(recursive: true);
  });

  test(
    'Unicode multiline data survives close/reopen and month navigation',
    () async {
      var repo = SqliteNoteRepository(db);
      const text = '한글 메모\nEnglish !@# \n세 번째 줄 😀';
      await repo.save('2026-12-31', text);
      await repo.save('2027-01-01', '다음 해');
      final original = (await repo.read('2026-12-31'))!;
      expect(original.createdAt.isUtc, true);
      expect(original.revision, 1);
      expect(original.id, matches(RegExp(r'^[a-f0-9-]{36}$')));
      await db.close();
      db = AppDatabase(NativeDatabase(file));
      repo = SqliteNoteRepository(db);
      expect((await repo.read('2026-12-31'))!.content, text);
      expect((await repo.watchMonth(2027, 1).first).single.content, '다음 해');
      expect((await repo.watchMonth(2026, 12).first).single.content, text);
      expect(
        (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
          'user_version',
        ),
        1,
      );
    },
  );

  test(
    'delete persists as tombstone; restore retains ID and increments revision',
    () async {
      var repo = SqliteNoteRepository(db, clock: () => DateTime.utc(2026));
      await repo.save('2026-10-20', '첫 메모');
      final first = (await repo.read('2026-10-20'))!;
      await repo.save('2026-10-20', '');
      await db.close();
      db = AppDatabase(NativeDatabase(file));
      repo = SqliteNoteRepository(db, clock: () => DateTime.utc(2025));
      final deleted = (await repo.read('2026-10-20'))!;
      expect(deleted.isDeleted, true);
      expect(deleted.revision, 2);
      expect(await repo.watchMonth(2026, 10).first, isEmpty);
      await repo.save('2026-10-20', '복구');
      final restored = (await repo.read('2026-10-20'))!;
      expect(restored.id, first.id);
      expect(restored.createdAt, first.createdAt);
      expect(restored.updatedAt.isAfter(deleted.updatedAt), true);
      expect(restored.revision, 3);
      expect(restored.isDeleted, false);
    },
  );

  test('database enforces one active note per date', () async {
    await SqliteNoteRepository(db).save('2026-10-20', 'one');
    await expectLater(
      db.customStatement(
        'INSERT INTO day_notes (id,date,content,created_at,updated_at,revision,is_deleted) '
        "VALUES ('other','2026-10-20','two',1,1,1,0)",
      ),
      throwsA(anything),
    );
    expect((await db.select(db.dayNotes).get()).length, 1);
  });

  test(
    'empty untouched date creates no phantom note; whitespace is retained',
    () async {
      final repo = SqliteNoteRepository(db);
      await repo.save('2026-10-20', '');
      expect(await repo.read('2026-10-20'), isNull);
      await repo.save('2026-10-20', '  \n');
      expect((await repo.read('2026-10-20'))!.isDeleted, false);
    },
  );

  test('settings persist position size opacity and mode', () async {
    const settings = AppSettings(
      x: -800,
      y: 120,
      width: 1200,
      height: 800,
      opacity: 0.35,
      fontSize: 20,
      autoStart: true,
      desktopMode: true,
    );
    await SettingsRepository(db).save(settings);
    await db.close();
    db = AppDatabase(NativeDatabase(file));
    expect((await SettingsRepository(db).load()).toJson(), settings.toJson());
  });

  test(
    'real SQLite write failure leaves committed content unchanged',
    () async {
      final repo = SqliteNoteRepository(db);
      await repo.save('2026-10-20', 'committed');
      await db.customStatement('PRAGMA query_only = ON');
      await expectLater(
        repo.save('2026-10-20', 'new draft'),
        throwsA(anything),
      );
      expect((await repo.read('2026-10-20'))!.content, 'committed');
      await db.customStatement('PRAGMA query_only = OFF');
      await repo.save('2026-10-20', 'new draft');
      expect((await repo.read('2026-10-20'))!.content, 'new draft');
    },
  );

  test('repository rejects invalid dates without writing', () async {
    final repo = SqliteNoteRepository(db);
    await expectLater(repo.save('2026-02-30', 'bad'), throwsFormatException);
    await expectLater(repo.save('2026/10/20', 'bad'), throwsFormatException);
    expect(await db.select(db.dayNotes).get(), isEmpty);
  });

  test(
    'calendar range includes visible adjacent days only when requested',
    () async {
      final repo = SqliteNoteRepository(db);
      await repo.save('2026-07-31', 'previous month');
      await repo.save('2026-08-01', 'this month');
      await repo.save('2026-09-05', 'following month');
      await repo.save('2026-09-06', 'not visible');
      expect((await repo.watchMonth(2026, 8).first).length, 1);
      expect(
        (await repo.watchMonth(2026, 8, includeAdjacentDays: true).first)
            .length,
        3,
      );
    },
  );
}
