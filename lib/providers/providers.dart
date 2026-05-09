import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/constants.dart';
import '../data/database/database_helper.dart';
import '../data/models/expense_model.dart';
import '../data/models/investment_asset_model.dart';
import '../data/models/user_settings_model.dart';
import '../data/repositories/expense_repository.dart';
import '../data/repositories/investment_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/services/gemini_service.dart';
import '../data/services/nav_service.dart';

// ─── Infrastructure ──────────────────────────────────────────────────────────

final dbProvider = Provider<DatabaseHelper>((ref) => DatabaseHelper.instance);

final secureStorageProvider =
    Provider<FlutterSecureStorage>((ref) => const FlutterSecureStorage());

// ─── Repositories ────────────────────────────────────────────────────────────

final settingsRepoProvider = Provider<SettingsRepository>((ref) =>
    SettingsRepository(ref.read(dbProvider), ref.read(secureStorageProvider)));

final expenseRepoProvider = Provider<ExpenseRepository>(
    (ref) => ExpenseRepository(ref.read(dbProvider)));

final investmentRepoProvider = Provider<InvestmentRepository>(
    (ref) => InvestmentRepository(ref.read(dbProvider)));

// ─── Settings ────────────────────────────────────────────────────────────────

class SettingsNotifier extends StateNotifier<AsyncValue<UserSettings?>> {
  final SettingsRepository _repo;
  SettingsNotifier(this._repo) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_repo.getSettings);
  }

  Future<void> updateCash(double cash) async {
    await _repo.updateCash(cash);
    await load();
  }

  Future<void> saveSettings(UserSettings s) async {
    await _repo.saveSettings(s);
    await load();
  }

  Future<void> initialize(double cash) async {
    await _repo.initializeDefaults(initialCash: cash);
    await load();
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AsyncValue<UserSettings?>>(
        (ref) => SettingsNotifier(ref.read(settingsRepoProvider)));

// ─── Gemini API key ──────────────────────────────────────────────────────────

final geminiApiKeyProvider = FutureProvider<String?>((ref) {
  return ref.read(settingsRepoProvider).getGeminiApiKey();
});

// ─── Expense filter ──────────────────────────────────────────────────────────

final expenseFilterProvider =
    StateProvider<ExpenseFilter>((ref) => ExpenseFilter.all);

// ─── Expenses ────────────────────────────────────────────────────────────────

class ExpensesNotifier extends StateNotifier<AsyncValue<List<Expense>>> {
  final ExpenseRepository _repo;
  final Ref _ref;

  ExpensesNotifier(this._repo, this._ref) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    final filter = _ref.read(expenseFilterProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repo.getExpenses(filter));
  }

  Future<void> add(Expense e) async {
    await _repo.addExpense(e);
    await load();
    _ref.read(settingsProvider.notifier).load();
    _ref.invalidate(dashboardSummaryProvider);
  }

  Future<void> update(Expense updated, double oldAmount) async {
    await _repo.updateExpense(updated, oldAmount);
    await load();
    _ref.read(settingsProvider.notifier).load();
  }

  Future<void> delete(Expense e) async {
    await _repo.deleteExpense(e);
    await load();
    _ref.read(settingsProvider.notifier).load();
  }
}

final expensesProvider =
    StateNotifierProvider<ExpensesNotifier, AsyncValue<List<Expense>>>(
        (ref) => ExpensesNotifier(ref.read(expenseRepoProvider), ref));

// ─── Dashboard summary ────────────────────────────────────────────────────────

final dashboardSummaryProvider = FutureProvider<DashboardSummary>((ref) async {
  final repo = ref.read(expenseRepoProvider);
  final today = await repo.getTotalForToday();
  final week = await repo.getTotalForWeek();
  final recent = await repo.getRecentExpenses(5);
  final quickRepeat = await repo.getRecentDistinct(5);
  return DashboardSummary(
      todayTotal: today,
      weekTotal: week,
      recent: recent,
      quickRepeat: quickRepeat);
});

class DashboardSummary {
  final double todayTotal;
  final double weekTotal;
  final List<Expense> recent;
  final List<Expense> quickRepeat; // distinct recent for repeat chips

  const DashboardSummary({
    required this.todayTotal,
    required this.weekTotal,
    required this.recent,
    required this.quickRepeat,
  });
}

// ─── Investments ─────────────────────────────────────────────────────────────

