import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_calendar/features/notes/note_editor_controller.dart';
import 'package:offline_calendar/models/day_note.dart';
import 'package:offline_calendar/repositories/note_repository.dart';

class ControlledRepository implements NoteRepository {
  final writes = <String>[];
  Completer<void>? pending;
  bool fail = false;
  @override
  Future<void> save(String date, String content) async {
    final wait = pending;
    pending = null;
    if (wait != null) await wait.future;
    if (fail) throw StateError('disk full');
    writes.add(content);
  }

  @override
  Future<DayNote?> read(String date) async => null;
  @override
  Stream<List<DayNote>> watchMonth(
    int year,
    int month, {
    bool includeAdjacentDays = false,
  }) => Stream.value([]);
}

void main() {
  testWidgets('debounce saves latest draft without save button', (
    tester,
  ) async {
    final repo = ControlledRepository();
    final controller = NoteEditorController(repo, '2026-10-20', '');
    controller.edit('한글');
    await tester.pump(const Duration(milliseconds: 400));
    controller.edit('한글\n두 줄');
    await tester.pump(const Duration(milliseconds: 400));
    expect(repo.writes, isEmpty);
    await tester.pump(const Duration(milliseconds: 300));
    expect(repo.writes, ['한글\n두 줄']);
    expect(controller.dirty, false);
    controller.dispose();
  });
  test('flush waits for in-flight save and drains edits in order', () async {
    final repo = ControlledRepository();
    final gate = Completer<void>();
    repo.pending = gate;
    final controller = NoteEditorController(repo, '2026-10-20', '');
    controller.edit('first');
    final flushing = controller.flush();
    controller.edit('newest');
    final closing = controller.flush();
    gate.complete();
    expect(await flushing, true);
    expect(await closing, true);
    expect(repo.writes, ['first', 'newest']);
    expect(controller.dirty, false);
    controller.dispose();
  });
  test('failure retains draft and retry commits it', () async {
    final repo = ControlledRepository()..fail = true;
    final controller = NoteEditorController(repo, '2026-10-20', 'previous');
    controller.edit('소중한 메모\n!');
    expect(await controller.flush(), false);
    expect(controller.error, isNotNull);
    expect(controller.dirty, true);
    expect(controller.text, '소중한 메모\n!');
    repo.fail = false;
    expect(await controller.flush(), true);
    expect(repo.writes.single, controller.text);
    controller.dispose();
  });
}
