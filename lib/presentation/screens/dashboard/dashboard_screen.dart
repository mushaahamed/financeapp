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

// ── Category icon/colour (mirrors expenses_screen) ────────────────────────────

class _CatMeta {
  final IconData icon;
  final Color color;
  const _CatMeta(this.icon, this.color);
}

const _expCatMeta = <String, _CatMeta>{
  'Food & Dining':  _CatMeta(Icons.restaurant_rounded,     Color(0xFFEF4444)),
  'Shopping':       _CatMeta(Icons.shopping_bag_rounded,   Color(0xFFF97316)),
  'Transport':      _CatMeta(Icons.directions_bus_rounded, Color(0xFF3B82F6)),
  'Health':         _CatMeta(Icons.favorite_rounded,       Color(0xFFEC4899)),
  'Entertainment':  _CatMeta(Icons.movie_rounded,          Color(0xFF8B5CF6)),
  'Bills':          _CatMeta(Icons.receipt_long_rounded,   Color(0xFF06B6D4)),
  'Friends':        _CatMeta(Icons.people_rounded,         Color(0xFF10B981)),
  'Other':          _CatMeta(Icons.payments_rounded,       Color(0xFF64748B)),
};

const _incCatMeta = <String, _CatMeta>{
  'Salary':                _CatMeta(Icons.work_rounded,              Color(0xFF10B981)),
  'Freelance / Consulting':_CatMeta(Icons.laptop_rounded,            Color(0xFF0EA5E9)),
  'Business':              _CatMeta(Icons.storefront_rounded,        Color(0xFF6366F1)),
  'Investment Returns':    _CatMeta(Icons.trending_up_rounded,       Color(0xFF8B5CF6)),
  'Rental Income':         _CatMeta(Icons.home_work_rounded,         Color(0xFFF59E0B)),
  'Gift / Bonus':          _CatMeta(Icons.card_giftcard_rounded,     Color(0xFFEC4899)),
  'Refund':                _CatMeta(Icons.replay_rounded,            Color(0xFF14B8A6)),
  'Other Income':          _CatMeta(Icons.payments_rounded,          Color(0xFF64748B)),
};

