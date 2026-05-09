import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import '../../../core/constants.dart';
import '../../../core/formatters.dart';
import '../../../data/models/expense_model.dart';
import '../../../data/repositories/expense_repository.dart';
import '../../../providers/providers.dart';

// ── Category metadata ─────────────────────────────────────────────────────────

class _Cat {
  final String label;
  final IconData icon;
  final Color color;
  const _Cat(this.label, this.icon, this.color);
}

const _cats = [
  _Cat('Food & Dining',  Icons.restaurant_rounded,     Color(0xFFEF4444)),
  _Cat('Shopping',       Icons.shopping_bag_rounded,   Color(0xFFF97316)),
  _Cat('Transport',      Icons.directions_bus_rounded, Color(0xFF3B82F6)),
  _Cat('Health',         Icons.favorite_rounded,       Color(0xFFEC4899)),
  _Cat('Entertainment',  Icons.movie_rounded,          Color(0xFF8B5CF6)),
  _Cat('Bills',          Icons.receipt_long_rounded,   Color(0xFF06B6D4)),
  _Cat('Friends',        Icons.people_rounded,         Color(0xFF10B981)),
  _Cat('Other',          Icons.payments_rounded,       Color(0xFF64748B)),
];

_Cat _catFor(String? label) =>
    _cats.firstWhere((c) => c.label == label, orElse: () => _cats.last);

