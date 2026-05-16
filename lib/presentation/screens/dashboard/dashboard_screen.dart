import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../../core/constants.dart';
import '../../../core/formatters.dart';
import '../../../data/models/expense_model.dart';
import '../../../providers/providers.dart';
import '../settings/settings_screen.dart';
import '../../widgets/section_header.dart';
import '../../widgets/add_transaction_sheet.dart';

// ── Category icon/colour ──────────────────────────────────────────────────────

class _CatMeta {
  final IconData icon;
  final Color color;
  const _CatMeta(this.icon, this.color);
}

_CatMeta _metaFor(Expense e) {
  if (e.isIncome) {
    final cat = kIncCats.where((c) => c.label == e.category).firstOrNull;
    return cat != null
        ? _CatMeta(cat.icon, cat.color)
        : const _CatMeta(Icons.add_circle_outline_rounded, Color(0xFF10B981));
  }
  final cat = kExpCats.where((c) => c.label == e.category).firstOrNull;
  return cat != null
      ? _CatMeta(cat.icon, cat.color)
      : const _CatMeta(Icons.payments_rounded, Color(0xFF64748B));
}

// ── Screen ────────────────────────────────────────────────────────────────────

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _cashCtrl = TextEditingController();
  bool _cashEditing = false;
  bool _updatingCash = false;
  bool _snapshotTaken = false;

  @override
  void dispose() {
    _cashCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveCash() async {
    final val =
        double.tryParse(_cashCtrl.text.replaceAll(',', '').trim());
    if (val == null) return;
    setState(() {
      _updatingCash = true;
      _cashEditing = false;
    });
    await ref.read(settingsProvider.notifier).updateCash(val);
    setState(() => _updatingCash = false);
    if (mounted) FocusScope.of(context).unfocus();
  }

  Future<void> _maybeCaptureSnapshot(double cash) async {
    if (_snapshotTaken) return;
    _snapshotTaken = true;
    final portfolio = ref.read(portfolioSummaryProvider);
    final liabilities = ref.read(liabilitiesProvider).value ?? [];
    final totalDebt =
        liabilities.fold<double>(0, (s, l) => s + l.outstandingBalance);
    await ref.read(dbProvider).upsertNetWorthSnapshot(
          cash: cash,
          investments: portfolio.currentValue,
          liabilities: totalDebt,
          date: DateTime.now(),
        );
    ref.invalidate(netWorthSnapshotsProvider);
  }

  Future<void> _openAddSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTransactionSheet(
        ref: ref,
        initialDate: DateTime.now(),
      ),
    );
    // Refresh dashboard
    ref.invalidate(dashboardSummaryProvider);
    ref.invalidate(categorySpendingProvider);
    ref.read(settingsProvider.notifier).load();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final health = ref.watch(financialHealthProvider);
    final budgets = ref.watch(budgetsProvider);
    final spendingAsync = ref.watch(categorySpendingProvider);

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text('dhuddu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddSheet,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Transaction'),
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
      ),
      body: settingsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (settings) {
          if (settings == null) return const SizedBox();
          if (!_cashEditing && _cashCtrl.text.isEmpty) {
            _cashCtrl.text =
                settings.currentCash.toStringAsFixed(2);
          }
          WidgetsBinding.instance.addPostFrameCallback(
              (_) => _maybeCaptureSnapshot(settings.currentCash));

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(dashboardSummaryProvider);
              ref.invalidate(categorySpendingProvider);
              ref.read(settingsProvider.notifier).load();
              _snapshotTaken = false;
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(kPad, 12, kPad, 120),
              children: [
                // ── Cash card ────────────────────────────────────────────
                _CashCard(
                  ctrl: _cashCtrl,
                  updating: _updatingCash,
                  onEditStart: () =>
                      setState(() => _cashEditing = true),
                  onSave: _saveCash,
                ),

                const Gap(16),

                // ── Monthly summary ───────────────────────────────────────
                summaryAsync.when(
                  loading: () => const _Shimmer(height: 120),
                  error: (_, __) => const SizedBox(),
                  data: (summary) =>
                      _MonthlySummaryCard(summary: summary),
                ),

                const Gap(16),

                // ── Financial health ──────────────────────────────────────
                _HealthStrip(health: health),

                const Gap(16),

                // ── Budget progress ───────────────────────────────────────
                if (budgets.isNotEmpty)
                  spendingAsync.when(
                    loading: () => const SizedBox(),
                    error: (_, __) => const SizedBox(),
                    data: (spending) => _BudgetSection(
                        budgets: budgets, spending: spending),
                  ),

                if (budgets.isNotEmpty) const Gap(16),

                // ── Today / Week quick stats ──────────────────────────────
                summaryAsync.when(
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                  data: (summary) => Row(children: [
                    Expanded(
                        child: _SmallStat(
                      label: 'Today',
                      value: formatCurrency(summary.todayTotal),
                      icon: Icons.today_rounded,
                      color: const Color(0xFFF97316),
                    )),
                    const Gap(10),
                    Expanded(
                        child: _SmallStat(
                      label: 'This Week',
                      value: formatCurrency(summary.weekTotal),
                      icon: Icons.date_range_rounded,
                      color: kPrimary,
                    )),
                  ]),
                ),

                const Gap(20),

                // ── Recent transactions ───────────────────────────────────
                summaryAsync.when(
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                  data: (summary) {
                    if (summary.recent.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 32),
                          child: Column(children: [
                            Icon(Icons.receipt_long_outlined,
                                size: 56,
                                color: kTextSecondary
                                    .withAlpha(100)),
                            const Gap(12),
                            const Text('No transactions yet',
                                style: TextStyle(
                                    color: kTextSecondary,
                                    fontSize: 15)),
                            const Gap(8),
                            Text(
                              'Tap the button below to add your first one',
                              style: TextStyle(
                                  color:
                                      kTextSecondary.withAlpha(180),
                                  fontSize: 13),
                            ),
                          ]),
                        ),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(
                            title: 'RECENT TRANSACTIONS'),
                        const Gap(8),
                        ...summary.recent
                            .map((e) => _RecentTile(expense: e)),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Cash card ─────────────────────────────────────────────────────────────────

class _CashCard extends StatelessWidget {
  final TextEditingController ctrl;
  final bool updating;
  final VoidCallback onEditStart;
  final VoidCallback onSave;

  const _CashCard({
    required this.ctrl,
    required this.updating,
    required this.onEditStart,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(kPad, 14, 8, 14),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(kRadiusLg),
        border: Border.all(color: kDivider),
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: kPrimary.withAlpha(25),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.account_balance_wallet_rounded,
              color: kPrimary, size: 20),
        ),
        const Gap(12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('CASH ON HAND',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: kTextSecondary,
                        letterSpacing: 0.6)),
                const Gap(2),
                Row(children: [
                  const Text('₹',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: kTextSecondary)),
                  const Gap(4),
                  Expanded(
                    child: TextField(
                      controller: ctrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                              decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*'))
                      ],
                      textInputAction: TextInputAction.done,
                      onTap: onEditStart,
                      onSubmitted: (_) => onSave(),
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        fillColor: Colors.transparent,
                        hintText: '0',
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ]),
              ]),
        ),
        updating
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2)))
            : IconButton(
                icon: const Icon(Icons.check_circle_rounded,
                    color: kGain),
                tooltip: 'Save cash balance',
                onPressed: onSave,
              ),
      ]),
    );
  }
}

