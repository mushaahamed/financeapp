import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../../core/constants.dart';
import '../../../core/formatters.dart';
import '../../../data/models/expense_model.dart';
import '../../../providers/providers.dart';
import '../settings/settings_screen.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/section_header.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _cashCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  bool _updatingCash = false;
  bool _addingExpense = false;

  @override
  void dispose() {
    _cashCtrl.dispose();
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveCash() async {
    final val = double.tryParse(_cashCtrl.text.trim());
    if (val == null) return;
    setState(() => _updatingCash = true);
    await ref.read(settingsProvider.notifier).updateCash(val);
    setState(() => _updatingCash = false);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Cash updated')));
    }
  }

  Future<void> _addExpense({String? title, double? amount}) async {
    final t = title ?? _titleCtrl.text.trim();
    final a = amount ?? double.tryParse(_amountCtrl.text.trim());
    if (t.isEmpty || a == null || a <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid title and amount')));
      return;
    }
    setState(() => _addingExpense = true);
    await ref.read(expensesProvider.notifier).add(
          Expense(title: t, amount: a, timestamp: DateTime.now()),
        );
    _titleCtrl.clear();
    _amountCtrl.clear();
    setState(() => _addingExpense = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('₹${a.toStringAsFixed(0)} deducted from cash')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);
    final portfolio = ref.watch(portfolioSummaryProvider);
    final summaryAsync = ref.watch(dashboardSummaryProvider);

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text('Paisa'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (settings) {
          if (settings == null) return const SizedBox();
          if (_cashCtrl.text.isEmpty) {
            _cashCtrl.text = settings.currentCash.toStringAsFixed(2);
          }
          final netWorth = settings.currentCash + portfolio.currentValue;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(dashboardSummaryProvider);
              ref.read(settingsProvider.notifier).load();
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(kPad, 8, kPad, 100),
              children: [
                // ── Net worth hero ──
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(kRadiusLg),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Net Worth',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                      const Gap(4),
                      Text(
                        formatCurrency(netWorth),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -1),
                      ),
                      const Gap(16),
                      Row(
                        children: [
                          _HeroStat(
                              label: 'Cash',
                              value: formatCurrency(settings.currentCash)),
                          const SizedBox(
                              height: 28,
                              child: VerticalDivider(
                                  color: Colors.white38, width: 24)),
                          _HeroStat(
                              label: 'Investments',
                              value: formatCurrency(portfolio.currentValue)),
                        ],
                      ),
                    ],
                  ),
                ),

                const Gap(20),

                // ── Update cash ──
                const SectionHeader(title: 'CASH BALANCE'),
                const Gap(8),
                Container(
                  decoration: BoxDecoration(
                      color: kCard,
                      borderRadius: BorderRadius.circular(kRadius),
                      border: Border.all(color: kDivider)),
                  padding: const EdgeInsets.symmetric(horizontal: kPad, vertical: 4),
                  child: Row(
                    children: [
                      const Text('₹', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: kTextSecondary)),
                      const Gap(8),
                      Expanded(
                        child: TextField(
                          controller: _cashCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            fillColor: Colors.transparent,
                            hintText: '0.00',
                          ),
                        ),
                      ),
                      FilledButton(
                        onPressed: _updatingCash ? null : _saveCash,
                        style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            textStyle: const TextStyle(fontSize: 13)),
                        child: _updatingCash
                            ? const SizedBox(width: 16, height: 16,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Save'),
                      ),
                    ],
                  ),
                ),

                const Gap(20),

                // ── Quick add expense ──
                const SectionHeader(title: 'ADD EXPENSE'),
                const Gap(8),
                Container(
                  decoration: BoxDecoration(
                      color: kCard,
                      borderRadius: BorderRadius.circular(kRadius),
                      border: Border.all(color: kDivider)),
                  padding: const EdgeInsets.all(kPad),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: _titleCtrl,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: const InputDecoration(hintText: 'What for?'),
                            ),
                          ),
                          const Gap(8),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _amountCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                              decoration: const InputDecoration(prefixText: '₹  ', hintText: '0'),
                            ),
                          ),
                          const Gap(8),
                          FilledButton(
                            onPressed: _addingExpense ? null : () => _addExpense(),
                            style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14)),
                            child: _addingExpense
                                ? const SizedBox(width: 16, height: 16,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.add, size: 20),
                          ),
                        ],
                      ),

                      // ── Quick repeat chips ──
                      summaryAsync.when(
                        loading: () => const SizedBox(),
                        error: (_, __) => const SizedBox(),
                        data: (summary) {
                          if (summary.quickRepeat.isEmpty) return const SizedBox();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Gap(12),
                              const Text('REPEAT',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: kTextSecondary,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5)),
                              const Gap(6),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: summary.quickRepeat.map((e) {
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: ActionChip(
                                        label: Text(
                                            '${e.title}  ₹${e.amount.toStringAsFixed(0)}'),
                                        onPressed: () => _addExpense(
                                            title: e.title, amount: e.amount),
                                        backgroundColor: kPrimaryLight,
                                        labelStyle: const TextStyle(
                                            color: kPrimary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600),
                                        side: const BorderSide(color: kPrimary, width: 0.8),
                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const Gap(20),

                // ── Today / Week stats + recent ──
                summaryAsync.when(
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                  data: (summary) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(title: 'SPENDING'),
                      const Gap(8),
                      Row(
                        children: [
                          Expanded(
                              child: StatCard(
                                  label: 'Today',
                                  value: formatCurrency(summary.todayTotal))),
                          const Gap(10),
                          Expanded(
                              child: StatCard(
                                  label: 'This Week',
                                  value: formatCurrency(summary.weekTotal))),
                        ],
                      ),
                      if (summary.recent.isNotEmpty) ...[
                        const Gap(16),
                        const SectionHeader(title: 'RECENT'),
                        const Gap(8),
                        ...summary.recent.map((e) => _RecentRow(
                              expense: e,
                              onRepeat: () =>
                                  _addExpense(title: e.title, amount: e.amount),
                            )),
                      ] else ...[
                        const Gap(16),
                        Center(
                          child: Text('No expenses yet.',
                              style: TextStyle(color: kTextSecondary)),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;
  const _HeroStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 11)),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _RecentRow extends StatelessWidget {
  final Expense expense;
  final VoidCallback onRepeat;
  const _RecentRow({required this.expense, required this.onRepeat});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: kPad, vertical: 10),
      decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(kRadius),
          border: Border.all(color: kDivider)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(expense.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 14)),
                Text(relativeDate(expense.timestamp),
                    style:
                        const TextStyle(color: kTextSecondary, fontSize: 12)),
              ],
            ),
          ),
          Text('−₹${expense.amount.toStringAsFixed(0)}',
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 14, color: kLoss)),
          const Gap(8),
          GestureDetector(
            onTap: onRepeat,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: kPrimaryLight,
                  borderRadius: BorderRadius.circular(20)),
              child: const Text('+Again',
                  style: TextStyle(
                      color: kPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