// ── Screen ────────────────────────────────────────────────────────────────────

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});
  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  // Calendar state
  late DateTime _focusedMonth;
  late DateTime _selectedDate;
  Set<DateTime> _datesWithExpenses = {};
  List<Expense> _dayExpenses = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
    _selectedDate = DateTime(now.year, now.month, now.day);
    _loadMonth();
    _loadDay();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _loadMonth() async {
    final dates = await ref.read(expenseRepoProvider)
        .getDatesWithExpensesInMonth(_focusedMonth.year, _focusedMonth.month);
    if (mounted) setState(() => _datesWithExpenses = dates);
  }

  Future<void> _loadDay() async {
    final list = await ref.read(expenseRepoProvider)
        .getExpensesForDate(_selectedDate);
    if (mounted) setState(() => _dayExpenses = list);
  }

  void _refresh() {
    _loadMonth();
    _loadDay();
    ref.read(expensesProvider.notifier).load();
    ref.invalidate(dashboardSummaryProvider);
  }

  Future<void> _openSheet({Expense? editing, DateTime? date}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExpenseSheet(
        ref: ref,
        editing: editing,
        initialDate: date ?? (editing?.timestamp ?? _selectedDate),
      ),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.calendar_month_outlined), text: 'Calendar'),
            Tab(icon: Icon(Icons.list_rounded), text: 'All'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_calendarTab(), _allTab()],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabs,
        builder: (_, __) {
          final isToday = _isSameDay(_selectedDate, DateTime.now());
          return FloatingActionButton.extended(
            onPressed: () => _openSheet(
              date: _tabs.index == 0 ? _selectedDate : DateTime.now(),
            ),
            icon: const Icon(Icons.add),
            label: Text(_tabs.index == 1 || isToday
                ? 'Add Expense'
                : 'Add for ${DateFormat("d MMM").format(_selectedDate)}'),
          );
        },
      ),
    );
  }

  // ── Calendar tab ──────────────────────────────────────────────────────────

  Widget _calendarTab() {
    final dayTotal = _dayExpenses.fold<double>(0, (s, e) => s + e.amount);
    final isToday = _isSameDay(_selectedDate, DateTime.now());

    return Column(children: [
      // Calendar widget
      Container(
        color: kCard,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () {
                  setState(() => _focusedMonth =
                      DateTime(_focusedMonth.year, _focusedMonth.month - 1));
                  _loadMonth();
                },
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: Center(
                  child: Text(
                    DateFormat('MMMM yyyy').format(_focusedMonth),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: () {
                  setState(() => _focusedMonth =
                      DateTime(_focusedMonth.year, _focusedMonth.month + 1));
                  _loadMonth();
                },
                visualDensity: VisualDensity.compact,
              ),
            ]),
          ),
          _CalendarGrid(
            month: _focusedMonth,
            selectedDate: _selectedDate,
            datesWithExpenses: _datesWithExpenses,
            onDateSelected: (d) { setState(() => _selectedDate = d); _loadDay(); },
          ),
          const Divider(height: 1),
        ]),
      ),

      // Day header
      Container(
        color: kBackground,
        padding: const EdgeInsets.fromLTRB(kPad, 10, kPad, 8),
        child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              isToday ? 'Today' : DateFormat('EEEE, d MMMM').format(_selectedDate),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            if (_dayExpenses.isNotEmpty)
              Text('${_dayExpenses.length} item${_dayExpenses.length > 1 ? "s" : ""}',
                  style: const TextStyle(fontSize: 12, color: kTextSecondary)),
          ]),
          const Spacer(),
          if (_dayExpenses.isNotEmpty)
            Text('−${formatCurrency(dayTotal)}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kLoss)),
        ]),
      ),

      // Day list
      Expanded(
        child: _dayExpenses.isEmpty
            ? _EmptyDay(
                date: _selectedDate,
                onAdd: () => _openSheet(),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(kPad, 8, kPad, 120),
                itemCount: _dayExpenses.length,
                separatorBuilder: (_, __) => const Gap(8),
                itemBuilder: (_, i) => _ExpenseRow(
                  expense: _dayExpenses[i],
                  onTap: () => _openSheet(editing: _dayExpenses[i]),
                  onDelete: () async {
                    await ref.read(expensesProvider.notifier).delete(_dayExpenses[i]);
                    _refresh();
                  },
                ),
              ),
      ),
    ]);
  }

  // ── All tab ───────────────────────────────────────────────────────────────

  Widget _allTab() {
    final expensesAsync = ref.watch(expensesProvider);
    final filter = ref.watch(expenseFilterProvider);

    return Column(children: [
      // Month summary bar
      _MonthBar(),

      // Filter chips
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: kPad, vertical: 8),
        child: Row(
          children: ExpenseFilter.values.map((f) {
            final label = {
              ExpenseFilter.all: 'All',
              ExpenseFilter.today: 'Today',
              ExpenseFilter.thisWeek: 'This Week',
              ExpenseFilter.thisMonth: 'This Month',
            }[f]!;
            final sel = f == filter;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(label),
                selected: sel,
                onSelected: (_) {
                  ref.read(expenseFilterProvider.notifier).state = f;
                  ref.read(expensesProvider.notifier).load();
                },
                selectedColor: kPrimary,
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                    color: sel ? Colors.white : kTextPrimary,
                    fontWeight: FontWeight.w500),
                backgroundColor: kCard,
                side: BorderSide(color: sel ? kPrimary : kDivider),
              ),
            );
          }).toList(),
        ),
      ),

      // Grouped list
      Expanded(
        child: expensesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (expenses) {
            if (expenses.isEmpty) {
              return const Center(
                child: Text('No expenses yet.', style: TextStyle(color: kTextSecondary)),
              );
            }
            // Group by date
            final grouped = <DateTime, List<Expense>>{};
            for (final e in expenses) {
              final day = DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day);
              grouped.putIfAbsent(day, () => []).add(e);
            }
            final days = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(kPad, 0, kPad, 120),
              itemCount: days.length,
              itemBuilder: (_, i) {
                final day = days[i];
                final items = grouped[day]!;
                final total = items.fold<double>(0, (s, e) => s + e.amount);
                final isToday = _isSameDay(day, DateTime.now());
                final isYest = _isSameDay(day,
                    DateTime.now().subtract(const Duration(days: 1)));
                final label = isToday
                    ? 'Today'
                    : isYest
                        ? 'Yesterday'
                        : DateFormat('EEE, d MMM').format(day);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
                      child: Row(children: [
                        Text(label,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: kTextSecondary,
                                letterSpacing: 0.4)),
                        const Spacer(),
                        Text('−${formatCurrency(total)}',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: kLoss)),
                      ]),
                    ),
                    ...items.map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _ExpenseRow(
                            expense: e,
                            onTap: () => _openSheet(editing: e),
                            onDelete: () async {
                              await ref.read(expensesProvider.notifier).delete(e);
                              _refresh();
                            },
                          ),
                        )),
                  ],
                );
              },
            );
          },
        ),
      ),
    ]);
  }
}

// ── Calendar grid ─────────────────────────────────────────────────────────────

class _CalendarGrid extends StatelessWidget {
  final DateTime month;
  final DateTime selectedDate;
  final Set<DateTime> datesWithExpenses;
  final ValueChanged<DateTime> onDateSelected;

