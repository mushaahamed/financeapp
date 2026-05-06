import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../database/database_helper.dart';
import '../models/user_settings_model.dart';
import '../../core/constants.dart';

class SettingsRepository {
  final DatabaseHelper _db;
  final FlutterSecureStorage _secure;

  SettingsRepository(this._db, this._secure);

  Future<UserSettings?> getSettings() => _db.getSettings();

  Future<void> saveSettings(UserSettings s) => _db.upsertSettings(s);

  Future<void> updateCash(double cash) => _db.updateCash(cash);

  Future<void> adjustCash(double delta) => _db.adjustCash(delta);

  Future<String?> getGeminiApiKey() =>
      _secure.read(key: kSecureKeyGeminiApiKey);

  Future<void> saveGeminiApiKey(String key) =>
      _secure.write(key: kSecureKeyGeminiApiKey, value: key);

  Future<void> clearGeminiApiKey() =>
      _secure.delete(key: kSecureKeyGeminiApiKey);

  Future<bool> isFirstLaunch() async {
    final settings = await _db.getSettings();
    return settings == null;
  }

  Future<UserSettings> initializeDefaults({
    required double initialCash,
    String currency = kDefaultCurrency,
  }) async {
    final now = DateTime.now();
    final settings = UserSettings(
      currentCash: initialCash,
      currency: currency,
      weeklyUpdateDay: now.weekday - 1, // weekday 1=Mon → 0
    );
    await _db.upsertSettings(settings);
    return settings;
  }
}