_CatMeta _metaFor(Expense e) {
  if (e.isIncome) {
    return _incCatMeta[e.category] ??
        const _CatMeta(Icons.add_circle_outline_rounded, Color(0xFF10B981));
  }
  return _expCatMeta[e.category] ??
      const _CatMeta(Icons.payments_rounded, Color(0xFF64748B));
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

  @override
  void dispose() {
    _cashCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveCash() async {
    final val = double.tryParse(_cashCtrl.text.replaceAll(',', '').trim());
    if (val == null) return;
    setState(() { _updatingCash = true; _cashEditing = false; });
    await ref.read(settingsProvider.notifier).updateCash(val);
    setState(() => _updatingCash = false);
    if (mounted) FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);
    final summaryAsync = ref.watch(dashboardSummaryProvider);

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text('Paisa'),
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
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (settings) {
          if (settings == null) return const SizedBox();

          // Only pre-fill cash field when not actively editing
          if (!_cashEditing && _cashCtrl.text.isEmpty) {
            _cashCtrl.text = settings.currentCash.toStringAsFixed(2);
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(dashboardSummaryProvider);
              ref.read(settingsProvider.notifier).load();
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(kPad, 12, kPad, 120),
              children: [

                // ── Cash on hand card ──────────────────────────────────────
                _CashCard(
                  ctrl: _cashCtrl,
                  updating: _updatingCash,
                  onEditStart: () => setState(() => _cashEditing = true),
                  onSave: _saveCash,
                ),

                const Gap(16),

                // ── Monthly income / expense summary ───────────────────────
                summaryAsync.when(
                  loading: () => const _MonthlySummaryShimmer(),
                  error: (_, __) => const SizedBox(),
                  data: (summary) => _MonthlySummaryCard(summary: summary),
                ),

                const Gap(16),

                // ── Today / Week quick stats ───────────────────────────────
                summaryAsync.when(
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                  data: (summary) => Row(children: [
                    Expanded(child: _SmallStat(
                      label: 'Today',
                      value: formatCurrency(summary.todayTotal),
                      icon: Icons.today_rounded,
                      color: const Color(0xFFF97316),
                    )),
                    const Gap(10),
                    Expanded(child: _SmallStat(
                      label: 'This Week',
                      value: formatCurrency(summary.weekTotal),
                      icon: Icons.date_range_rounded,
                      color: kPrimary,
                    )),
                  ]),
                ),

                const Gap(20),

                // ── Recent transactions ────────────────────────────────────
                summaryAsync.when(
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                  data: (summary) {
                    if (summary.recent.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: Column(
                            children: [
                              Icon(Icons.receipt_long_outlined,
                                  size: 48,
                                  color: kTextSecondary.withOpacity(0.4)),
                              const Gap(12),
                              const Text('No transactions yet',
                                  style: TextStyle(
                                      color: kTextSecondary, fontSize: 15)),
                            ],
                          ),
                        ),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader(title: 'RECENT TRANSACTIONS'),
                        const Gap(8),
                        ...summary.recent.map((e) => _RecentTile(expense: e)),
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
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: kPrimary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.account_balance_wallet_rounded,
              color: kPrimary, size: 20),
        ),
        const Gap(12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                  ],
                  textInputAction: TextInputAction.done,
                  onTap: onEditStart,
                  onSubmitted: (_) => onSave(),
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700),
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
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : IconButton(
                icon: const Icon(Icons.check_circle_rounded, color: kGain),
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('THIS MONTH',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: kTextSecondary,
                letterSpacing: 0.6)),
        const Gap(12),
        Row(children: [
          // Income
          Expanded(child: _SummaryPill(
            label: 'Income',
            value: summary.monthIncome,
            color: kGain,
            icon: Icons.arrow_downward_rounded,
          )),
          const Gap(10),
          // Expenses
          Expanded(child: _SummaryPill(
            label: 'Expenses',
            value: summary.monthExpenses,
            color: kLoss,
            icon: Icons.arrow_upward_rounded,
          )),
        ]),
        const Gap(12),
        const Divider(height: 1),
        const Gap(12),
        // Net row
        Row(children: [
          const Text('Net Balance',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: kTextSecondary)),
          const Spacer(),
          Text(
            '${netPositive ? '+' : ''}${formatCurrency(net)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: netPositive ? kGain : kLoss,
            ),
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
  const _SummaryPill({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(kRadius),
      ),
      child: Row(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const Gap(8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: color, fontWeight: FontWeight.w600)),
            const Gap(1),
            Text(formatCurrency(value),
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color),
                overflow: TextOverflow.ellipsis),
          ]),
        ),
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
  const _SmallStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: kPad, vertical: 12),
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
                  fontSize: 11, color: kTextSecondary, fontWeight: FontWeight.w500)),
          const Gap(2),
          Text(value,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }
}

// ── Monthly summary shimmer (loading) ─────────────────────────────────────────

class _MonthlySummaryShimmer extends StatelessWidget {
  const _MonthlySummaryShimmer();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(kRadiusLg),
        border: Border.all(color: kDivider),
      ),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}

// ── Recent transaction tile ───────────────────────────────────────────────────

class _RecentTile extends StatelessWidget {
  final Expense expense;
  const _RecentTile({required this.expense});

  @override
  Widget build(BuildContext context) {
    final meta = _metaFor(expense);
    final isIncome = expense.isIncome;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: kDivider),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: meta.color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(meta.icon, size: 20, color: meta.color),
        ),
        const Gap(12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(expense.title,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14)),
            const Gap(2),
            Text(relativeDate(expense.timestamp),
                style: const TextStyle(color: kTextSecondary, fontSize: 12)),
          ]),
        ),
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
