import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../../core/constants.dart';
import '../../../core/formatters.dart';
import '../../../data/repositories/expense_repository.dart';
import '../../../providers/providers.dart';

// ── Pie chart colour palette ──────────────────────────────────────────────────

const _kPalette = [
  Color(0xFF2563EB), // blue
  Color(0xFF10B981), // green
  Color(0xFFF59E0B), // amber
  Color(0xFFEF4444), // red
  Color(0xFF8B5CF6), // violet
  Color(0xFF06B6D4), // cyan
  Color(0xFFF97316), // orange
  Color(0xFFEC4899), // pink
  Color(0xFF14B8A6), // teal
  Color(0xFF84CC16), // lime
];

Color _colorFor(int i) => _kPalette[i % _kPalette.length];

// ── Screen ───────────────────────────────────────────────────────────────────

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  int _touchedExpense = -1;
  int _touchedPortfolio = -1;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Expenses'),
            Tab(text: 'Portfolio'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _ExpensesTab(
            touchedIndex: _touchedExpense,
            onTouch: (i) => setState(() => _touchedExpense = i),
          ),
          _PortfolioTab(
            touchedIndex: _touchedPortfolio,
            onTouch: (i) => setState(() => _touchedPortfolio = i),
          ),
        ],
      ),
    );
  }
}

// ── Expenses tab ─────────────────────────────────────────────────────────────

class _ExpensesTab extends ConsumerStatefulWidget {
  final int touchedIndex;
  final ValueChanged<int> onTouch;
  const _ExpensesTab({required this.touchedIndex, required this.onTouch});

  @override
  ConsumerState<_ExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends ConsumerState<_ExpensesTab> {
  ExpenseFilter _filter = ExpenseFilter.thisMonth;

  @override
  Widget build(BuildContext context) {
    final categoriesAsync =
        ref.watch(expenseCategoryProvider(_filter));

    return categoriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (categories) {
        final total = categories.fold<double>(0, (s, c) => s + c.total);

        return ListView(
          padding: const EdgeInsets.fromLTRB(kPad, kPad, kPad, 40),
          children: [
            // ── Filter chips ──
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'Today',
                    selected: _filter == ExpenseFilter.today,
                    onTap: () =>
                        setState(() => _filter = ExpenseFilter.today),
                  ),
                  const Gap(8),
                  _FilterChip(
                    label: 'This Week',
                    selected: _filter == ExpenseFilter.thisWeek,
                    onTap: () =>
                        setState(() => _filter = ExpenseFilter.thisWeek),
                  ),
                  const Gap(8),
                  _FilterChip(
                    label: 'This Month',
                    selected: _filter == ExpenseFilter.thisMonth,
                    onTap: () =>
                        setState(() => _filter = ExpenseFilter.thisMonth),
                  ),
                  const Gap(8),
                  _FilterChip(
                    label: 'All Time',
                    selected: _filter == ExpenseFilter.all,
                    onTap: () =>
                        setState(() => _filter = ExpenseFilter.all),
                  ),
                ],
              ),
            ),

            const Gap(20),

            if (categories.isEmpty) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Text('No expenses for this period.',
                      style:
                          TextStyle(color: kTextSecondary, fontSize: 15)),
                ),
              ),
            ] else ...[
              // ── Total ──
              _TotalCard(
                label: 'Total Spent',
                value: formatCurrency(total),
                color: kLoss,
              ),

              const Gap(20),

              // ── Pie chart ──
              _PieSection(
                title: 'Spending by Category',
                sections: categories
                    .asMap()
                    .entries
                    .map((e) => PieChartSectionData(
                          value: e.value.total,
                          color: _colorFor(e.key),
                          radius: widget.touchedIndex == e.key ? 68 : 55,
                          title: widget.touchedIndex == e.key
                              ? '${(e.value.total / total * 100).toStringAsFixed(1)}%'
                              : '',
                          titleStyle: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700),
                        ))
                    .toList(),
                touchedIndex: widget.touchedIndex,
                onTouch: widget.onTouch,
              ),

              const Gap(20),

              // ── Legend ──
              _LegendCard(
                items: categories
                    .asMap()
                    .entries
                    .map((e) => _LegendItem(
                          color: _colorFor(e.key),
                          label: e.value.name,
                          value: formatCurrency(e.value.total),
                          percent:
                              '${(e.value.total / total * 100).toStringAsFixed(1)}%',
                        ))
                    .toList(),
              ),
            ],
          ],
        );
      },
    );
  }
}

// ── Portfolio tab ─────────────────────────────────────────────────────────────

class _PortfolioTab extends ConsumerWidget {
  final int touchedIndex;
  final ValueChanged<int> onTouch;
  const _PortfolioTab(
      {required this.touchedIndex, required this.onTouch});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(portfolioSummaryProvider);
    final assets = summary.assets;

