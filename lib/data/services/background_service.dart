import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:workmanager/workmanager.dart';
import '../database/database_helper.dart';
import '../services/gemini_service.dart';
import '../../core/constants.dart';

const kBgTaskName = 'weeklyPortfolioUpdate';
const kBgTaskUnique = 'paisa_weekly_prices';

/// Top-level callback required by workmanager (runs in separate isolate).
@pragma('vm:entry-point')
void workmanagerCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName != kBgTaskName) return true;

    WidgetsFlutterBinding.ensureInitialized();
    final db = DatabaseHelper.instance;
    final storage = const FlutterSecureStorage();

    final apiKey = await storage.read(key: kSecureKeyGeminiApiKey);
    if (apiKey == null || apiKey.isEmpty) return true;

    final settings = await db.getSettings();
    if (settings == null || !settings.autoUpdateEnabled) return true;

    final assets = await db.getAllInvestments();
    if (assets.isEmpty) return true;

    final gemini = GeminiService(apiKey: apiKey, model: settings.geminiModel);

    for (final asset in assets) {
      if (asset.id == null) continue;
      final result = await gemini.fetchValue(asset);
      if (result.success) {
        await db.updateInvestmentValue(
            asset.id!, result.currentValue!, DateTime.now());
      }
      await Future.delayed(const Duration(seconds: 2));
    }

    await db.updateLastPortfolioUpdate(DateTime.now());
    return true;
  });
}

class BackgroundService {
  static Future<void> initialize() async {
    await Workmanager().initialize(workmanagerCallbackDispatcher);
  }

  static Future<void> scheduleWeeklyUpdate() async {
    await Workmanager().registerPeriodicTask(
      kBgTaskUnique,
      kBgTaskName,
      frequency: const Duration(days: 7),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  }

  static Future<void> cancelWeeklyUpdate() async {
    await Workmanager().cancelByUniqueName(kBgTaskUnique);
  }
}
