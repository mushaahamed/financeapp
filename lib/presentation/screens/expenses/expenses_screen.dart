import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import '../../../core/constants.dart';
import '../../../core/formatters.dart';
import '../../../data/models/expense_model.dart';
import '../../../data/repositories/expense_repository.dart';
import '../../../providers/providers.dart';
import '../../widgets/add_transaction_sheet.dart';

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
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadMonth() async {
    final dates = await ref
        .read(expenseRepoProvider)
        .getDatesWithExpensesInMonth(
            _focusedMonth.year, _focusedMonth.month);
    if (mounted) setState(() => _datesWithExpenses = dates);
  }

  Future<void> _loadDay() async {
    final list = await ref
        .read(expenseRepoProvider)
        .getExpensesForDate(_selectedDate);
    if (mounted) setState(() => _dayExpenses = list);
  }

  void _refresh() {
    _loadMonth();
    _loadDay();
    ref.read(expensesProvider.notifier).load();
    ref.invalidate(dashboardSummaryProvider);
    ref.invalidate(categorySpendingProvider);
  }

  Future<void> _openSheet({Expense? editing, DateTime? date}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTransactionSheet(
        ref: ref,
        editing: editing,
        initialDate:
            date ?? (editing?.timestamp ?? _selectedDate),
      ),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(
                icon: Icon(Icons.calendar_month_outlined),
                text: 'Calendar'),
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
              date: _tabs.index == 0
                  ? _selectedDate
                  : DateTime.now(),
            ),
            icon: const Icon(Icons.add),
            label: Text(_tabs.index == 1 || isToday
                ? 'Add Transaction'
                : 'Add for ${DateFormat("d MMM").format(_selectedDate)}'),
          );
        },
      ),
    );
  }

  // ── Calendar tab ──────────────────────────────────────────────────────────

  Widget _calendarTab() {
    final expenses =
        _dayExpenses.where((e) => !e.isIncome).toList();
    final income = _dayExpenses.where((e) => e.isIncome).toList();
    final dayTotal =
        expenses.fold<double>(0, (s, e) => s + e.amount);
    final dayIncome =
        income.fold<double>(0, (s, e) => s + e.amount);
    final isToday = _isSameDay(_selectedDate, DateTime.now());

    return Column(children: [
      Container(
        color: kCard,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () {
                  setState(() => _focusedMonth = DateTime(
                      _focusedMonth.year, _focusedMonth.month - 1));
                  _loadMonth();
                },
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
                onPressed: () {
                  setState(() => _focusedMonth = DateTime(
                      _focusedMonth.year, _focusedMonth.month + 1));
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
            onDateSelected: (d) {
              setState(() => _selectedDate = d);
              _loadDay();
            },
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
              isToday
                  ? 'Today'
                  : DateFormat('EEEE, d MMMM').format(_selectedDate),
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700),
            ),
            if (_dayExpenses.isNotEmpty)
              Text(
                '${_dayExpenses.length} item${_dayExpenses.length > 1 ? "s" : ""}',
                style: const TextStyle(
                    fontSize: 12, color: kTextSecondary)),
          ]),
          const Spacer(),
          if (dayIncome > 0)
            Text('+${formatCurrency(dayIncome)}',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kGain)),
          if (dayIncome > 0 && dayTotal > 0)
            const Text('  ·  ',
                style:
                    TextStyle(fontSize: 13, color: kTextSecondary)),
          if (dayTotal > 0)
            Text('−${formatCurrency(dayTotal)}',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kLoss)),
        ]),
      ),

      Expanded(
        child: _dayExpenses.isEmpty
            ? _EmptyDay(
                date: _selectedDate,
                onAdd: () => _openSheet())
            : ListView.separated(
                padding:
                    const EdgeInsets.fromLTRB(kPad, 8, kPad, 120),
                itemCount: _dayExpenses.length,
                separatorBuilder: (_, __) => const Gap(8),
                itemBuilder: (_, i) => _ExpenseRow(
                  expense: _dayExpenses[i],
                  onTap: () =>
                      _openSheet(editing: _dayExpenses[i]),
                  onDelete: () async {
                    await ref
                        .read(expensesProvider.notifier)
                        .delete(_dayExpenses[i]);
                    _refresh();
                  },
                ),
              ),
      ),
    ]);
  }

  Widget _allTab() => const _AllTab();
}

