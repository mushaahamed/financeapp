import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../../core/constants.dart';
import '../../../core/formatters.dart';
import '../../../data/models/expense_model.dart';
import '../../../data/repositories/expense_repository.dart';
import '../../../providers/providers.dart';

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(expenseFilterProvider);
    final expensesAsync = ref.watch(expensesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Expenses')),
      body: Column(
        children: [
          // ── Month total ──
          _MonthTotal(),
          // ── Filter pills ──
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: kPad, vertical: 8),
            child: Row(
              children: ExpenseFilter.values.map((f) {
                final label = {
                  ExpenseFilter.all: 'All',
                  ExpenseFilter.today: 'Today',
                  ExpenseFilter.thisWeek: 'This Week',
                  ExpenseFilter.thisMonth: 'This Month',
                }[f]!;
                final selected = f == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(label),
                    selected: selected,
                    onSelected: (_) {
                      ref.read(expenseFilterProvider.notifier).state = f;
                      ref.read(expensesProvider.notifier).load();
                    },
                    selectedColor: kPrimary,
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : kTextPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                    backgroundColor: kCard,
                    side: BorderSide(
                        color: selected ? kPrimary : kDivider),
                  ),
                );
              }).toList(),
            ),
          ),
          // ── List ──
          Expanded(
            child: expensesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (expenses) {
                if (expenses.isEmpty) {
                  return const Center(
                    child: Text(
                      'No expenses yet.',
                      style: TextStyle(color: kTextSecondary),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(kPad, 0, kPad, 100),
                  itemCount: expenses.length,
                  separatorBuilder: (_, __) => const Gap(8),
                  itemBuilder: (_, i) => _ExpenseTile(expenses[i]),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddExpenseSheet(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _MonthTotal extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<double>(
      future:
          ref.read(expenseRepoProvider).getTotalForMonth(),
      builder: (context, snap) {
        final total = snap.data ?? 0;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(kPad, kPad, kPad, 12),
          color: kCard,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'THIS MONTH',
                style: TextStyle(
                  fontSize: 11,
                  color: kTextSecondary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const Gap(4),
              Text(
                formatCurrency(total),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: kTextPrimary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ExpenseTile extends ConsumerWidget {
  final Expense expense;
  const _ExpenseTile(this.expense);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _showDetailSheet(context, ref),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: kPad, vertical: 14),
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
                  Text(expense.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 15)),
                  const Gap(3),
                  Row(
                    children: [
                      Text(
                        relativeDate(expense.timestamp),
                        style: const TextStyle(
                            color: kTextSecondary, fontSize: 12),
                      ),
                      if (expense.category != null) ...[
                        const Text(' · ',
                            style: TextStyle(
                                color: kTextSecondary, fontSize: 12)),
                        Text(expense.category!,
                            style: const TextStyle(
                                color: kTextSecondary, fontSize: 12)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Text(
              '−${formatCurrency(expense.amount)}',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: kLoss,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetailSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExpenseDetailSheet(expense: expense, ref: ref),
    );
  }
}

class _ExpenseDetailSheet extends StatefulWidget {
  final Expense expense;
  final WidgetRef ref;
  const _ExpenseDetailSheet({required this.expense, required this.ref});

  @override
  State<_ExpenseDetailSheet> createState() => _ExpenseDetailSheetState();
}

class _ExpenseDetailSheetState extends State<_ExpenseDetailSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _notesCtrl;
  String? _category;
  bool _saving = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.expense.title);
    _amountCtrl = TextEditingController(
        text: widget.expense.amount.toStringAsFixed(2));
    _notesCtrl =
        TextEditingController(text: widget.expense.notes ?? '');
    _category = widget.expense.category;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: kCard,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.all(kPad),
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: kDivider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Gap(16),
            const Text('Edit Expense',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const Gap(20),
            _field('Title', _titleCtrl),
            const Gap(12),
            _field('Amount', _amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                prefix: '₹  '),
            const Gap(12),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(hintText: 'Category (optional)'),
              items: kExpenseCategories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v),
            ),
            const Gap(12),
            _field('Notes', _notesCtrl, maxLines: 3),
            const Gap(8),
            Text(
              formatDateTime(widget.expense.timestamp),
              style:
                  const TextStyle(color: kTextSecondary, fontSize: 13),
            ),
            const Gap(24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _deleting ? null : _delete,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kLoss,
                      side: const BorderSide(color: kLoss),
                    ),
                    child: _deleting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: kLoss))
                        : const Text('Delete'),
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white))
                        : const Text('Save'),
                  ),
                ),
              ],
            ),
            Gap(MediaQuery.of(context).viewInsets.bottom + 16),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {TextInputType? keyboardType,
      String? prefix,
      int maxLines = 1}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      maxLines: maxLines,
      inputFormatters: keyboardType ==
              const TextInputType.numberWithOptions(decimal: true)
          ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]
          : null,
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefix,
      ),
    );
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (title.isEmpty || amount == null || amount <= 0) return;

    setState(() => _saving = true);
    final updated = widget.expense.copyWith(
      title: title,
      amount: amount,
      category: _category,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );
    await widget.ref
        .read(expensesProvider.notifier)
        .update(updated, widget.expense.amount);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    setState(() => _deleting = true);
    await widget.ref
        .read(expensesProvider.notifier)
        .delete(widget.expense);
    if (mounted) Navigator.pop(context);
  }
}

// ── Add Expense Sheet ─────────────────────────────────────────────────────────

void _showAddExpenseSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddExpenseSheet(ref: ref),
  );
}

class _AddExpenseSheet extends StatefulWidget {
  final WidgetRef ref;
  const _AddExpenseSheet({required this.ref});

  @override
  State<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<_AddExpenseSheet> {
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String? _category;
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(kPad),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: kDivider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Gap(16),
            const Text('Add Expense',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const Gap(16),
            TextFormField(
              controller: _titleCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration:
                  const InputDecoration(hintText: 'What did you spend on?'),
            ),
            const Gap(10),
            TextFormField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'^\d*\.?\d*'))
              ],
              decoration:
                  const InputDecoration(prefixText: '₹  ', hintText: '0.00'),
            ),
            const Gap(10),
            DropdownButtonFormField<String>(
              value: _category,
              decoration:
                  const InputDecoration(hintText: 'Category (optional)'),
              items: kExpenseCategories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v),
            ),
            const Gap(10),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration:
                  const InputDecoration(hintText: 'Notes (optional)'),
            ),
            const Gap(16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Add Expense'),
              ),
            ),
            const Gap(8),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (title.isEmpty || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid title and amount')),
      );
      return;
    }
    setState(() => _saving = true);
    final expense = Expense(
      title: title,
      amount: amount,
      timestamp: DateTime.now(),
      category: _category,
      notes:
          _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );
    await widget.ref.read(expensesProvider.notifier).add(expense);
    widget.ref.refresh(dashboardSummaryProvider);
    if (mounted) Navigator.pop(context);
  }
}