  const _CalendarGrid({
    required this.month,
    required this.selectedDate,
    required this.datesWithExpenses,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final startOffset = firstDay.weekday - 1; // Mon=0
    final today = DateTime.now();

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Column(children: [
        // Day-of-week header
        Row(
          children: ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su']
              .map((d) => Expanded(
                    child: Center(
                      child: Text(d,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: kTextSecondary)),
                    ),
                  ))
              .toList(),
        ),
        const Gap(4),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
            childAspectRatio: 1,
          ),
          itemCount: startOffset + daysInMonth,
          itemBuilder: (_, index) {
            if (index < startOffset) return const SizedBox();
            final day = index - startOffset + 1;
            final date = DateTime(month.year, month.month, day);
            final normDate = DateTime(date.year, date.month, date.day);
            final isSelected = _isSameDay(date, selectedDate);
            final isToday = _isSameDay(date, today);
            final hasExp = datesWithExpenses.contains(normDate);

            return GestureDetector(
              onTap: () => onDateSelected(date),
              child: Container(
                margin: const EdgeInsets.all(1),
                decoration: BoxDecoration(
                  color: isSelected ? kPrimary : isToday ? kPrimaryLight : null,
                  shape: BoxShape.circle,
                ),
                child: Stack(alignment: Alignment.center, children: [
                  Text('$day',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isToday || isSelected
                            ? FontWeight.w700
                            : FontWeight.normal,
                        color: isSelected
                            ? Colors.white
                            : isToday
                                ? kPrimary
                                : kTextPrimary,
                      )),
                  if (hasExp && !isSelected)
                    Positioned(
                      bottom: 3,
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                            color: kLoss, shape: BoxShape.circle),
                      ),
                    ),
                ]),
              ),
            );
          },
        ),
      ]),
    );
  }
}

// ── Month summary bar ─────────────────────────────────────────────────────────

class _MonthBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<double>(
      future: ref.read(expenseRepoProvider).getTotalForMonth(),
      builder: (_, snap) {
        final total = snap.data ?? 0;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(kPad, 12, kPad, 12),
          color: kCard,
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('THIS MONTH',
                  style: TextStyle(
                      fontSize: 11,
                      color: kTextSecondary,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5)),
              const Gap(2),
              Text(formatCurrency(total),
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
            ]),
          ]),
        );
      },
    );
  }
}

// ── Expense row (with swipe-to-delete) ───────────────────────────────────────

class _ExpenseRow extends StatelessWidget {
  final Expense expense;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ExpenseRow({
    required this.expense,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cat = _catFor(expense.category);
    return Dismissible(
      key: ValueKey(expense.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: kLoss,
          borderRadius: BorderRadius.circular(kRadius),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: Colors.white, size: 22),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete expense?'),
            content: Text(
                '"${expense.title}" — ${formatCurrency(expense.amount)}'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel')),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(foregroundColor: kLoss),
                  child: const Text('Delete')),
            ],
          ),
        );
      },
      onDismissed: (_) => onDelete(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(kRadius),
            border: Border.all(color: kDivider),
          ),
          child: Row(children: [
            // Category icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cat.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(cat.icon, size: 20, color: cat.color),
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
                    Text(formatTime(expense.timestamp),
                        style: const TextStyle(
                            color: kTextSecondary, fontSize: 12)),
                    if (expense.category != null) ...[
                      const Text(' · ',
                          style: TextStyle(color: kTextSecondary, fontSize: 12)),
                      Text(expense.category!,
                          style: const TextStyle(
                              color: kTextSecondary, fontSize: 12)),
                    ],
                  ]),
                ],
              ),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('−${formatCurrency(expense.amount)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: kLoss)),
              const Gap(2),
              const Icon(Icons.chevron_right_rounded,
                  size: 16, color: kTextSecondary),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ── Empty day ─────────────────────────────────────────────────────────────────

class _EmptyDay extends StatelessWidget {
  final DateTime date;
  final VoidCallback onAdd;
  const _EmptyDay({required this.date, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final isToday = _isSameDay(date, DateTime.now());
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.receipt_long_outlined, size: 48, color: kTextSecondary.withOpacity(0.5)),
        const Gap(12),
        Text(
          isToday ? 'No expenses today' : 'No expenses on ${DateFormat("d MMM").format(date)}',
          style: const TextStyle(color: kTextSecondary, fontSize: 15),
        ),
        const Gap(8),
        TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add, size: 16),
          label: Text(isToday ? 'Add expense' : 'Add for this day'),
        ),
      ]),
    );
  }
}

// ── Add / Edit sheet ──────────────────────────────────────────────────────────

class _ExpenseSheet extends StatefulWidget {
  final WidgetRef ref;
  final Expense? editing; // null = add mode
  final DateTime initialDate;

  const _ExpenseSheet({
    required this.ref,
    this.editing,
    required this.initialDate,
  });

  @override
  State<_ExpenseSheet> createState() => _ExpenseSheetState();
}

class _ExpenseSheetState extends State<_ExpenseSheet> {
  final _amountCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String? _category;
  late DateTime _date;
  bool _saving = false;

  bool get _isEdit => widget.editing != null;
  bool get _isToday => _isSameDay(_date, DateTime.now());

