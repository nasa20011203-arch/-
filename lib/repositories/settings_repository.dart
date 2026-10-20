import 'dart:convert';
import '../database/app_database.dart';
import '../models/app_settings.dart';

class SettingsRepository {
  SettingsRepository(this.db);
  final AppDatabase db;
  Future<AppSettings> load() async {
    final row = await (db.select(
      db.settingsEntries,
    )..where((t) => t.key.equals('window'))).getSingleOrNull();
    if (row == null) return const AppSettings();
    return AppSettings.fromJson(jsonDecode(row.value) as Map<String, dynamic>);
  }

  Future<void> save(AppSettings settings) async {
    await db
        .into(db.settingsEntries)
        .insertOnConflictUpdate(
          SettingsEntriesCompanion.insert(
            key: 'window',
            value: jsonEncode(settings.toJson()),
          ),
        );
  }
}
