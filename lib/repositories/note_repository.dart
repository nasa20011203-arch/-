import '../models/day_note.dart';

abstract interface class NoteRepository {
  Future<DayNote?> read(String date);
  Stream<List<DayNote>> watchMonth(
    int year,
    int month, {
    bool includeAdjacentDays = false,
  });
  // Empty content is a tombstone; whitespace is legitimate free text.
  Future<void> save(String date, String content);
}
