import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../data/database/database_helper.dart';
import '../data/models/expense_model.dart';
import '../data/models/investment_asset_model.dart';
import '../data/models/investment_transaction_model.dart';
import '../data/models/user_settings_model.dart';
import '../data/repositories/expense_repository.dart';
import '../data/repositories/investment_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/services/gemini_service.dart';

// ─── Infrastructure ──────────────────────────────────────────────────────────

final dbProvider = Provider<DatabaseHelper>((ref) => DatabaseHelper.instance);

final secureStorageProvider = Provider<FlutterSecureStorage>(
    (ref) => const FlutterSecureStorage());

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

// ─── Dashboard summary data ──────────────────────────────────────────────────

final dashboardSummaryProvider = FutureProvider<DashboardSummary>((ref) async {
  final repo = ref.read(expenseRepoProvider);
  final today = await repo.getTotalForToday();
  final week = await repo.getTotalForWeek();
  final recent = await repo.getRecentExpenses(5);
  return DashboardSummary(todayTotal: today, weekTotal: week, recent: recent);
});

class DashboardSummary {
  final double todayTotal;
  final double weekTotal;
  final List<Expense> recent;
  const DashboardSummary({
    required this.todayTotal,
    required this.weekTotal,
    required this.recent,
  });
}

// ─── Investments ─────────────────────────────────────────────────────────────

class InvestmentAssetsNotifier
    extends StateNotifier<AsyncValue<List<InvestmentAsset>>> {
  final InvestmentRepository _repo;
  final Ref _ref;

  InvestmentAssetsNotifier(this._repo, this._ref)
      : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_repo.getAllAssets);
  }

  Future<int> addAsset(InvestmentAsset a) async {
    final id = await _repo.addAsset(a);
    await load();
    return id;
  }

  Future<void> updateAsset(InvestmentAsset a) async {
    await _repo.updateAsset(a);
    await load();
  }

  Future<void> deleteAsset(int id) async {
    await _repo.deleteAsset(id);
    await load();
    _ref.read(settingsProvider.notifier).load();
  }

  Future<void> addTransaction(InvestmentTransaction tx) async {
    await _repo.addTransaction(tx);
    await load();
    _ref.read(settingsProvider.notifier).load();
  }

  Future<void> deleteTransaction(InvestmentTransaction tx) async {
    await _repo.deleteTransaction(tx);
    await load();
    _ref.read(settingsProvider.notifier).load();
  }

  Future<String?> refreshPrice(InvestmentAsset asset) async {
    final key =
        await _ref.read(settingsRepoProvider).getGeminiApiKey();
    if (key == null || key.isEmpty) return 'Gemini API key not set';

    final settings = _ref.read(settingsProvider).value;
    final model = settings?.geminiModel ?? 'gemini-2.0-flash';
    final gemini = GeminiService(apiKey: key, model: model);
    final result = await gemini.fetchPrice(asset);
    if (result.success) {
      await _repo.updateAssetPrice(asset.id!, result.price!, DateTime.now());
      await load();
      return null;
    }
    return result.error ?? 'Unknown error';
  }

  Future<String?> refreshAllPrices() async {
    final key =
        await _ref.read(settingsRepoProvider).getGeminiApiKey();
    if (key == null || key.isEmpty) return 'Gemini API key not set';

    final settings = _ref.read(settingsProvider).value;
    final model = settings?.geminiModel ?? 'gemini-2.0-flash';
    final gemini = GeminiService(apiKey: key, model: model);

    final assets = state.value ?? [];
    String? lastError;
    for (final asset in assets) {
      if (asset.id == null) continue;
      final result = await gemini.fetchPrice(asset);
      if (result.success) {
        await _repo.updateAssetPrice(asset.id!, result.price!, DateTime.now());
      } else {
        lastError = 'Could not fetch price for ${asset.name}: ${result.error}';
      }
      await Future.delayed(const Duration(milliseconds: 1200));
    }
    await _repo.updateLastPortfolioUpdate(DateTime.now());
    await load();
    _ref.read(settingsProvider.notifier).load();
    return lastError;
  }
}

final investmentAssetsProvider = StateNotifierProvider<InvestmentAssetsNotifier,
    AsyncValue<List<InvestmentAsset>>>(
  (ref) => InvestmentAssetsNotifier(ref.read(investmentRepoProvider), ref),
);

// ─── Transactions for a specific asset ───────────────────────────────────────

final transactionsProvider = FutureProvider.family<List<InvestmentTransaction>,
    int>((ref, assetId) {
  return ref.read(investmentRepoProvider).getTransactions(assetId);
});

// ─── Portfolio summary ────────────────────────────────────────────────────────

final portfolioSummaryProvider =
    Provider<PortfolioSummary>((ref) {
  final assets = ref.watch(investmentAssetsProvider).value ?? [];
  double totalInvested = 0;
  double portfolioValue = 0;
  bool hasMissingPrices = false;

  for (final a in assets) {
    totalInvested += a.totalInvested;
    if (a.lastKnownPricePerUnit != null) {
      portfolioValue += a.unitsHeld * a.lastKnownPricePerUnit!;
    } else {
      portfolioValue += a.totalInvested;
      if (a.unitsHeld > 0) hasMissingPrices = true;
    }
  }

  final pnl = portfolioValue - totalInvested;
  final returnPct =
      totalInvested > 0 ? (pnl / totalInvested) * 100 : 0.0;

  return PortfolioSummary(
    totalInvested: totalInvested,
    portfolioValue: portfolioValue,
    pnl: pnl,
    returnPercent: returnPct,
    hasMissingPrices: hasMissingPrices,
  );
});

class PortfolioSummary {
  final double totalInvested;
  final double portfolioValue;
  final double pnl;
  final double returnPercent;
  final bool hasMissingPrices;

  const PortfolioSummary({
    required this.totalInvested,
    required this.portfolioValue,
    required this.pnl,
    required this.returnPercent,
    required this.hasMissingPrices,
  });
}

// ─── Price refresh loading state ─────────────────────────────────────────────

final priceRefreshingProvider = StateProvider<bool>((ref) => false);
