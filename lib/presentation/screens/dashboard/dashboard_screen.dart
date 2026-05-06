import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../../core/constants.dart';
import '../../../core/formatters.dart';
import '../../../data/models/expense_model.dart';
import '../../../providers/providers.dart';
import '../settings/settings_screen.dart';
import '../../../presentation/widgets/stat_card.dart';
import '../../../presentation/widgets/section_header.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _cashController = TextEditingController();
  final _expenseTitleController = TextEditingController();
  final _expenseAmountController = TextEditingController();
  bool _updatingCash = false;

  @override
  void dispose() {
    _cashController.dispose();
    _expenseTitleController.dispose();
    _expenseAmountController.dispose();
    super.dispose();
  }

  Future<void> _updateCash() async {
    final val = double.tryParse(_cashController.text.trim());
    if (val == null) return;
    setState(() => _updatingCash = true);
    await ref.read(settingsProvider.notifier).updateCash(val);
    setState(() => _updatingCash = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cash updated')),
      );
    }
  }

  Future<void> _addExpense() async {
    final title = _expenseTitleController.text.trim();
    final amount =
        double.tryParse(_expenseAmountController.text.trim());
    if (title.isEmpty || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid title and amount')),
      );
      return;
    }
    final expense = Expense(
      title: title,
      amount: amount,
      timestamp: DateTime.now(),
    );
    await ref.read(expensesProvider.notifier).add(expense);
    _expenseTitleController.clear();
    _expenseAmountController.clear();
    ref.refresh(dashboardSummaryProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Expense added · ₹${amount.toStringAsFixed(2)} deducted from cash')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);
    final portfolioSummary = ref.watch(portfolioSummaryProvider);
    final dashSummaryAsync = ref.watch(dashboardSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paisa'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: settingsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (settings) {
          if (settings == null) return const SizedBox();
          final symbol = kDefaultCurrencySymbol;

          // Pre-fill cash if controller is empty
          if (_cashController.text.isEmpty) {
            _cashController.text =
                settings.currentCash.toStringAsFixed(2);
          }

          final portfolioValue = portfolioSummary.portfolioValue;
          final netWorth = settings.currentCash + portfolioValue;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(dashboardSummaryProvider);
              ref.read(settingsProvider.notifier).load();
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(kPad, 0, kPad, 100),
              children: [
                const Gap(12),

                // ── Overview cards ──
                const SectionHeader(title: 'OVERVIEW'),
                const Gap(10),
                StatCard(
                  label: 'Total Cash',
                  value: formatCurrency(settings.currentCash,
                      symbol: symbol),
                  backgroundColor: kPrimaryLight,
                ),
                const Gap(10),
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        label: 'Portfolio',
                        value: formatCurrency(portfolioValue,
                            symbol: symbol),
                        subtitle: portfolioSummary.hasMissingPrices
                            ? 'Some prices missing'
                            : null,
                      ),
                    ),
                    const Gap(10),
                    Expanded(
                      child: StatCard(
                        label: 'Net Worth',
                        value: formatCurrency(netWorth, symbol: symbol),
                      ),
                    ),
                  ],
                ),

                const Gap(24),

                // ── Update cash ──
                const SectionHeader(title: 'UPDATE CASH'),
                const Gap(10),
                Container(
                  padding: const EdgeInsets.all(kPad),
                  decoration: BoxDecoration(
                    color: kCard,
                    borderRadius: BorderRadius.circular(kRadiusLg),
                    border: Border.all(color: kDivider),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _cashController,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d*'))
                          ],
                          decoration: const InputDecoration(
                            prefixText: '₹  ',
                            hintText: '0.00',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            fillColor: Colors.transparent,
                          ),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Gap(8),
                      FilledButton(
                        onPressed: _updatingCash ? null : _updateCash,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          textStyle: const TextStyle(fontSize: 13),
                        ),
                        child: _updatingCash
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2))
                            : const Text('Update'),
                      ),
                    ],
                  ),
                ),

                const Gap(24),

                // ── Quick add expense ──
                const SectionHeader(title: 'QUICK EXPENSE'),
                const Gap(10),
                Container(
                  padding: const EdgeInsets.all(kPad),
                  decoration: BoxDecoration(
                    color: kCard,
                    borderRadius: BorderRadius.circular(kRadiusLg),
                    border: Border.all(color: kDivider),
                  ),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _expenseTitleController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'What did you spend on?',
                        ),
                      ),
                      const Gap(10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _expenseAmountController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*\.?\d*'))
                              ],
                              decoration: const InputDecoration(
                                prefixText: '₹  ',
                                hintText: '0.00',
                              ),
                            ),
                          ),
                          const Gap(10),
                          FilledButton(
                            onPressed: _addExpense,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 14),
                            ),
                            child: const Text('Add'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Gap(24),

                // ── Recent activity ──
                dashSummaryAsync.when(
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                  data: (summary) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(title: 'RECENT ACTIVITY'),
                      const Gap(10),
                      Container(
                        padding: const EdgeInsets.all(kPad),
                        decoration: BoxDecoration(
                          color: kCard,
                          borderRadius:
                              BorderRadius.circular(kRadiusLg),
                          border: Border.all(color: kDivider),
                        ),
                        child: Column(
                          children: [
                            SmallStatRow(
                              label: 'Expenses today',
                              value: formatCurrency(summary.todayTotal,
                                  symbol: symbol),
                            ),
                            const Gap(10),
                            const Divider(height: 1),
                            const Gap(10),
                            SmallStatRow(
                              label: 'Expenses this week',
                              value: formatCurrency(summary.weekTotal,
                                  symbol: symbol),
                            ),
                          ],
                        ),
                      ),
                      if (summary.recent.isEmpty) ...[
                        const Gap(16),
                        Center(
                          child: Text(
                            'No expenses yet. Add one above.',
                            style: const TextStyle(
                                color: kTextSecondary, fontSize: 14),
                          ),
                        ),
                      ] else ...[
                        const Gap(16),
                        ...summary.recent.map((e) => _ExpenseRow(e)),
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

class _ExpenseRow extends StatelessWidget {
  final Expense expense;
  const _ExpenseRow(this.expense);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: kPad, vertical: 12),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: kDivider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 14),
                ),
                Text(
                  relativeDate(expense.timestamp),
                  style: const TextStyle(
                      color: kTextSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '−₹${expense.amount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: kLoss,
            ),
          ),
        ],
      ),
    );
  }
}
