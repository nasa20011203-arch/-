import 'package:flutter/material.dart';
import '../../core/calendar_date.dart';
import '../../repositories/note_repository.dart';
import 'note_editor_controller.dart';

class NoteEditor extends StatefulWidget {
  const NoteEditor({
    super.key,
    required this.date,
    required this.repository,
    required this.register,
    required this.unregister,
  });
  final DateTime date;
  final NoteRepository repository;
  final void Function(Future<bool> Function()) register;
  final VoidCallback unregister;
  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  NoteEditorController? _editor;
  TextEditingController? _text;
  Object? _loadError;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    widget.register(_close);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final note = await widget.repository.read(dateKey(widget.date));
      if (!mounted) return;
      final content = note == null || note.isDeleted ? '' : note.content;
      _editor = NoteEditorController(
        widget.repository,
        dateKey(widget.date),
        content,
      )..addListener(_changed);
      _text = TextEditingController(text: content);
      setState(() {});
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<bool> _flush() async => _editor == null ? false : _editor!.flush();

  Future<bool> _close() async {
    if (_closing) return false;
    setState(() => _closing = true);
    final ok = _editor == null ? true : await _flush();
    if (!mounted) return ok;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => _closing = false);
    }
    return ok;
  }

  @override
  void dispose() {
    widget.unregister();
    _editor?.removeListener(_changed);
    _editor?.dispose();
    _text?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editor = _editor;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _close();
      },
      child: Dialog(
        child: SizedBox(
          width: 620,
          height: 480,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${dateKey(widget.date)} 메모',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      key: const Key('close-note'),
                      tooltip: '닫기',
                      onPressed: _closing ? null : _close,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_loadError != null) ...[
                  const Text('메모를 읽지 못했습니다. 기존 내용을 보호하기 위해 편집을 잠갔습니다.'),
                  TextButton(onPressed: _load, child: const Text('다시 읽기')),
                ] else if (editor == null)
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  Expanded(
                    child: TextField(
                      key: const Key('note-text'),
                      controller: _text,
                      autofocus: true,
                      expands: true,
                      minLines: null,
                      maxLines: null,
                      enabled: !_closing,
                      keyboardType: TextInputType.multiline,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: '이 날짜의 메모를 입력하세요',
                      ),
                      onChanged: editor.edit,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (editor.error != null) ...[
                    const Text(
                      '저장하지 못했습니다. 입력 내용은 이 창에 남아 있습니다.',
                      style: TextStyle(color: Colors.red),
                    ),
                    TextButton(
                      onPressed: editor.saving ? null : editor.flush,
                      child: const Text('저장 재시도'),
                    ),
                  ] else
                    Text(
                      editor.saving
                          ? '저장 중…'
                          : editor.dirty
                          ? '저장 대기 중…'
                          : '저장됨',
                      key: const Key('save-status'),
                    ),
                  const Text(
                    '입력 후 자동 저장됩니다. 내용을 모두 지우면 삭제로 기록됩니다.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
