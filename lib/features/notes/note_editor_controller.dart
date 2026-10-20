import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../repositories/note_repository.dart';

/// One controller per open date. Writes are serialized; old writes cannot
/// overwrite a newer draft. A failed flush leaves the draft and dirty flag intact.
class NoteEditorController extends ChangeNotifier {
  NoteEditorController(
    this.repository,
    this.date,
    String initial, {
    this.debounce = const Duration(milliseconds: 650),
  }) : _text = initial,
       _savedText = initial;
  final NoteRepository repository;
  final String date;
  final Duration debounce;
  String _text, _savedText;
  Timer? _timer;
  Future<bool>? _inFlight;
  bool _disposed = false;
  Object? error;
  bool saving = false;
  String get text => _text;
  bool get dirty => _text != _savedText;

  void edit(String value) {
    _text = value;
    _timer?.cancel();
    _timer = Timer(debounce, flush);
    _notify();
  }

  Future<bool> flush() async {
    _timer?.cancel();
    final active = _inFlight;
    if (active != null) return active;
    final completer = Completer<bool>();
    _inFlight = completer.future;
    saving = true;
    error = null;
    _notify();
    try {
      while (dirty) {
        final snapshot = _text;
        await repository.save(date, snapshot);
        _savedText = snapshot;
      }
      completer.complete(true);
    } catch (failure) {
      error = failure;
      completer.complete(false);
    } finally {
      saving = false;
      _inFlight = null;
      _notify();
    }
    return completer.future;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _disposed = true;
    super.dispose();
  }
}
