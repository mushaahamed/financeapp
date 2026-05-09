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

// ── Main screen ───────────────────────────────────────────────────────────────

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
  bool _calendarLoading = false;
  bool _dayLoading = false;

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
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadMonth() async {
    if (!mounted) return;
    setState(() => _calendarLoading = true);
    final dates = await ref
        .read(expenseRepoProvider)
        .getDatesWithExpensesInMonth(_focusedMonth.year, _focusedMonth.month);
    if (mounted) setState(() { _datesWithExpenses = dates; _calendarLoading = false; });
  }

  Future<void> _loadDay() async {
    if (!mounted) return;
    setState(() => _dayLoading = true);
    final expenses =
        await ref.read(expenseRepoProvider).getExpensesForDate(_selectedDate);
    if (mounted) setState(() { _dayExpenses = expenses; _dayLoading = false; });
  }

  void _prevMonth() {
    setState(() => _focusedMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month - 1));
    _loadMonth();
  }

  void _nextMonth() {
    setState(() => _focusedMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month + 1));
    _loadMonth();
  }

  void _selectDate(DateTime d) {
    setState(() => _selectedDate = d);
    _loadDay();
  }

  Future<void> _openAdd({DateTime? date}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddExpenseSheet(
        ref: ref,
        initialDate: date ?? _selectedDate,
      ),
    );
    _loadMonth();
    _loadDay();
    // Also refresh the All-tab list
    ref.read(expensesProvider.notifier).load();
    ref.invalidate(dashboardSummaryProvider);
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
        children: [
          _buildCalendarTab(),
          _buildAllTab(),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabs,
        builder: (_, __) {
          if (_tabs.index == 1) {
            return FloatingActionButton(
              onPressed: () => _openAdd(date: DateTime.now()),
              child: const Icon(Icons.add),
            );
          }
          final isToday = _isSameDay(_selectedDate, DateTime.now());
          return FloatingActionButton.extended(
            onPressed: () => _openAdd(),
            icon: const Icon(Icons.add),
            label: Text(isToday
                ? 'Add Expense'
                : 'Add for ${DateFormat("d MMM").format(_selectedDate)}'),
          );
        },
      ),
    );
  }

  // ── Calendar tab ──────────────────────────────────────────────────────────

  Widget _buildCalendarTab() {
    final dayTotal =
        _dayExpenses.fold<double>(0, (s, e) => s + e.amount);
    final isToday = _isSameDay(_selectedDate, DateTime.now());

    return Column(
      children: [
        // Calendar card
        Container(
          color: kCard,
          child: Column(
            children: [
              // Month navigation
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: _prevMonth,
                      visualDensity: VisualDensity.compact,
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          DateFormat('MMMM yyyy').format(_focusedMonth),
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: _nextMonth,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              _CalendarGrid(
                month: _focusedMonth,
                selectedDate: _selectedDate,
                datesWithExpenses: _datesWithExpenses,
                onDateSelected: _selectDate,
                loading: _calendarLoading,
              ),
              const Divider(height: 1),
            ],
          ),
        ),

        // Selected day header
        Container(
          color: kBackground,
          padding: const EdgeInsets.fromLTRB(kPad, 10, kPad, 8),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isToday
                        ? 'Today'
                        : DateFormat('EEEE, d MMMM').format(_selectedDate),
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: kTextPrimary),
                  ),
                  if (_dayExpenses.isNotEmpty)
                    Text(
                      '${_dayExpenses.length} expense${_dayExpenses.length > 1 ? "s" : ""}',
                      style: const TextStyle(
                          fontSize: 12, color: kTextSecondary),
                    ),
                ],
              ),
              const Spacer(),
              if (_dayExpenses.isNotEmpty)
                Text(
                  '−${formatCurrency(dayTotal)}',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: kLoss),
                ),
            ],
          ),
        ),

        // Day expense list
        Expanded(
          child: _dayLoading
              ? const Center(child: CircularProgressIndicator())
              : _dayExpenses.isEmpty
                  ? _EmptyDay(
                      date: _selectedDate,
                      onAdd: () => _openAdd(),
                    )
                  : ListView.separated(
                      padding:
                          const EdgeInsets.fromLTRB(kPad, 8, kPad, 120),
                      itemCount: _dayExpenses.length,
                      separatorBuilder: (_, __) => const Gap(8),
                      itemBuilder: (_, i) => _ExpenseTile(
                        _dayExpenses[i],
                        onChanged: () {
                          _loadMonth();
                          _loadDay();
                          ref.read(expensesProvider.notifier).load();
                          ref.invalidate(dashboardSummaryProvider);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  // ── All-expenses tab ──────────────────────────────────────────────────────

  Widget _buildAllTab() {
    final filter = ref.watch(expenseFilterProvider);
    final expensesAsync = ref.watch(expensesProvider);

    return Column(
      children: [
        // Month total banner
        _MonthTotal(),
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
                  side: BorderSide(color: selected ? kPrimary : kDivider),
                ),
              );
            }).toList(),
          ),
        ),
        // List
        Expanded(
          child: expensesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (expenses) {
              if (expenses.isEmpty) {
                return const Center(
                  child: Text('No expenses yet.',
                      style: TextStyle(color: kTextSecondary)),
                );
              }
              // Group by date
              final grouped = <DateTime, List<Expense>>{};
              for (final e in expenses) {
                final day = DateTime(
                    e.timestamp.year, e.timestamp.month, e.timestamp.day);
                grouped.putIfAbsent(day, () => []).add(e);
              }
              final days = grouped.keys.toList()
                ..sort((a, b) => b.compareTo(a));

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(kPad, 0, kPad, 120),
                itemCount: days.length,
                itemBuilder: (_, i) {
                  final day = days[i];
                  final items = grouped[day]!;
                  final total =
                      items.fold<double>(0, (s, e) => s + e.amount);
                  final isToday = _isSameDay(day, DateTime.now());
                  final isYesterday = _isSameDay(
                      day, DateTime.now().subtract(const Duration(days: 1)));
                  final label = isToday
                      ? 'Today'
                      : isYesterday
                          ? 'Yesterday'
                          : DateFormat('EEE, d MMM').format(day);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
                        child: Row(
                          children: [
                            Text(label,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: kTextSecondary,
                                    letterSpacing: 0.3)),
                            const Spacer(),
                            Text('−${formatCurrency(total)}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: kLoss)),
                          ],
                        ),
                      ),
                      ...items.map((e) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _ExpenseTile(
                              e,
                              onChanged: () {
                                _loadMonth();
                                _loadDay();
                                ref.read(expensesProvider.notifier).load();
                                ref.invalidate(dashboardSummaryProvider);
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
      ],
    );
  }
}

// ── Calendar grid ─────────────────────────────────────────────────────────────

class _CalendarGrid extends StatelessWidget {
  final DateTime month;
  final DateTime selectedDate;
  final Set<DateTime> datesWithExpenses;
  final ValueChanged<DateTime> onDateSelected;
  final bool loading;

  const _CalendarGrid({
    required this.month,
    required this.selectedDate,
    required this.datesWithExpenses,
    required this.onDateSelected,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Monday-first offset: Mon=0, Tue=1, …, Sun=6
    final startOffset = firstDay.weekday - 1;
    final today = DateTime.now();

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Column(
        children: [
          // Day-of-week headers
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
          // Day cells
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
              final hasExpenses = datesWithExpenses.contains(normDate);

              return GestureDetector(
                onTap: () => onDateSelected(date),
                child: Container(
                  margin: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? kPrimary
                        : isToday
                            ? kPrimaryLight
                            : null,
                    shape: BoxShape.circle,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        '$day',
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
                        ),
                      ),
                      if (hasExpenses && !isSelected)
                        Positioned(
                          bottom: 3,
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: kLoss,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Empty-day placeholder ─────────────────────────────────────────────────────

class _EmptyDay extends StatelessWidget {
  final DateTime date;
  final VoidCallback onAdd;
  const _EmptyDay({required this.date, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final isToday = _isSameDay(date, DateTime.now());
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.receipt_long_outlined,
              size: 44, color: kTextSecondary),
          const Gap(10),
          Text(
            isToday
                ? 'No expenses today'
                : 'No expenses on ${DateFormat("d MMM").format(date)}',
            style: const TextStyle(color: kTextSecondary, fontSize: 14),
          ),
          const Gap(4),
          TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 16),
            label: Text(isToday ? 'Add one' : 'Add for this day'),
          ),
        ],
      ),
    );
  }
}

// ── Month total banner ────────────────────────────────────────────────────────

class _MonthTotal extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<double>(
      future: ref.read(expenseRepoProvider).getTotalForMonth(),
      builder: (_, snap) {
        final total = snap.data ?? 0;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(kPad, kPad, kPad, 12),
          color: kCard,
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('THIS MONTH',
                      style: TextStyle(
                          fontSize: 11,
                          color: kTextSecondary,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5)),
                  const Gap(2),
                  Text(formatCurrency(total),
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Expense tile ──────────────────────────────────────────────────────────────

class _ExpenseTile extends ConsumerWidget {
  final Expense expense;
  final VoidCallback onChanged;
  const _ExpenseTile(this.expense, {required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () async {
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _ExpenseDetailSheet(expense: expense, ref: ref),
        );
        onChanged();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: kPad, vertical: 12),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(kRadius),
          border: Border.all(color: kDivider),
        ),
        child: Row(
          children: [
            // Category icon circle
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: kPrimaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _categoryIcon(expense.category),
                size: 18,
                color: kPrimary,
              ),
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
                  Row(
                    children: [
                      Text(formatTime(expense.timestamp),
                          style: const TextStyle(
                              color: kTextSecondary, fontSize: 12)),
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
                  fontWeight: FontWeight.w700, fontSize: 14, color: kLoss),
            ),
          ],
        ),
      ),
    );
  }

  IconData _categoryIcon(String? cat) {
    switch (cat) {
      case 'Food & Dining':
        return Icons.restaurant_rounded;
      case 'Shopping':
        return Icons.shopping_bag_outlined;
      case 'Transport':
        return Icons.directions_bus_rounded;
      case 'Health':
        return Icons.favorite_border_rounded;
      case 'Entertainment':
        return Icons.movie_outlined;
      case 'Bills':
        return Icons.receipt_outlined;
      case 'Friends':
        return Icons.people_outline_rounded;
      default:
        return Icons.payments_outlined;
    }
  }
}

// ── Add Expense Sheet (with date picker) ──────────────────────────────────────

class _AddExpenseSheet extends StatefulWidget {
  final WidgetRef ref;
  final DateTime initialDate;
  const _AddExpenseSheet({required this.ref, required this.initialDate});

  @override
  State<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<_AddExpenseSheet> {
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String? _category;
  late DateTime _date;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      helpText: 'Select expense date',
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter what you spent on')));
      return;
    }
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
      return;
    }
    setState(() => _saving = true);

    // Preserve the selected date but use current time-of-day
    final now = DateTime.now();
    final timestamp = DateTime(
        _date.year, _date.month, _date.day, now.hour, now.minute, now.second);

    final expense = Expense(
      title: title,
      amount: amount,
      timestamp: timestamp,
      category: _category,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );
    await widget.ref.read(expensesProvider.notifier).add(expense);
    if (mounted) Navigator.pop(context);
  }

  bool get _isToday => _isSameDay(_date, DateTime.now());

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(kPad),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: kDivider,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const Gap(16),
              Row(
                children: [
                  const Text('Add Expense',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  // Date selector button
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _isToday ? kPrimaryLight : const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: _isToday
                                ? kPrimary
                                : const Color(0xFFF97316)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today_rounded,
                              size: 12,
                              color: _isToday
                                  ? kPrimary
                                  : const Color(0xFFF97316)),
                          const Gap(4),
                          Text(
                            _isToday
                                ? 'Today'
                                : DateFormat('d MMM').format(_date),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _isToday
                                  ? kPrimary
                                  : const Color(0xFFF97316),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (!_isToday)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Recording for ${DateFormat("EEEE, d MMMM").format(_date)}',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFFF97316)),
                  ),
                ),
              const Gap(14),
              TextFormField(
                controller: _titleCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                    hintText: 'What did you spend on?'),
              ),
              const Gap(10),
              TextFormField(
                controller: _amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                ],
                decoration: const InputDecoration(
                    prefixText: '₹  ', hintText: '0'),
              ),
              const Gap(10),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(
                    hintText: 'Category (optional)'),
                items: kExpenseCategories
                    .map((c) =>
                        DropdownMenuItem(value: c, child: Text(c)))
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
                      : Text(_isToday
                          ? 'Add Expense'
                          : 'Add for ${DateFormat("d MMM").format(_date)}'),
                ),
              ),
              const Gap(8),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Edit / detail sheet ───────────────────────────────────────────────────────

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
  late DateTime _date;
  String? _category;
  bool _saving = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.expense.title);
    _amountCtrl =
        TextEditingController(text: widget.expense.amount.toStringAsFixed(2));
    _notesCtrl =
        TextEditingController(text: widget.expense.notes ?? '');
    _category = widget.expense.category;
    _date = widget.expense.timestamp;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
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
    );
    if (picked != null) {
      setState(() => _date =
          DateTime(picked.year, picked.month, picked.day,
              _date.hour, _date.minute));
    }
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (title.isEmpty || amount == null || amount <= 0) return;
    setState(() => _saving = true);
    final updated = widget.expense.copyWith(
      title: title,
      amount: amount,
      timestamp: _date,
      category: _category,
      notes: _notesCtrl.text.trim().isEmpty
          ? null
          : _notesCtrl.text.trim(),
    );
    await widget.ref
        .read(expensesProvider.notifier)
        .update(updated, widget.expense.amount);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Expense?'),
        content: Text(
            'Delete "${widget.expense.title}" of ${formatCurrency(widget.expense.amount)}?'),
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
    setState(() => _deleting = true);
    await widget.ref
        .read(expensesProvider.notifier)
        .delete(widget.expense);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: controller,
          padding: EdgeInsets.fromLTRB(
              kPad, kPad, kPad, MediaQuery.of(context).viewInsets.bottom + 16),
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: kDivider,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const Gap(16),
            const Text('Edit Expense',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const Gap(20),
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const Gap(12),
            TextFormField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
              ],
              decoration: const InputDecoration(
                  labelText: 'Amount', prefixText: '₹  '),
            ),
            const Gap(12),
            DropdownButtonFormField<String>(
              value: _category,
              decoration:
                  const InputDecoration(hintText: 'Category (optional)'),
              items: kExpenseCategories
                  .map((c) =>
                      DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v),
            ),
            const Gap(12),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration:
                  const InputDecoration(labelText: 'Notes (optional)'),
            ),
            const Gap(12),
            // Date/time row
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                    color: kBackground,
                    borderRadius: BorderRadius.circular(kRadius),
                    border: Border.all(color: kDivider)),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 15, color: kTextSecondary),
                    const Gap(10),
                    Text(formatDateTime(_date),
                        style: const TextStyle(fontSize: 14)),
                    const Spacer(),
                    const Text('Change',
                        style: TextStyle(
                            fontSize: 12,
                            color: kPrimary,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            const Gap(24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _deleting ? null : _delete,
                    style: OutlinedButton.styleFrom(
                        foregroundColor: kLoss,
                        side: const BorderSide(color: kLoss)),
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
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