  @override
  void initState() {
    super.initState();
    _date = DateTime(widget.initialDate.year, widget.initialDate.month,
        widget.initialDate.day);
    if (_isEdit) {
      final e = widget.editing!;
      _amountCtrl.text =
          e.amount == e.amount.truncateToDouble() ? e.amount.toInt().toString() : e.amount.toStringAsFixed(2);
      _titleCtrl.text = e.title;
      _notesCtrl.text = e.notes ?? '';
      _category = e.category;
      _date = DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day);
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      helpText: 'Select expense date',
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.trim());

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
      return;
    }
    if (title.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter what you spent on')));
      return;
    }

    setState(() => _saving = true);

    final now = DateTime.now();
    final timestamp = _isEdit
        ? DateTime(_date.year, _date.month, _date.day,
            widget.editing!.timestamp.hour, widget.editing!.timestamp.minute)
        : DateTime(_date.year, _date.month, _date.day,
            now.hour, now.minute, now.second);

    if (_isEdit) {
      final updated = widget.editing!.copyWith(
        title: title,
        amount: amount,
        timestamp: timestamp,
        category: _category,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      await widget.ref
          .read(expensesProvider.notifier)
          .update(updated, widget.editing!.amount);
    } else {
      await widget.ref.read(expensesProvider.notifier).add(Expense(
            title: title,
            amount: amount,
            timestamp: timestamp,
            category: _category,
            notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          ));
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete expense?'),
        content: Text(
            '"${widget.editing!.title}" — ${formatCurrency(widget.editing!.amount)}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: kLoss),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await widget.ref.read(expensesProvider.notifier).delete(widget.editing!);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(kPad, 16, kPad, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: kDivider, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const Gap(16),

              // Title row
              Row(children: [
                Text(_isEdit ? 'Edit Expense' : 'Add Expense',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const Spacer(),
                // Date badge
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isToday ? kPrimaryLight : const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: _isToday ? kPrimary : const Color(0xFFF97316)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 12,
                          color: _isToday ? kPrimary : const Color(0xFFF97316)),
                      const Gap(4),
                      Text(
                        _isToday ? 'Today' : DateFormat('d MMM').format(_date),
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _isToday
                                ? kPrimary
                                : const Color(0xFFF97316)),
                      ),
                    ]),
                  ),
                ),
              ]),
              if (!_isToday)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    DateFormat('EEEE, d MMMM yyyy').format(_date),
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFFF97316)),
                  ),
                ),
              const Gap(16),

              // Amount — large, prominent
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: kBackground,
                  borderRadius: BorderRadius.circular(kRadius),
                  border: Border.all(color: kDivider),
                ),
                child: Row(children: [
                  Text('₹',
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: kTextSecondary.withOpacity(0.6))),
                  const Gap(8),
                  Expanded(
                    child: TextField(
                      controller: _amountCtrl,
                      autofocus: !_isEdit,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                      ],
                      style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        fillColor: Colors.transparent,
                        hintText: '0',
                        hintStyle: TextStyle(color: kDivider),
                      ),
                    ),
                  ),
                ]),
              ),
              const Gap(12),

              // Title
              TextFormField(
                controller: _titleCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                    hintText: 'What was this for?',
                    prefixIcon: Icon(Icons.edit_outlined, size: 18)),
              ),
              const Gap(12),

              // Category grid
              const Text('CATEGORY',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: kTextSecondary,
                      letterSpacing: 0.5)),
              const Gap(8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _cats.map((cat) {
                  final sel = _category == cat.label;
                  return GestureDetector(
                    onTap: () => setState(() =>
                        _category = sel ? null : cat.label),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: sel
                            ? cat.color.withOpacity(0.15)
                            : kBackground,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: sel ? cat.color : kDivider,
                            width: sel ? 1.5 : 1),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(cat.icon,
                            size: 14,
                            color: sel ? cat.color : kTextSecondary),
                        const Gap(5),
                        Text(cat.label,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: sel
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: sel ? cat.color : kTextSecondary)),
                      ]),
                    ),
                  );
                }).toList(),
              ),
              const Gap(12),

              // Notes
              TextFormField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                    hintText: 'Notes (optional)',
                    prefixIcon: Icon(Icons.notes_rounded, size: 18)),
              ),
              const Gap(20),

              // Buttons
              if (_isEdit) ...[
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : _delete,
                      icon: const Icon(Icons.delete_outline_rounded, size: 16),
                      label: const Text('Delete'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: kLoss,
                          side: const BorderSide(color: kLoss),
                          padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: _saving
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text('Save Changes'),
                    ),
                  ),
                ]),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: _saving
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text(_isToday
                            ? 'Add Expense'
                            : 'Add for ${DateFormat("d MMM").format(_date)}'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Helper ────────────────────────────────────────────────────────────────────

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
