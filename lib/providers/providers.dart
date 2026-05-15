import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/constants.dart';
import '../data/database/database_helper.dart';
import '../data/models/expense_model.dart';
import '../data/models/goal_model.dart';
import '../data/models/investment_asset_model.dart';
import '../data/models/liability_model.dart';
import '../data/models/user_settings_model.dart';
import '../data/repositories/expense_repository.dart';
import '../data/repositories/goal_repository.dart';
import '../data/repositories/investment_repository.dart';
import '../data/repositories/liability_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/services/fmp_service.dart';
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

final goalRepoProvider =
    Provider<GoalRepository>((ref) => GoalRepository(ref.read(dbProvider)));

final liabilityRepoProvider = Provider<LiabilityRepository>(
    (ref) => LiabilityRepository(ref.read(dbProvider)));

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

  Future<void> update(Expense updated, double oldAmount, bool wasIncome) async {
    await _repo.updateExpense(updated, oldAmount, wasIncome);
    await load();
    _ref.read(settingsProvider.notifier).load();
    _ref.invalidate(dashboardSummaryProvider);
  }

  Future<void> delete(Expense e) async {
    await _repo.deleteExpense(e);
    await load();
    _ref.read(settingsProvider.notifier).load();
    _ref.invalidate(dashboardSummaryProvider);
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
  final monthIncome = await repo.getMonthIncome();
  final monthExpenses = await repo.getMonthExpenses();
  final recent = await repo.getRecentExpenses(10);
  final quickRepeat = await repo.getRecentDistinct(5);
  return DashboardSummary(
    todayTotal: today,
    weekTotal: week,
    monthIncome: monthIncome,
    monthExpenses: monthExpenses,
    recent: recent,
    quickRepeat: quickRepeat,
  );
});

class DashboardSummary {
  final double todayTotal;
  final double weekTotal;
  final double monthIncome;
  final double monthExpenses;
  final List<Expense> recent;
  final List<Expense> quickRepeat;

  double get monthNet => monthIncome - monthExpenses;
  double get savingsRate =>
      monthIncome > 0 ? (monthNet / monthIncome * 100).clamp(0, 100) : 0;