// ── All tab (stateful for period + view-mode + search) ────────────────────────

class _AllTab extends ConsumerStatefulWidget {
  const _AllTab();
  @override
  ConsumerState<_AllTab> createState() => _AllTabState();
}

class _AllTabState extends ConsumerState<_AllTab> {
  ExpenseFilter _period = ExpenseFilter.thisMonth;
  bool _groupedView = false;
  bool _searchActive = false;
  int _refreshKey = 0;
  String _query = '';
  final Set<String> _expandedGroups = {};
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.read(expensesProvider.notifier).load();
    ref.invalidate(dashboardSummaryProvider);
    ref.invalidate(categorySpendingProvider);
    setState(() => _refreshKey++);
  }

  Future<void> _openSheet({Expense? editing}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTransactionSheet(
        ref: ref,
        editing: editing,
        initialDate: editing?.timestamp ?? DateTime.now(),
      ),
    );
    _refresh();
  }

  List<Expense> _applySearch(List<Expense> list) {
    if (_query.trim().isEmpty) return list;
    final q = _query.trim().toLowerCase();
    return list.where((e) {
      return e.title.toLowerCase().contains(q) ||
          (e.category?.toLowerCase().contains(q) ?? false) ||
          (e.notes?.toLowerCase().contains(q) ?? false) ||
          (e.paymentMethod?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Expense>>(
      future: ref.read(expenseRepoProvider).getExpenses(_period),
      key: ValueKey('$_period/$_refreshKey'),
      builder: (context, snap) {
        final allExpenses = snap.data ?? [];
        final expenses = _applySearch(allExpenses);

        final income = expenses
            .where((e) => e.isIncome)
            .fold<double>(0, (s, e) => s + e.amount);
        final spent = expenses
            .where((e) => !e.isIncome)
            .fold<double>(0, (s, e) => s + e.amount);
        final net = income - spent;

        return Column(children: [
          // ── Search bar (when active) ──
          if (_searchActive)
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(kPad, 8, kPad, 0),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search transactions…',
                  prefixIcon: const Icon(Icons.search_rounded,
                      size: 20),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close_rounded,
                        size: 18),
                    onPressed: () => setState(() {
                      _searchActive = false;
                      _query = '';
                      _searchCtrl.clear();
                    }),
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 10),
                ),
              ),
            ),

          // ── Period filter chips ──
          if (!_searchActive)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.fromLTRB(kPad, 10, kPad, 4),
              child: Row(
                children: [
                  ExpenseFilter.thisWeek,
                  ExpenseFilter.thisMonth,
                  ExpenseFilter.thisYear,
                  ExpenseFilter.all,
                ].map((f) {
                  final label = {
                    ExpenseFilter.thisWeek: 'This Week',
                    ExpenseFilter.thisMonth: 'This Month',
                    ExpenseFilter.thisYear: 'This Year',
                    ExpenseFilter.all: 'All Time',
                  }[f]!;
                  final sel = f == _period;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(label),
                      selected: sel,
                      onSelected: (_) => setState(() {
                        _period = f;
                        _expandedGroups.clear();
                      }),
                      selectedColor: kPrimary,
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                          color: sel ? Colors.white : kTextPrimary,
                          fontWeight: FontWeight.w500,
                          fontSize: 13),
                      backgroundColor: kCard,
                      side: BorderSide(
                          color: sel ? kPrimary : kDivider),
                    ),
                  );
                }).toList(),
              ),
            ),

          // ── Period summary bar ──
          if (snap.hasData)
            Container(
              padding:
                  const EdgeInsets.fromLTRB(kPad, 8, kPad, 8),
              color: kCard,
              child: Row(children: [
                _PeriodStat(
                    label: 'Income',
                    value: income,
                    color: kGain),
                const _VDivider(),
                _PeriodStat(
                    label: 'Spent',
                    value: spent,
                    color: kLoss),
                const _VDivider(),
                _PeriodStat(
                  label: 'Net',
                  value: net.abs(),
                  color: net >= 0 ? kGain : kLoss,
                  prefix: net >= 0 ? '+' : '−',
                ),
                const Spacer(),
                // Search toggle
                IconButton(
                  tooltip: 'Search',
                  icon: Icon(
                    _searchActive
                        ? Icons.search_off_rounded
                        : Icons.search_rounded,
                    size: 20,
                  ),
                  onPressed: () => setState(() {
                    _searchActive = !_searchActive;
                    if (!_searchActive) {
                      _query = '';
                      _searchCtrl.clear();
                    }
                  }),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                // View mode toggle
                IconButton(
                  tooltip: _groupedView
                      ? 'List view'
                      : 'Grouped view',
                  icon: Icon(
                    _groupedView
                        ? Icons.list_rounded
                        : Icons.segment_rounded,
                    size: 20,
                  ),
                  onPressed: () => setState(() {
                    _groupedView = !_groupedView;
                    _expandedGroups.clear();
                  }),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ]),
            ),

          const Divider(height: 1),

          // ── Content ──
          Expanded(
            child: snap.connectionState ==
                    ConnectionState.waiting
                ? const Center(
                    child: CircularProgressIndicator())
                : expenses.isEmpty
                    ? (_query.isNotEmpty
                        ? _EmptySearch(query: _query)
                        : const _EmptyAll())
                    : _groupedView
                        ? _GroupedView(
                            expenses: expenses,
                            expandedGroups: _expandedGroups,
                            onToggleGroup: (k) => setState(() {
                              if (_expandedGroups.contains(k)) {
                                _expandedGroups.remove(k);
                              } else {
                                _expandedGroups.add(k);
                              }
                            }),
                            onTapEntry: (e) =>
                                _openSheet(editing: e),
                            onDeleteEntry: (e) async {
                              await ref
                                  .read(expensesProvider.notifier)
                                  .delete(e);
                              _refresh();
                            },
                          )
                        : _ListView(
                            expenses: expenses,
                            onTap: (e) =>
                                _openSheet(editing: e),
                            onDelete: (e) async {
                              await ref
                                  .read(expensesProvider.notifier)
                                  .delete(e);
                              _refresh();
                            },
                          ),
          ),
        ]);
      },
    );
  }
}