class InvestmentsNotifier
    extends StateNotifier<AsyncValue<List<InvestmentAsset>>> {
  final InvestmentRepository _repo;
  final Ref _ref;

  InvestmentsNotifier(this._repo, this._ref)
      : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_repo.getAll);
  }

  Future<void> add(InvestmentAsset a) async {
    await _repo.add(a);
    await load();
    _ref.read(settingsProvider.notifier).load();
  }

  /// Adds an investment and returns the new DB id (for auto-refresh after add).
  Future<int?> addAndGetId(InvestmentAsset a) async {
    final id = await _repo.add(a);
    await load();
    _ref.read(settingsProvider.notifier).load();
    return id;
  }

  Future<void> addMore(int id, double amount) async {
    await _repo.addMore(id, amount);
    await load();
    _ref.read(settingsProvider.notifier).load();
  }

  Future<void> update(InvestmentAsset a) async {
    await _repo.update(a);
    await load();
  }

  Future<void> delete(int id, double amountInvested) async {
    await _repo.delete(id, amountInvested);
    await load();
    _ref.read(settingsProvider.notifier).load();
  }

  /// Refresh price for one asset.
  /// Uses mfapi.in NAV (exact) if eligible, otherwise Gemini (estimate).
  /// Returns error string or null on success.
  Future<String?> refreshOne(InvestmentAsset asset) async {
    if (asset.id == null) return 'Invalid asset';

    // 1. Try exact NAV from mfapi.in
    if (NavService.isEligible(asset)) {
      final nav = await NavService.calculate(asset);
      if (nav != null && nav.success) {
        await _repo.updateValue(asset.id!, nav.currentValue, DateTime.now());
        await load();
        return null;
      }
    }

    // 2. Fall back to Gemini estimate
    final key = await _ref.read(settingsRepoProvider).getGeminiApiKey();
    if (key == null || key.isEmpty) return 'Gemini API key not set in Settings';
    final settings = _ref.read(settingsProvider).value;
    final gemini = GeminiService(
        apiKey: key, model: settings?.geminiModel ?? kGeminiDefaultModel);
    final result = await gemini.fetchValue(asset);
    if (result.success) {
      await _repo.updateValue(asset.id!, result.currentValue!, DateTime.now());
      await load();
      return null;
    }
    return result.error;
  }

  /// Refresh all assets. Returns last error string or null if all succeeded.
  Future<String?> refreshAll() async {
    final assets = state.value ?? [];
    String? lastError;

    // Fetch Gemini key once (only needed for non-mfapi assets)
    String? geminiKey;
    GeminiService? gemini;

    for (final a in assets) {
      if (a.id == null) continue;

      // Try exact NAV first
      if (NavService.isEligible(a)) {
        final nav = await NavService.calculate(a);
        if (nav != null && nav.success) {
          await _repo.updateValue(a.id!, nav.currentValue, DateTime.now());
          continue;
        }
      }

      // Fall back to Gemini
      geminiKey ??= await _ref.read(settingsRepoProvider).getGeminiApiKey();
      if (geminiKey == null || geminiKey.isEmpty) {
        lastError = 'Gemini API key not set — non-fund assets skipped';
        continue;
      }
      gemini ??= GeminiService(
          apiKey: geminiKey,
          model: _ref.read(settingsProvider).value?.geminiModel ??
              kGeminiDefaultModel);

      final r = await gemini.fetchValue(a);
      if (r.success) {
        await _repo.updateValue(a.id!, r.currentValue!, DateTime.now());
      } else {
        lastError = 'Could not fetch ${a.name}: ${r.error}';
      }
    }

    await _repo.updateLastPortfolioUpdate(DateTime.now());
    await load();
    _ref.read(settingsProvider.notifier).load();
    return lastError;
  }
}

final investmentsProvider = StateNotifierProvider<InvestmentsNotifier,
    AsyncValue<List<InvestmentAsset>>>(
  (ref) => InvestmentsNotifier(ref.read(investmentRepoProvider), ref),
);

// ─── Portfolio summary ────────────────────────────────────────────────────────

final portfolioSummaryProvider = Provider<PortfolioSummary>((ref) {
  final assets = ref.watch(investmentsProvider).value ?? [];
  double invested = 0;
  double current = 0;
  bool hasMissing = false;

  for (final a in assets) {
    invested += a.amountInvested;
    current += a.effectiveValue;
    if (a.currentValue == null && a.amountInvested > 0) hasMissing = true;
  }

  final pnl = current - invested;
  final pct = invested > 0 ? (pnl / invested) * 100 : 0.0;

  return PortfolioSummary(
    totalInvested: invested,
    currentValue: current,
    pnl: pnl,
    returnPercent: pct,
    hasMissing: hasMissing,
    assets: assets,
  );
});

class PortfolioSummary {
  final double totalInvested;
  final double currentValue;
  final double pnl;
  final double returnPercent;
  final bool hasMissing;
  final List<InvestmentAsset> assets;

  const PortfolioSummary({
    required this.totalInvested,
    required this.currentValue,
    required this.pnl,
    required this.returnPercent,
    required this.hasMissing,
    required this.assets,
  });
}

// ─── Expense category summary (for pie chart) ─────────────────────────────────

final expenseCategoryProvider =
    FutureProvider.family<List<CategoryTotal>, ExpenseFilter>(
        (ref, filter) async {
  final repo = ref.read(expenseRepoProvider);
  final expenses = await repo.getExpenses(filter);
  final map = <String, double>{};
  for (final e in expenses) {
    final cat = e.category ?? 'Other';
    map[cat] = (map[cat] ?? 0) + e.amount;
  }
  final list = map.entries
      .map((e) => CategoryTotal(name: e.key, total: e.value))
      .toList()
    ..sort((a, b) => b.total.compareTo(a.total));
  return list;
});

class CategoryTotal {
  final String name;
  final double total;
  const CategoryTotal({required this.name, required this.total});
}

// ─── Price refresh loading ────────────────────────────────────────────────────

final priceRefreshingProvider = StateProvider<bool>((ref) => false);

// ─── Live NAV for a single mfapi scheme code ─────────────────────────────────
// Used in AssetDetailScreen to show current NAV even without investment date.

final currentNavProvider =
    FutureProvider.family<double?, String>((ref, schemeCode) async {
  return NavService.fetchCurrentNav(schemeCode);
});
