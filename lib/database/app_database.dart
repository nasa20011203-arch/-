import 'package:drift/drift.dart';

part 'app_database.g.dart';

@DataClassName('NoteRow')
class DayNotes extends Table {
  TextColumn get id => text()();
  TextColumn get date => text().withLength(min: 10, max: 10)();
  TextColumn get content => text()();
  // UTC microseconds since epoch; timezone-independent SQLite INTEGER.
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get revision =>
      integer().customConstraint('NOT NULL CHECK (revision > 0)')();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  @override
  Set<Column> get primaryKey => {id};
}

class SettingsEntries extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [DayNotes, SettingsEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);
  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement(
        'CREATE UNIQUE INDEX one_active_note_per_date '
        'ON day_notes(date) WHERE is_deleted = 0',
      );
    },
    onUpgrade: (m, from, to) async {
      // Every future version must supply an explicit, tested migration.
      throw StateError('Unsupported schema migration: $from -> $to');
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement('PRAGMA busy_timeout = 5000');
      await customStatement('PRAGMA journal_mode = WAL');
      await customStatement('PRAGMA synchronous = FULL');
    },
  );
}