    if (assets.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 40),
          child: Text('No investments yet.',
              style: TextStyle(color: kTextSecondary, fontSize: 15)),
        ),
      );
    }

    final total = summary.currentValue;

    return ListView(
      padding: const EdgeInsets.fromLTRB(kPad, kPad, kPad, 40),
      children: [
        // ── Summary cards ──
        Row(children: [
          Expanded(
            child: _TotalCard(
              label: 'Invested',
              value: formatCurrency(summary.totalInvested),
              color: kPrimary,
            ),
          ),
          const Gap(10),
          Expanded(
            child: _TotalCard(
              label: 'Current Value',
              value: formatCurrency(summary.currentValue),
              color: summary.pnl >= 0 ? kGain : kLoss,
            ),
          ),
        ]),

        const Gap(10),

        _TotalCard(
          label:
              'P&L  ${summary.pnl >= 0 ? '+' : ''}${summary.returnPercent.toStringAsFixed(2)}%',
          value:
              '${summary.pnl >= 0 ? '+' : ''}${formatCurrency(summary.pnl)}',
          color: summary.pnl >= 0 ? kGain : kLoss,
        ),

        const Gap(20),

        // ── Allocation pie ──
        _PieSection(
          title: 'Portfolio Allocation',
          sections: assets
              .asMap()
              .entries
              .map((e) => PieChartSectionData(
                    value: e.value.effectiveValue,
                    color: _colorFor(e.key),
                    radius: touchedIndex == e.key ? 68 : 55,
                    title: touchedIndex == e.key
                        ? '${(e.value.effectiveValue / total * 100).toStringAsFixed(1)}%'
                        : '',
                    titleStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                  ))
              .toList(),
          touchedIndex: touchedIndex,
          onTouch: onTouch,
        ),

        const Gap(20),

        // ── Legend ──
        _LegendCard(
          items: assets
              .asMap()
              .entries
              .map((e) => _LegendItem(
                    color: _colorFor(e.key),
                    label: e.value.name,
                    value: formatCurrency(e.value.effectiveValue),
                    percent: total > 0
                        ? '${(e.value.effectiveValue / total * 100).toStringAsFixed(1)}%'
                        : '—',
                  ))
              .toList(),
        ),

        const Gap(20),

        // ── Asset type breakdown ──
        _TypeBreakdownCard(assets: assets),
      ],
    );
  }
}

// ── Reusable widgets ──────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? kPrimary : kCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? kPrimary : kDivider),
          ),
          child: Text(
            label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : kTextSecondary),
          ),
        ),
      );
}

class _TotalCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _TotalCard(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: kPad, vertical: 14),
        decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(kRadius),
            border: Border.all(color: kDivider)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: kTextSecondary)),
            const Gap(4),
            Text(value,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: -0.5)),
          ],
        ),
      );
}

class _PieSection extends StatelessWidget {
  final String title;
  final List<PieChartSectionData> sections;
  final int touchedIndex;
  final ValueChanged<int> onTouch;
  const _PieSection(
      {required this.title,
      required this.sections,
      required this.touchedIndex,
      required this.onTouch});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(kPad),
        decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(kRadiusLg),
            border: Border.all(color: kDivider)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700)),
            const Gap(16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 48,
                  sectionsSpace: 2,
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      if (!event.isInterestedForInteractions ||
                          response == null ||
                          response.touchedSection == null) {
                        onTouch(-1);
                        return;
                      }
                      onTouch(response
                          .touchedSection!.touchedSectionIndex);
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

class _LegendCard extends StatelessWidget {
  final List<_LegendItem> items;
  const _LegendCard({required this.items});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(kPad),
        decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(kRadiusLg),
            border: Border.all(color: kDivider)),
        child: Column(
          children: items
              .expand((item) => [
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                              color: item.color,
                              shape: BoxShape.circle),
                        ),
                        const Gap(10),
                        Expanded(
                          child: Text(item.label,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                        ),
                        Text(item.percent,
                            style: const TextStyle(
                                fontSize: 12, color: kTextSecondary)),
                        const Gap(12),
                        Text(item.value,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const Divider(height: 14),
                  ])
              .toList()
            ..removeLast(),
        ),
      );
}

class _LegendItem {
  final Color color;
  final String label;
  final String value;
  final String percent;
  const _LegendItem(
      {required this.color,
      required this.label,
      required this.value,
      required this.percent});
}

class _TypeBreakdownCard extends StatelessWidget {
  final List<dynamic> assets;
  const _TypeBreakdownCard({required this.assets});

  @override
  Widget build(BuildContext context) {
    // group by type
    final map = <String, double>{};
    for (final a in assets) {
      final label = kAssetTypeLabels[a.type] ?? (a.type as String);
      map[label] = (map[label] ?? 0) + (a.effectiveValue as double);
    }
    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = sorted.fold<double>(0, (s, e) => s + e.value);

    return Container(
      padding: const EdgeInsets.all(kPad),
      decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(kRadiusLg),
          border: Border.all(color: kDivider)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('By Asset Type',
              style:
                  TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const Gap(12),
          ...sorted.map((e) {
            final pct = total > 0 ? e.value / total : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: Text(e.key,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500))),
                      Text(
                          '${(pct * 100).toStringAsFixed(1)}%  ${formatCurrency(e.value)}',
                          style: const TextStyle(
                              fontSize: 12, color: kTextSecondary)),
                    ],
                  ),
                  const Gap(4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 6,
                      backgroundColor: kDivider,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(kPrimary),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