// ── Monthly summary card ──────────────────────────────────────────────────────

class _MonthlySummaryCard extends StatelessWidget {
  final DashboardSummary summary;
  const _MonthlySummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final net = summary.monthNet;
    final netPositive = net >= 0;

    return Container(
      padding: const EdgeInsets.all(kPad),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(kRadiusLg),
        border: Border.all(color: kDivider),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('THIS MONTH',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: kTextSecondary,
                    letterSpacing: 0.6)),
            const Gap(12),
            Row(children: [
              Expanded(
                  child: _SummaryPill(
                label: 'Income',
                value: summary.monthIncome,
                color: kGain,
                icon: Icons.arrow_downward_rounded,
              )),
              const Gap(10),
              Expanded(
                  child: _SummaryPill(
                label: 'Expenses',
                value: summary.monthExpenses,
                color: kLoss,
                icon: Icons.arrow_upward_rounded,
              )),
            ]),
            const Gap(12),
            const Divider(height: 1),
            const Gap(12),
            Row(children: [
              const Text('Net Balance',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: kTextSecondary)),
              const Gap(8),
              if (summary.savingsRate > 0)
                Text(
                  '${summary.savingsRate.toStringAsFixed(0)}% saved',
                  style: TextStyle(
                      fontSize: 11, color: kGain.withAlpha(200)),
                ),
              const Spacer(),
              Text(
                '${netPositive ? '+' : ''}${formatCurrency(net)}',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: netPositive ? kGain : kLoss),
              ),
            ]),
          ]),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final IconData icon;
  const _SummaryPill(
      {required this.label,
      required this.value,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(kRadius),
      ),
      child: Row(children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
              color: color.withAlpha(38), shape: BoxShape.circle),
          child: Icon(icon, size: 14, color: color),
        ),
        const Gap(8),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w600)),
              const Gap(1),
              Text(formatCurrency(value),
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: color),
                  overflow: TextOverflow.ellipsis),
            ])),
      ]),
    );
  }
}

