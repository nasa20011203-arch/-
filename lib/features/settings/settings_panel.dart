import 'package:flutter/material.dart';
import '../../models/app_settings.dart';

class SettingsPanel extends StatefulWidget {
  const SettingsPanel({super.key, required this.initial, required this.save});
  final AppSettings initial;
  final Future<void> Function(AppSettings) save;
  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  late AppSettings _settings = widget.initial;
  bool _saving = false;
  String? _error;
  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.save(_settings);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '설정을 적용하지 못했습니다: $error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('달력 설정'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('배경 불투명도 ${(_settings.opacity * 100).round()}%'),
            Slider(
              key: const Key('opacity'),
              value: _settings.opacity,
              min: 0.15,
              max: 1,
              onChanged: _saving
                  ? null
                  : (v) => setState(
                      () => _settings = _settings.copyWith(opacity: v),
                    ),
            ),
            Text('글자 크기 ${_settings.fontSize.round()}'),
            Slider(
              value: _settings.fontSize,
              min: 10,
              max: 28,
              divisions: 18,
              onChanged: _saving
                  ? null
                  : (v) => setState(
                      () => _settings = _settings.copyWith(fontSize: v),
                    ),
            ),
            SwitchListTile(
              title: const Text('Windows 시작 시 자동 실행'),
              value: _settings.autoStart,
              onChanged: _saving
                  ? null
                  : (v) => setState(
                      () => _settings = _settings.copyWith(autoStart: v),
                    ),
            ),
            SwitchListTile(
              title: const Text('바탕화면 모드 (실험적)'),
              subtitle: const Text('Explorer 구조에 의존합니다. 실패하면 일반 창으로 전환합니다.'),
              value: _settings.desktopMode,
              onChanged: _saving
                  ? null
                  : (v) => setState(
                      () => _settings = _settings.copyWith(desktopMode: v),
                    ),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('취소'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? '적용 중…' : '적용'),
      ),
    ],
  );
}