// ── Period stat ───────────────────────────────────────────────────────────────

class _PeriodStat extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final String prefix;
  const _PeriodStat({
    required this.label,
    required this.value,
    required this.color,
    this.prefix = '',
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              fontSize: 10,
              color: kTextSecondary,
              fontWeight: FontWeight.w600)),
      const Gap(2),
      Text('$prefix${formatCurrency(value)}',
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color)),
    ]);
  }
}

class _VDivider extends StatelessWidget {
  const _VDivider();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14),
        child:
            SizedBox(height: 28, child: VerticalDivider(width: 1)),
      );
}

// ── List view (grouped by date) ───────────────────────────────────────────────

class _ListView extends StatelessWidget {
  final List<Expense> expenses;
  final ValueChanged<Expense> onTap;
  final ValueChanged<Expense> onDelete;
  const _ListView({
    required this.expenses,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
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
        final spent = items
            .where((e) => !e.isIncome)
            .fold<double>(0, (s, e) => s + e.amount);
        final income = items
            .where((e) => e.isIncome)
            .fold<double>(0, (s, e) => s + e.amount);
        final isToday = _isSameDay(day, DateTime.now());
        final isYest = _isSameDay(
            day, DateTime.now().subtract(const Duration(days: 1)));
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
              if (income > 0)
                Text('+${formatCurrency(income)}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: kGain)),
              if (income > 0 && spent > 0)
                const Text('  ',
                    style: TextStyle(fontSize: 12)),
              if (spent > 0)
                Text('−${formatCurrency(spent)}',
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
                  onTap: () => onTap(e),
                  onDelete: () => onDelete(e),
                ),
              )),
        ]);
      },
    );
  }
}

// ── Grouped view (by title) ───────────────────────────────────────────────────

class _TitleGroup {
  final String title;
  final List<Expense> entries;
  final bool isIncome;
  double get total => entries.fold(0, (s, e) => s + e.amount);
  _TitleGroup(
      {required this.title,
      required this.entries,
      required this.isIncome});
}

