import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../../models/app_settings.dart';

/// Only this adapter knows about Windows. Data and note logic do not.
class DesktopHost {
  static const channel = MethodChannel('offline_calendar/desktop');
  String? warning;
  bool get available => Platform.isWindows;
  void listen(Future<void> Function(MethodCall call) handler) {
    if (available) channel.setMethodCallHandler(handler);
  }

  Future<bool> initialize(AppSettings settings) async {
    if (!available) return false;
    await windowManager.ensureInitialized();
    await windowManager.setBackgroundColor(Colors.transparent);
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setAsFrameless();
    await windowManager.setMinimumSize(const Size(560, 420));
    final attached =
        await channel.invokeMethod<bool>('initialize', settings.toJson()) ??
        false;
    try {
      await setAutoStart(settings.autoStart);
    } catch (_) {
      warning = 'Windows 자동 실행 설정을 적용하지 못했습니다. 설정에서 다시 시도하세요.';
    }
    return attached;
  }

  Future<bool> setDesktopMode(bool enabled) async {
    if (!available) return false;
    return await channel.invokeMethod<bool>('setDesktopMode', enabled) ?? false;
  }

  Future<void> setAutoStart(bool enabled) async {
    if (available) await channel.invokeMethod<void>('setAutoStart', enabled);
  }

  Future<void> beginDrag() async {
    if (available) await channel.invokeMethod<void>('beginDrag');
  }

  Future<void> beginResize() async {
    if (available) await channel.invokeMethod<void>('beginResize');
  }

  Future<void> destroy() async {
    if (available) await channel.invokeMethod<void>('destroy');
  }
}