// ── Financial health strip ────────────────────────────────────────────────────

class _HealthStrip extends StatelessWidget {
  final FinancialHealth health;
  const _HealthStrip({required this.health});

  @override
  Widget build(BuildContext context) {
    Color scoreColor;
    if (health.score >= 80) {
      scoreColor = kGain;
    } else if (health.score >= 60) {
      scoreColor = const Color(0xFF10B981);
    } else if (health.score >= 40) {
      scoreColor = const Color(0xFFF59E0B);
    } else {
      scoreColor = kLoss;
    }

    return Container(
      padding: const EdgeInsets.all(kPad),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: kDivider),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Text('FINANCIAL HEALTH',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: kTextSecondary,
                      letterSpacing: 0.6)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: scoreColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(health.scoreLabel,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: scoreColor)),
              ),
            ]),
            const Gap(10),
            Row(children: [
              Expanded(
                  child: _HealthMetric(
                label: 'Savings Rate',
                value: '${health.savingsRate.toStringAsFixed(0)}%',
                good: health.savingsRate >= 20,
                ok: health.savingsRate >= 10,
              )),
              const Gap(8),
              Expanded(
                  child: _HealthMetric(
                label: 'Emergency Fund',
                value:
                    '${health.emergencyFundMonths.toStringAsFixed(1)} mo',
                good: health.emergencyFundMonths >= 6,
                ok: health.emergencyFundMonths >= 3,
              )),
              const Gap(8),
              Expanded(
                  child: _HealthMetric(
                label: 'Debt/Income',
                value: health.debtToIncomeRatio > 0
                    ? '${health.debtToIncomeRatio.toStringAsFixed(0)}%'
                    : 'None',
                good: health.debtToIncomeRatio == 0,
                ok: health.debtToIncomeRatio <= 20,
                invertColor: true,
              )),
            ]),
          ]),
    );
  }
}

class _HealthMetric extends StatelessWidget {
  final String label;
  final String value;
  final bool good;
  final bool ok;
  final bool invertColor;

  const _HealthMetric({
    required this.label,
    required this.value,
    required this.good,
    required this.ok,
    this.invertColor = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = good
        ? kGain
        : ok
            ? const Color(0xFFF59E0B)
            : kLoss;

    return Container(
      padding:
          const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 10,
                    color: kTextSecondary,
                    fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis),
            const Gap(4),
            Text(value,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color),
                overflow: TextOverflow.ellipsis),
          ]),
    );
  }
}

