import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_settings.dart';
import '../repositories/note_repository.dart';
import '../repositories/settings_repository.dart';
import '../platform/windows/desktop_host.dart';

final noteRepositoryProvider = Provider<NoteRepository>(
  (ref) => throw StateError('NoteRepository must be provided at startup'),
);
final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => throw StateError('SettingsRepository must be provided at startup'),
);
final desktopHostProvider = Provider<DesktopHost>((ref) => DesktopHost());
final settingsProvider = StateProvider<AppSettings>(
  (ref) => const AppSettings(),
);
final monthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});
final monthNotesProvider = StreamProvider.family(
  (ref, DateTime month) => ref
      .watch(noteRepositoryProvider)
      .watchMonth(month.year, month.month, includeAdjacentDays: true),
);

final shutdownDatabaseProvider = Provider<Future<void> Function()>(
  (ref) => throw StateError('Database shutdown must be provided at startup'),
);
