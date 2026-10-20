// Run in two separate processes to verify file persistence, not just an
// in-memory connection. Uses a caller-supplied temporary database only.
import 'dart:io';
import 'package:drift/native.dart';
import 'package:offline_calendar/database/app_database.dart';
import 'package:offline_calendar/models/app_settings.dart';
import 'package:offline_calendar/repositories/settings_repository.dart';
import 'package:offline_calendar/repositories/sqlite_note_repository.dart';

Future<void> main(List<String> args) async {
  if (args.length != 2 || !['write', 'read'].contains(args[0])) {
    throw ArgumentError('storage_probe.dart <write|read> <temporary-db-path>');
  }
  final db = AppDatabase(NativeDatabase(File(args[1])));
  try {
    final notes = SqliteNoteRepository(db);
    final settings = SettingsRepository(db);
    if (args[0] == 'write') {
      await notes.save('2026-10-20', '한글\nEnglish !@# 😀');
      await notes.save('2026-10-21', '삭제할 메모');
      await notes.save('2026-10-21', '');
      await settings.save(
        const AppSettings(
          x: -900,
          width: 1100,
          height: 760,
          opacity: 0.45,
          fontSize: 18,
        ),
      );
      stdout.writeln('WRITE: notes, tombstone, settings committed');
    } else {
      final note = (await notes.read('2026-10-20'))!;
      final deleted = (await notes.read('2026-10-21'))!;
      final restored = await settings.load();
      if (note.content != '한글\nEnglish !@# 😀' ||
          note.revision != 1 ||
          !deleted.isDeleted ||
          deleted.revision != 2 ||
          restored.x != -900 ||
          restored.opacity != 0.45 ||
          restored.width != 1100 ||
          restored.height != 760 ||
          restored.fontSize != 18) {
        throw StateError('Process restart persistence mismatch');
      }
      stdout.writeln(
        'READ: Unicode, multiline, tombstone, revision and settings verified',
      );
    }
  } finally {
    await db.close();
  }
}