// ── Budget progress section ───────────────────────────────────────────────────

class _BudgetSection extends StatelessWidget {
  final Map<String, double> budgets;
  final Map<String, double> spending;
  const _BudgetSection(
      {required this.budgets, required this.spending});

  @override
  Widget build(BuildContext context) {
    final entries = budgets.entries.toList()
      ..sort((a, b) {
        final pa = (spending[a.key] ?? 0) / a.value;
        final pb = (spending[b.key] ?? 0) / b.value;
        return pb.compareTo(pa); // most-spent first
      });

    return Container(
      padding: const EdgeInsets.all(kPad),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(kRadiusLg),
        border: Border.all(color: kDivider),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('MONTHLY BUDGETS',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: kTextSecondary,
                    letterSpacing: 0.6)),
            const Gap(12),
            ...entries.map((e) {
              final spent = spending[e.key] ?? 0;
              final limit = e.value;
              final pct = (spent / limit).clamp(0.0, 1.0);
              final over = spent > limit;
              final color =
                  over ? kLoss : pct >= 0.8 ? const Color(0xFFF59E0B) : kGain;
              final cat = kExpCats
                  .where((c) => c.label == e.key)
                  .firstOrNull;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    if (cat != null)
                      Icon(cat.icon, size: 14, color: cat.color),
                    if (cat != null) const Gap(6),
                    Expanded(
                      child: Text(e.key,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                    ),
                    Text(
                      '${formatCurrency(spent)} / ${formatCurrency(limit)}',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: color),
                    ),
                  ]),
                  const Gap(6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: kDivider,
                      valueColor: AlwaysStoppedAnimation(color),
                      minHeight: 6,
                    ),
                  ),
                  if (over)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        'Over by ${formatCurrency(spent - limit)}',
                        style: const TextStyle(
                            fontSize: 11, color: kLoss),
                      ),
                    ),
                ]),
              );
            }),
          ]),
    );
  }
}

// ── Small stat card ───────────────────────────────────────────────────────────

class _SmallStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _SmallStat(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: kPad, vertical: 12),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: kDivider),
      ),
      child: Row(children: [
        Icon(icon, size: 18, color: color),
        const Gap(10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  color: kTextSecondary,
                  fontWeight: FontWeight.w500)),
          const Gap(2),
          Text(value,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }
}

// ── Shimmer placeholder ───────────────────────────────────────────────────────

class _Shimmer extends StatelessWidget {
  final double height;
  const _Shimmer({required this.height});
  @override
  Widget build(BuildContext context) => Container(
        height: height,
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(kRadiusLg),
          border: Border.all(color: kDivider),
        ),
        child:
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
}

// ── Recent tile ───────────────────────────────────────────────────────────────

class _RecentTile extends StatelessWidget {
  final Expense expense;
  const _RecentTile({required this.expense});

  @override
  Widget build(BuildContext context) {
    final meta = _metaFor(expense);
    final isIncome = expense.isIncome;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: kDivider),
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: meta.color.withAlpha(30),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(meta.icon, size: 20, color: meta.color),
        ),
        const Gap(12),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
          Text(expense.title,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14)),
          const Gap(2),
          Row(children: [
            Text(relativeDate(expense.timestamp),
                style: const TextStyle(
                    color: kTextSecondary, fontSize: 12)),
            if (expense.paymentMethod != null) ...[
              const Text(' · ',
                  style: TextStyle(
                      color: kTextSecondary, fontSize: 12)),
              Text(expense.paymentMethod!,
                  style: const TextStyle(
                      color: kTextSecondary, fontSize: 12)),
            ],
          ]),
        ])),
        Text(
          isIncome
              ? '+${formatCurrency(expense.amount)}'
              : '−${formatCurrency(expense.amount)}',
          style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: isIncome ? kGain : kLoss),
        ),
      ]),
    );
  }
}
