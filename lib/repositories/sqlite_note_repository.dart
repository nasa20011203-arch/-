import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../core/calendar_date.dart';
import '../database/app_database.dart';
import '../models/day_note.dart';
import 'note_repository.dart';

class SqliteNoteRepository implements NoteRepository {
  SqliteNoteRepository(this.db, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final AppDatabase db;
  final DateTime Function() clock;

  DayNote _model(NoteRow row) => DayNote(
    id: row.id,
    date: row.date,
    content: row.content,
    createdAt: DateTime.fromMicrosecondsSinceEpoch(row.createdAt, isUtc: true),
    updatedAt: DateTime.fromMicrosecondsSinceEpoch(row.updatedAt, isUtc: true),
    revision: row.revision,
    isDeleted: row.isDeleted,
  );

  @override
  Future<DayNote?> read(String date) async {
    requireDateKey(date);
    final query = db.select(db.dayNotes)
      ..where((t) => t.date.equals(date))
      ..orderBy([
        (t) => OrderingTerm.desc(t.updatedAt),
        (t) => OrderingTerm.desc(t.revision),
      ])
      ..limit(1);
    final row = await query.getSingleOrNull();
    return row == null ? null : _model(row);
  }

  @override
  Stream<List<DayNote>> watchMonth(
    int year,
    int month, {
    bool includeAdjacentDays = false,
  }) {
    final cells = monthCells(DateTime(year, month));
    final start = dateKey(
      includeAdjacentDays ? cells.first : DateTime(year, month),
    );
    final last = cells.last;
    final end = dateKey(
      includeAdjacentDays
          ? DateTime(last.year, last.month, last.day + 1)
          : DateTime(year, month + 1),
    );
    final query = db.select(db.dayNotes)
      ..where(
        (t) =>
            t.date.isBiggerOrEqualValue(start) &
            t.date.isSmallerThanValue(end) &
            t.isDeleted.equals(false),
      );
    return query.watch().map((rows) => rows.map(_model).toList());
  }

  @override
  Future<void> save(String date, String content) => db.transaction(() async {
    requireDateKey(date);
    final previous = await read(date);
    if (previous == null && content.isEmpty) return;
    if (previous != null &&
        previous.content == content &&
        previous.isDeleted == content.isEmpty) {
      return;
    }
    final now = clock().toUtc().microsecondsSinceEpoch;
    final updated = previous == null
        ? now
        : (now > previous.updatedAt.microsecondsSinceEpoch
              ? now
              : previous.updatedAt.microsecondsSinceEpoch + 1);
    await db
        .into(db.dayNotes)
        .insertOnConflictUpdate(
          DayNotesCompanion.insert(
            id: previous?.id ?? const Uuid().v4(),
            date: date,
            content: content,
            createdAt: previous?.createdAt.microsecondsSinceEpoch ?? now,
            updatedAt: updated,
            revision: (previous?.revision ?? 0) + 1,
            isDeleted: Value(content.isEmpty),
          ),
        );
  });
}