  const DashboardSummary({
    required this.todayTotal,
    required this.weekTotal,
    required this.monthIncome,
    required this.monthExpenses,
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

  Future<void> updateValue(int id, double value) async {
    await _repo.updateValue(id, value, DateTime.now());
    await load();
  }

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

  Future<String?> refreshOne(InvestmentAsset asset) async {
    if (asset.id == null) return 'Invalid asset';

    if (NavService.isEligible(asset)) {
      final nav = await NavService.calculate(asset);
      if (nav != null && nav.success) {
        await _repo.updateValue(asset.id!, nav.currentValue, DateTime.now());
        await load();
        return null;
      }
    }

    if (FmpService.isEligible(asset)) {
      final fmp = await FmpService.calculate(asset);
      if (fmp != null && fmp.success) {
        await _repo.updateValue(asset.id!, fmp.currentValue, DateTime.now());
        await load();
        return null;
      }
    }

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

  Future<String?> refreshAll() async {
    final assets = state.value ?? [];
    String? lastError;

    String? geminiKey;
    GeminiService? gemini;

    for (final a in assets) {
      if (a.id == null) continue;

      if (NavService.isEligible(a)) {
        final nav = await NavService.calculate(a);
        if (nav != null && nav.success) {
          await _repo.updateValue(a.id!, nav.currentValue, DateTime.now());
          continue;
        }
      }

      if (FmpService.isEligible(a)) {
        final fmp = await FmpService.calculate(a);
        if (fmp != null && fmp.success) {
          await _repo.updateValue(a.id!, fmp.currentValue, DateTime.now());
          continue;
        }
      }

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
  for (final e in expenses.where((e) => !e.isIncome)) {
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

final currentNavProvider =
    FutureProvider.family<double?, String>((ref, schemeCode) async {
  return NavService.fetchCurrentNav(schemeCode);
});

// ─── Goals ───────────────────────────────────────────────────────────────────

class GoalsNotifier extends StateNotifier<AsyncValue<List<Goal>>> {
  final GoalRepository _repo;

  GoalsNotifier(this._repo) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_repo.getAll);
  }

  Future<void> add(Goal g) async {
    await _repo.add(g);
    await load();
  }

  Future<void> update(Goal g) async {
    await _repo.update(g);
    await load();
  }

  Future<void> delete(int id) async {
    await _repo.delete(id);
    await load();
  }

  Future<void> addToSaved(int id, double amount) async {
    await _repo.addToSaved(id, amount);
    await load();
  }
}

final goalsProvider =
    StateNotifierProvider<GoalsNotifier, AsyncValue<List<Goal>>>(
        (ref) => GoalsNotifier(ref.read(goalRepoProvider)));

// ─── Liabilities ─────────────────────────────────────────────────────────────

class LiabilitiesNotifier extends StateNotifier<AsyncValue<List<Liability>>> {
  final LiabilityRepository _repo;

  LiabilitiesNotifier(this._repo) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_repo.getAll);
  }

  Future<void> add(Liability l) async {
    await _repo.add(l);
    await load();
  }

  Future<void> update(Liability l) async {
    await _repo.update(l);
    await load();
  }

  Future<void> delete(int id) async {
    await _repo.delete(id);
    await load();
  }

  Future<void> makePayment(int id, double amount) async {
    await _repo.makePayment(id, amount);
    await load();
  }
}

final liabilitiesProvider =
    StateNotifierProvider<LiabilitiesNotifier, AsyncValue<List<Liability>>>(
        (ref) => LiabilitiesNotifier(ref.read(liabilityRepoProvider)));

// ─── Monthly trends (last 6 months) ──────────────────────────────────────────

final monthlyTrendsProvider = FutureProvider<List<MonthlyStats>>((ref) {
  return ref.read(expenseRepoProvider).getLastNMonths(6);
});

// ─── Net worth snapshots ──────────────────────────────────────────────────────

final netWorthSnapshotsProvider =
    FutureProvider<List<NetWorthSnapshot>>((ref) {
  return ref.read(dbProvider).getNetWorthHistory(90);
});

// ─── Financial health ─────────────────────────────────────────────────────────

final financialHealthProvider = Provider<FinancialHealth>((ref) {
  final summary = ref.watch(dashboardSummaryProvider).value;
  final settings = ref.watch(settingsProvider).value;
  final liabilities = ref.watch(liabilitiesProvider).value ?? [];

  final monthIncome = summary?.monthIncome ?? 0;
  final monthExpenses = summary?.monthExpenses ?? 0;
  final cash = settings?.currentCash ?? 0;

  final savingsRate = monthIncome > 0
      ? ((monthIncome - monthExpenses) / monthIncome * 100).clamp(0.0, 100.0)
      : 0.0;

  // Emergency fund in months (cash / avg monthly expenses)
  final emergencyMonths =
      monthExpenses > 0 ? (cash / monthExpenses) : 0.0;

  final totalDebt =
      liabilities.fold<double>(0, (s, l) => s + l.outstandingBalance);
  final totalEmi =
      liabilities.fold<double>(0, (s, l) => s + (l.emiAmount ?? 0));
  final debtToIncome =
      monthIncome > 0 ? (totalEmi / monthIncome * 100) : 0.0;

  return FinancialHealth(
    savingsRate: savingsRate,
    emergencyFundMonths: emergencyMonths,
    totalDebt: totalDebt,
    totalMonthlyEmi: totalEmi,
    debtToIncomeRatio: debtToIncome,
  );
});

class FinancialHealth {
  final double savingsRate;
  final double emergencyFundMonths;
  final double totalDebt;
  final double totalMonthlyEmi;
  final double debtToIncomeRatio;

  const FinancialHealth({
    required this.savingsRate,
    required this.emergencyFundMonths,
    required this.totalDebt,
    required this.totalMonthlyEmi,
    required this.debtToIncomeRatio,
  });

  /// 0–100 score based on savings rate, emergency fund, debt
  int get score {
    int s = 0;
    if (savingsRate >= 20) s += 40;
    else if (savingsRate >= 10) s += 20;
    else if (savingsRate > 0) s += 10;

    if (emergencyFundMonths >= 6) s += 30;
    else if (emergencyFundMonths >= 3) s += 20;
    else if (emergencyFundMonths >= 1) s += 10;

    if (debtToIncomeRatio == 0) s += 30;
    else if (debtToIncomeRatio <= 20) s += 20;
    else if (debtToIncomeRatio <= 40) s += 10;

    return s;
  }

  String get scoreLabel {
    if (score >= 80) return 'Excellent';
    if (score >= 60) return 'Good';
    if (score >= 40) return 'Fair';
    return 'Needs Attention';
  }
}
