import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/calendar_date.dart';
import '../../core/providers.dart';
import '../../models/app_settings.dart';
import '../../models/day_note.dart';
import '../../platform/windows/desktop_host.dart';
import '../notes/note_editor.dart';
import '../settings/settings_panel.dart';
import 'calendar_day_cell.dart';

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});
  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  late final DesktopHost _host;
  Future<bool> Function()? _flushEditor;
  bool _editorOpen = false;
  bool _closing = false;
  Timer? _midnight, _boundsTimer;
  AppSettings? _pendingBounds;
  Future<void> _settingsQueue = Future.value();
  String? _notice;

  @override
  void initState() {
    super.initState();
    _host = ref.read(desktopHostProvider);
    _notice = _host.warning;
    _host.listen(_nativeEvent);
    _scheduleMidnight();
  }

  void _scheduleMidnight() {
    final now = DateTime.now();
    _midnight = Timer(
      DateTime(now.year, now.month, now.day + 1).difference(now),
      () {
        if (mounted) setState(() {});
        _scheduleMidnight();
      },
    );
  }

  Future<void> _nativeEvent(MethodCall call) async {
    if (!mounted) return;
    switch (call.method) {
      case 'closeRequested':
        await _closeApp();
      case 'boundsChanged':
        final args = Map<String, dynamic>.from(call.arguments as Map);
        final current = ref.read(settingsProvider);
        final next = AppSettings.fromJson({...current.toJson(), ...args});
        ref.read(settingsProvider.notifier).state = next;
        _pendingBounds = next;
        _boundsTimer?.cancel();
        _boundsTimer = Timer(const Duration(milliseconds: 500), _saveBounds);
      case 'desktopFallback':
        final next = ref.read(settingsProvider).copyWith(desktopMode: false);
        ref.read(settingsProvider.notifier).state = next;
        _pendingBounds = next;
        await _saveBounds();
        if (mounted) setState(() => _notice = '바탕화면 연결이 끊겨 일반 창으로 전환했습니다.');
    }
  }

  Future<void> _persist(AppSettings settings) {
    final operation = _settingsQueue.then(
      (_) => ref.read(settingsRepositoryProvider).save(settings),
    );
    // Keep the queue usable after a failure; the caller still sees the error.
    _settingsQueue = operation.catchError((Object error) {});
    return operation;
  }

  Future<void> _saveBounds() async {
    _boundsTimer?.cancel();
    final pending = _pendingBounds;
    if (pending == null) return;
    try {
      await _persist(pending);
      if (identical(pending, _pendingBounds)) _pendingBounds = null;
    } catch (error) {
      if (mounted) setState(() => _notice = '창 위치를 저장하지 못했습니다. 종료 시 다시 시도합니다.');
    }
  }

  Future<void> _openNote(DateTime date) async {
    if (_editorOpen || _closing) return;
    _editorOpen = true;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => NoteEditor(
          date: date,
          repository: ref.read(noteRepositoryProvider),
          register: (flush) => _flushEditor = flush,
          unregister: () => _flushEditor = null,
        ),
      );
    } finally {
      _editorOpen = false;
    }
  }

  Future<void> _closeApp() async {
    if (_closing) return;
    _closing = true;
    try {
      if (_flushEditor != null && !await _flushEditor!()) return;
      await _saveBounds();
      if (_pendingBounds != null) return;
      await _settingsQueue;
      await ref.read(shutdownDatabaseProvider)();
      await _host.destroy();
    } catch (error) {
      if (mounted) {
        setState(() => _notice = '종료하지 못했습니다. 저장 상태를 확인한 후 다시 시도하세요.');
      }
    } finally {
      _closing = false;
    }
  }

  Future<void> _applySettings(AppSettings requested) async {
    final host = ref.read(desktopHostProvider);
    final previous = ref.read(settingsProvider);
    var next = requested;
    try {
      await host.setAutoStart(requested.autoStart);
      final attached = await host.setDesktopMode(requested.desktopMode);
      if (requested.desktopMode && !attached) {
        next = requested.copyWith(desktopMode: false);
        if (mounted) setState(() => _notice = '바탕화면 연결에 실패하여 일반 창 모드를 사용합니다.');
      }
      await _persist(next);
      _pendingBounds = null;
      _boundsTimer?.cancel();
      ref.read(settingsProvider.notifier).state = next;
    } catch (_) {
      // Best-effort rollback; preserve the actual UI configuration on failure.
      try {
        await host.setAutoStart(previous.autoStart);
      } catch (_) {}
      try {
        await host.setDesktopMode(previous.desktopMode);
      } catch (_) {}
      rethrow;
    }
  }

  @override
  void dispose() {
    _midnight?.cancel();
    _boundsTimer?.cancel();
    _host.listen((_) async {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final month = ref.watch(monthProvider);
    final settings = ref.watch(settingsProvider);
    final notes = ref.watch(monthNotesProvider(month));
    final cells = monthCells(month);
    final today = dateKey(DateTime.now());
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          color: const Color(0xfff5f3ed).withValues(alpha: settings.opacity),
          border: Border.all(color: const Color(0xffb8beb8)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onPanStart: (_) =>
                        ref.read(desktopHostProvider).beginDrag(),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        '${month.year}년 ${month.month}월',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('previous-month'),
                  tooltip: '이전 달',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => ref.read(monthProvider.notifier).state =
                      DateTime(month.year, month.month - 1),
                ),
                TextButton(
                  key: const Key('today'),
                  onPressed: () {
                    final now = DateTime.now();
                    ref.read(monthProvider.notifier).state = DateTime(
                      now.year,
                      now.month,
                    );
                  },
                  child: const Text('오늘'),
                ),
                IconButton(
                  key: const Key('next-month'),
                  tooltip: '다음 달',
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => ref.read(monthProvider.notifier).state =
                      DateTime(month.year, month.month + 1),
                ),
                IconButton(
                  tooltip: '설정',
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => SettingsPanel(
                      initial: ref.read(settingsProvider),
                      save: _applySettings,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '프로그램 종료',
                  icon: const Icon(Icons.close),
                  onPressed: _closeApp,
                ),
              ],
            ),
            if (_notice != null)
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        _notice!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _notice = null),
                    icon: const Icon(Icons.close, size: 16),
                  ),
                ],
              ),
            Row(
              children: ['일', '월', '화', '수', '목', '금', '토']
                  .asMap()
                  .entries
                  .map(
                    (e) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Center(
                          child: Text(
                            e.value,
                            style: TextStyle(
                              color: e.key == 0
                                  ? Colors.red.shade700
                                  : e.key == 6
                                  ? Colors.blue.shade700
                                  : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            if (notes.hasError)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  '메모를 읽지 못했습니다. 저장소 상태를 확인하세요.',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final byDate = {
                    for (final note in notes.asData?.value ?? <DayNote>[])
                      note.date: note,
                  };
                  final rows = cells.length ~/ 7;
                  return Column(
                    children: List.generate(
                      rows,
                      (row) => Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: List.generate(7, (column) {
                            final date = cells[row * 7 + column];
                            final key = dateKey(date);
                            final inMonth = date.month == month.month;
                            return Expanded(
                              child: CalendarDayCell(
                                date: date,
                                inMonth: inMonth,
                                isToday: key == today,
                                content: byDate[key]?.content ?? '',
                                fontSize: settings.fontSize,
                                onDoubleTap: () => _openNote(date),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(
              height: 22,
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      '날짜를 더블클릭하여 메모 편집 · 제목을 끌어 이동',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (_) =>
                        ref.read(desktopHostProvider).beginResize(),
                    child: const SizedBox(
                      width: 28,
                      child: Icon(Icons.south_east, size: 16),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