class _GroupedView extends StatelessWidget {
  final List<Expense> expenses;
  final Set<String> expandedGroups;
  final ValueChanged<String> onToggleGroup;
  final ValueChanged<Expense> onTapEntry;
  final ValueChanged<Expense> onDeleteEntry;

  const _GroupedView({
    required this.expenses,
    required this.expandedGroups,
    required this.onToggleGroup,
    required this.onTapEntry,
    required this.onDeleteEntry,
  });

  @override
  Widget build(BuildContext context) {
    Map<String, _TitleGroup> buildGroups(
        List<Expense> list, bool isIncome) {
      final map = <String, _TitleGroup>{};
      for (final e in list) {
        final key = e.title.trim().toLowerCase();
        final display = e.title.trim();
        if (!map.containsKey(key)) {
          map[key] = _TitleGroup(
              title: display, entries: [], isIncome: isIncome);
        }
        map[key]!.entries.add(e);
      }
      final sorted = map.entries.toList()
        ..sort((a, b) =>
            b.value.total.compareTo(a.value.total));
      return Map.fromEntries(sorted);
    }

    final expenseGroups = buildGroups(
        expenses.where((e) => !e.isIncome).toList(), false);
    final incomeGroups = buildGroups(
        expenses.where((e) => e.isIncome).toList(), true);

    final sections = <Widget>[];

    void addSection(String header, Map<String, _TitleGroup> groups,
        Color headerColor) {
      if (groups.isEmpty) return;
      sections.add(Padding(
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
        child: Text(header,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: headerColor,
                letterSpacing: 0.5)),
      ));
      for (final entry in groups.entries) {
        final groupKey = '${header}_${entry.key}';
        final group = entry.value;
        final isExpanded = expandedGroups.contains(groupKey);
        final cat = group.isIncome
            ? incCatFor(group.entries.first.category)
            : expCatFor(group.entries.first.category);

        sections.add(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => onToggleGroup(groupKey),
              child: Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: kCard,
                  borderRadius:
                      BorderRadius.circular(kRadius),
                  border: Border.all(
                    color: isExpanded
                        ? (group.isIncome ? kGain : kLoss)
                            .withAlpha(100)
                        : kDivider,
                  ),
                ),
                child: Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: cat.color.withAlpha(30),
                      borderRadius:
                          BorderRadius.circular(10),
                    ),
                    child: Icon(cat.icon,
                        size: 20, color: cat.color),
                  ),
                  const Gap(12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                      Text(group.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                      Text(
                        '${group.entries.length} transaction${group.entries.length > 1 ? "s" : ""}',
                        style: const TextStyle(
                            color: kTextSecondary,
                            fontSize: 12),
                      ),
                    ]),
                  ),
                  Text(
                    group.isIncome
                        ? '+${formatCurrency(group.total)}'
                        : '−${formatCurrency(group.total)}',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: group.isIncome
                            ? kGain
                            : kLoss),
                  ),
                  const Gap(6),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: kTextSecondary,
                  ),
                ]),
              ),
            ),
            if (isExpanded)
              Container(
                margin:
                    const EdgeInsets.only(left: 16, bottom: 4),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                        color: (group.isIncome ? kGain : kLoss)
                            .withAlpha(76),
                        width: 2),
                  ),
                ),
                child: Column(
                  children: group.entries
                      .map((e) => Padding(
                            padding: const EdgeInsets.only(
                                left: 8, bottom: 4),
                            child: _ExpenseRow(
                              expense: e,
                              onTap: () => onTapEntry(e),
                              onDelete: () =>
                                  onDeleteEntry(e),
                              compact: true,
                            ),
                          ))
                      .toList(),
                ),
              ),
          ],
        ));
      }
    }

    addSection('EXPENSES', expenseGroups, kLoss);
    addSection('INCOME', incomeGroups, kGain);

    return ListView(
      padding: const EdgeInsets.fromLTRB(kPad, 0, kPad, 120),
      children: sections,
    );
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
    final daysInMonth =
        DateTime(month.year, month.month + 1, 0).day;
    final startOffset = firstDay.weekday - 1;
    final today = DateTime.now();

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Column(children: [
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
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
            childAspectRatio: 1,
          ),
          itemCount: startOffset + daysInMonth,
          itemBuilder: (_, index) {
            if (index < startOffset) return const SizedBox();
            final day = index - startOffset + 1;
            final date =
                DateTime(month.year, month.month, day);
            final normDate =
                DateTime(date.year, date.month, date.day);
            final isSelected =
                _isSameDay(date, selectedDate);
            final isToday = _isSameDay(date, today);
            final hasExp =
                datesWithExpenses.contains(normDate);

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
                            color: kLoss,
                            shape: BoxShape.circle),
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

// ── Expense row ───────────────────────────────────────────────────────────────

class _ExpenseRow extends StatelessWidget {
  final Expense expense;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final bool compact;

  const _ExpenseRow({
    required this.expense,
    required this.onTap,
    required this.onDelete,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final cat = catForExpense(expense);
    final isIncome = expense.isIncome;

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
            title: Text(
                'Delete ${isIncome ? "income" : "expense"}?'),
            content: Text(
                '"${expense.title}" — ${formatCurrency(expense.amount)}'),
            actions: [
              TextButton(
                  onPressed: () =>
                      Navigator.pop(context, false),
                  child: const Text('Cancel')),
              TextButton(
                  onPressed: () =>
                      Navigator.pop(context, true),
                  style: TextButton.styleFrom(
                      foregroundColor: kLoss),
                  child: const Text('Delete')),
            ],
          ),
        );
      },
      onDismissed: (_) => onDelete(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: 14, vertical: compact ? 10 : 12),
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
                color: cat.color.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  Icon(cat.icon, size: 20, color: cat.color),
            ),
            const Gap(12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(expense.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                const Gap(2),
                Row(children: [
                  Text(
                    compact
                        ? DateFormat('d MMM, h:mm a')
                            .format(expense.timestamp)
                        : formatTime(expense.timestamp),
                    style: const TextStyle(
                        color: kTextSecondary,
                        fontSize: 12),
                  ),
                  if (expense.category != null) ...[
                    const Text(' · ',
                        style: TextStyle(
                            color: kTextSecondary,
                            fontSize: 12)),
                    Text(expense.category!,
                        style: const TextStyle(
                            color: kTextSecondary,
                            fontSize: 12)),
                  ],
                  if (expense.paymentMethod != null) ...[
                    const Text(' · ',
                        style: TextStyle(
                            color: kTextSecondary,
                            fontSize: 12)),
                    Text(expense.paymentMethod!,
                        style: const TextStyle(
                            color: kTextSecondary,
                            fontSize: 12)),
                  ],
                ]),
              ]),
            ),
            Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
              Text(
                isIncome
                    ? '+${formatCurrency(expense.amount)}'
                    : '−${formatCurrency(expense.amount)}',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: isIncome ? kGain : kLoss),
              ),
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

// ── Empty states ──────────────────────────────────────────────────────────────

class _EmptyDay extends StatelessWidget {
  final DateTime date;
  final VoidCallback onAdd;
  const _EmptyDay({required this.date, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final isToday = _isSameDay(date, DateTime.now());
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.receipt_long_outlined,
            size: 48, color: kTextSecondary.withAlpha(127)),
        const Gap(12),
        Text(
          isToday
              ? 'No transactions today'
              : 'No transactions on ${DateFormat("d MMM").format(date)}',
          style: const TextStyle(
              color: kTextSecondary, fontSize: 15),
        ),
        const Gap(8),
        TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add, size: 16),
          label: Text(
              isToday ? 'Add transaction' : 'Add for this day'),
        ),
      ]),
    );
  }
}

class _EmptyAll extends StatelessWidget {
  const _EmptyAll();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('No transactions in this period.',
          style:
              TextStyle(color: kTextSecondary, fontSize: 15)),
    );
  }
}

class _EmptySearch extends StatelessWidget {
  final String query;
  const _EmptySearch({required this.query});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.search_off_rounded,
            size: 48, color: kTextSecondary.withAlpha(127)),
        const Gap(12),
        Text('No results for "$query"',
            style: const TextStyle(
                color: kTextSecondary, fontSize: 15)),
      ]),
    );
  }
}

// ── Helper ────────────────────────────────────────────────────────────────────

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
