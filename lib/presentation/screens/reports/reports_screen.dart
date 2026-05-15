import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import '../../../core/constants.dart';
import '../../../core/formatters.dart';
import '../../../data/database/database_helper.dart';
import '../../../data/repositories/expense_repository.dart';
import '../../../providers/providers.dart';

const _kPalette = [
  Color(0xFF2563EB), Color(0xFF10B981), Color(0xFFF59E0B), Color(0xFFEF4444),
  Color(0xFF8B5CF6), Color(0xFF06B6D4), Color(0xFFF97316), Color(0xFFEC4899),
  Color(0xFF14B8A6), Color(0xFF84CC16),
];

Color _colorFor(int i) => _kPalette[i % _kPalette.length];

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
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Spending'),
            Tab(text: 'Portfolio'),
            Tab(text: 'Trends'),
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
          const _TrendsTab(),
        ],
      ),
    );
  }
}

// ── Spending tab ─────────────────────────────────────────────────────────────

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
    final categoriesAsync = ref.watch(expenseCategoryProvider(_filter));

    return categoriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (categories) {
        final total = categories.fold<double>(0, (s, c) => s + c.total);

        return ListView(
          padding: const EdgeInsets.fromLTRB(kPad, kPad, kPad, 40),
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _FilterChip(label: 'Today', selected: _filter == ExpenseFilter.today,
                    onTap: () => setState(() => _filter = ExpenseFilter.today)),
                const Gap(8),
                _FilterChip(label: 'This Week', selected: _filter == ExpenseFilter.thisWeek,
                    onTap: () => setState(() => _filter = ExpenseFilter.thisWeek)),
                const Gap(8),
                _FilterChip(label: 'This Month', selected: _filter == ExpenseFilter.thisMonth,
                    onTap: () => setState(() => _filter = ExpenseFilter.thisMonth)),
                const Gap(8),
                _FilterChip(label: 'All Time', selected: _filter == ExpenseFilter.all,
                    onTap: () => setState(() => _filter = ExpenseFilter.all)),
              ]),
            ),
            const Gap(20),
            if (categories.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Text('No expenses for this period.',
                      style: TextStyle(color: kTextSecondary, fontSize: 15)),
                ),
              )
            else ...[
              _TotalCard(label: 'Total Spent', value: formatCurrency(total), color: kLoss),
              const Gap(20),
              _PieSection(
                title: 'Spending by Category',
                sections: categories.asMap().entries.map((e) => PieChartSectionData(
                  value: e.value.total,
                  color: _colorFor(e.key),
                  radius: widget.touchedIndex == e.key ? 68 : 55,
                  title: widget.touchedIndex == e.key
                      ? '${(e.value.total / total * 100).toStringAsFixed(1)}%' : '',
                  titleStyle: const TextStyle(color: Colors.white,
                      fontSize: 12, fontWeight: FontWeight.w700),
                )).toList(),
                touchedIndex: widget.touchedIndex,
                onTouch: widget.onTouch,
              ),
              const Gap(20),
              _LegendCard(items: categories.asMap().entries.map((e) => _LegendItem(
                color: _colorFor(e.key), label: e.value.name,
                value: formatCurrency(e.value.total),
                percent: '${(e.value.total / total * 100).toStringAsFixed(1)}%',
              )).toList()),
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
  const _PortfolioTab({required this.touchedIndex, required this.onTouch});

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
        Row(children: [
          Expanded(child: _TotalCard(label: 'Invested',
              value: formatCurrency(summary.totalInvested), color: kPrimary)),
          const Gap(10),
          Expanded(child: _TotalCard(label: 'Current Value',
              value: formatCurrency(summary.currentValue),
              color: summary.pnl >= 0 ? kGain : kLoss)),
        ]),
        const Gap(10),
        _TotalCard(
          label: 'P&L  ${summary.pnl >= 0 ? '+' : ''}${summary.returnPercent.toStringAsFixed(2)}%',
          value: '${summary.pnl >= 0 ? '+' : ''}${formatCurrency(summary.pnl)}',
          color: summary.pnl >= 0 ? kGain : kLoss,
        ),
        const Gap(20),
        _PieSection(
          title: 'Portfolio Allocation',
          sections: assets.asMap().entries.map((e) => PieChartSectionData(
            value: e.value.effectiveValue,
            color: _colorFor(e.key),
            radius: touchedIndex == e.key ? 68 : 55,
            title: touchedIndex == e.key
                ? '${(e.value.effectiveValue / total * 100).toStringAsFixed(1)}%' : '',
            titleStyle: const TextStyle(color: Colors.white,
                fontSize: 12, fontWeight: FontWeight.w700),
          )).toList(),
          touchedIndex: touchedIndex,
          onTouch: onTouch,
        ),
        const Gap(20),
        _LegendCard(items: assets.asMap().entries.map((e) => _LegendItem(
          color: _colorFor(e.key), label: e.value.name,
          value: formatCurrency(e.value.effectiveValue),
          percent: total > 0
              ? '${(e.value.effectiveValue / total * 100).toStringAsFixed(1)}%' : '—',
        )).toList()),
        const Gap(20),
        _TypeBreakdownCard(assets: assets),
      ],
    );
  }
}

// ── Trends tab ────────────────────────────────────────────────────────────────

class _TrendsTab extends ConsumerWidget {
  const _TrendsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendsAsync = ref.watch(monthlyTrendsProvider);
    final snapshotsAsync = ref.watch(netWorthSnapshotsProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(kPad, kPad, kPad, 40),
      children: [
        // ── Monthly income vs expense bar chart ──
        trendsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const SizedBox(),
          data: (months) => _MonthlyBarChart(months: months),
        ),

        const Gap(20),

        // ── Savings rate trend ──
        trendsAsync.when(
          loading: () => const SizedBox(),
          error: (_, __) => const SizedBox(),
          data: (months) => _SavingsRateCard(months: months),
        ),

        const Gap(20),

        // ── Net worth history line chart ──
        snapshotsAsync.when(
          loading: () => const SizedBox(),
          error: (_, __) => const SizedBox(),
          data: (snapshots) => snapshots.length < 2
              ? Container(
                  padding: const EdgeInsets.all(kPad),
                  decoration: BoxDecoration(
                    color: kCard,
                    borderRadius: BorderRadius.circular(kRadiusLg),
                    border: Border.all(color: kDivider),
                  ),
                  child: const Center(
                    child: Text('Net worth history will appear\nafter a few days of use.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: kTextSecondary, fontSize: 13)),
                  ),
                )
              : _NetWorthLineChart(snapshots: snapshots),
        ),
      ],
    );
  }
}

class _MonthlyBarChart extends StatefulWidget {
  final List<MonthlyStats> months;
  const _MonthlyBarChart({required this.months});

  @override
  State<_MonthlyBarChart> createState() => _MonthlyBarChartState();
}

class _MonthlyBarChartState extends State<_MonthlyBarChart> {
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    final months = widget.months;
    if (months.isEmpty) return const SizedBox();

    final maxVal = months.fold<double>(0, (m, s) =>
        [m, s.income, s.expenses].reduce((a, b) => a > b ? a : b));

    return Container(
      padding: const EdgeInsets.all(kPad),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(kRadiusLg),
        border: Border.all(color: kDivider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Income vs Expenses',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const Gap(4),
        const Text('Last 6 months',
            style: TextStyle(fontSize: 12, color: kTextSecondary)),
        const Gap(16),
        SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              maxY: maxVal * 1.2,
              barTouchData: BarTouchData(
                touchCallback: (event, resp) {
                  if (!event.isInterestedForInteractions ||
                      resp == null || resp.spot == null) {
                    setState(() => _touched = -1);
                    return;
                  }
                  setState(() => _touched = resp.spot!.touchedBarGroupIndex);
                },
                touchTooltipData: BarTouchTooltipData(
                  tooltipRoundedRadius: 8,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final m = months[groupIndex];
                    final label = rodIndex == 0
                        ? 'Income: ${formatCurrency(m.income)}'
                        : 'Spent: ${formatCurrency(m.expenses)}';
                    return BarTooltipItem(label,
                        const TextStyle(color: Colors.white, fontSize: 12));
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (val, meta) {
                      final i = val.toInt();
                      if (i < 0 || i >= months.length) return const SizedBox();
                      final m = months[i];
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          DateFormat('MMM').format(DateTime(m.year, m.month)),
                          style: const TextStyle(
                              fontSize: 10, color: kTextSecondary),
                        ),
                      );
                    },
                    reservedSize: 24,
                  ),
                ),
                leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) =>
                    const FlLine(color: kDivider, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              barGroups: months.asMap().entries.map((e) {
                final i = e.key;
                final m = e.value;
                final isTouched = _touched == i;
                return BarChartGroupData(
                  x: i,
                  groupVertically: false,
                  barRods: [
                    BarChartRodData(
                      toY: m.income,
                      color: isTouched
                          ? kGain
                          : kGain.withOpacity(0.7),
                      width: 10,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4)),
                    ),
                    BarChartRodData(
                      toY: m.expenses,
                      color: isTouched
                          ? kLoss
                          : kLoss.withOpacity(0.7),
                      width: 10,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4)),
                    ),
                  ],
                  barsSpace: 4,
                );
              }).toList(),
            ),
          ),
        ),
        const Gap(12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _ChartLegendDot(color: kGain, label: 'Income'),
          const Gap(16),
          _ChartLegendDot(color: kLoss, label: 'Expenses'),
        ]),
      ]),
    );
  }
}

class _ChartLegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _ChartLegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 10, height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const Gap(6),
    Text(label, style: const TextStyle(fontSize: 12, color: kTextSecondary)),
  ]);
}

class _SavingsRateCard extends StatelessWidget {
  final List<MonthlyStats> months;
  const _SavingsRateCard({required this.months});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(kPad),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(kRadiusLg),
        border: Border.all(color: kDivider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Monthly Savings Rate',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const Gap(12),
        ...months.map((m) {
          final color = m.savingsRate >= 20
              ? kGain
              : m.savingsRate >= 10
                  ? const Color(0xFFF59E0B)
                  : kLoss;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              SizedBox(
                width: 36,
                child: Text(
                  DateFormat('MMM').format(DateTime(m.year, m.month)),
                  style: const TextStyle(fontSize: 12, color: kTextSecondary),
                ),
              ),
              const Gap(8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (m.savingsRate / 100).clamp(0.0, 1.0),
                    minHeight: 7,
                    backgroundColor: kDivider,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ),
              const Gap(8),
              SizedBox(
                width: 40,
                child: Text(
                  '${m.savingsRate.toStringAsFixed(0)}%',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: color),
                  textAlign: TextAlign.right,
                ),
              ),
            ]),
          );
        }),
      ]),
    );
  }
}

class _NetWorthLineChart extends StatelessWidget {
  final List<NetWorthSnapshot> snapshots;
  const _NetWorthLineChart({required this.snapshots});

  @override
  Widget build(BuildContext context) {
    final spots = snapshots.asMap().entries.map((e) =>
        FlSpot(e.key.toDouble(), e.value.netWorth)).toList();

    final minY = snapshots.fold<double>(double.infinity,
        (m, s) => s.netWorth < m ? s.netWorth : m);
    final maxY = snapshots.fold<double>(double.negativeInfinity,
        (m, s) => s.netWorth > m ? s.netWorth : m);
    final range = maxY - minY;

    return Container(
      padding: const EdgeInsets.all(kPad),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(kRadiusLg),
        border: Border.all(color: kDivider),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Net Worth History',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        Text(
          '${snapshots.first.date} → ${snapshots.last.date}',
          style: const TextStyle(fontSize: 11, color: kTextSecondary),
        ),
        const Gap(16),
        SizedBox(
          height: 180,
          child: LineChart(
            LineChartData(
              minY: (minY - range * 0.1),
              maxY: (maxY + range * 0.1),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  tooltipRoundedRadius: 8,
                  getTooltipItems: (spots) => spots.map((s) {
                    final snap = snapshots[s.x.toInt()];
                    return LineTooltipItem(
                      '${snap.date}\n${formatCurrency(s.y)}',
                      const TextStyle(color: Colors.white, fontSize: 11),
                    );
                  }).toList(),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) =>
                    const FlLine(color: kDivider, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: (snapshots.length / 4).ceilToDouble(),
                    getTitlesWidget: (val, _) {
                      final i = val.toInt();
                      if (i < 0 || i >= snapshots.length) return const SizedBox();
                      final parts = snapshots[i].date.split('-');
                      if (parts.length < 3) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('${parts[2]}/${parts[1]}',
                            style: const TextStyle(
                                fontSize: 9, color: kTextSecondary)),
                      );
                    },
                    reservedSize: 22,
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: kPrimary,
                  barWidth: 2.5,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: kPrimary.withOpacity(0.1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Reusable widgets ──────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? kPrimary : kCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? kPrimary : kDivider),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : kTextSecondary)),
        ),
      );
}

class _TotalCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _TotalCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: kPad, vertical: 14),
        decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(kRadius),
            border: Border.all(color: kDivider)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 12, color: kTextSecondary)),
          const Gap(4),
          Text(value,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700,
                  color: color, letterSpacing: -0.5)),
        ]),
      );
}

class _PieSection extends StatelessWidget {
  final String title;
  final List<PieChartSectionData> sections;
  final int touchedIndex;
  final ValueChanged<int> onTouch;
  const _PieSection({required this.title, required this.sections,
      required this.touchedIndex, required this.onTouch});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(kPad),
        decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(kRadiusLg),
            border: Border.all(color: kDivider)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const Gap(16),
          SizedBox(
            height: 200,
            child: PieChart(PieChartData(
              sections: sections,
              centerSpaceRadius: 48,
              sectionsSpace: 2,
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  if (!event.isInterestedForInteractions ||
                      response == null || response.touchedSection == null) {
                    onTouch(-1);
                    return;
                  }
                  onTouch(response.touchedSection!.touchedSectionIndex);
                },
              ),
            )),
          ),
        ]),
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
          children: items.expand((item) => [
            Row(children: [
              Container(width: 12, height: 12,
                  decoration: BoxDecoration(color: item.color, shape: BoxShape.circle)),
              const Gap(10),
              Expanded(child: Text(item.label,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
              Text(item.percent,
                  style: const TextStyle(fontSize: 12, color: kTextSecondary)),
              const Gap(12),
              Text(item.value,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
            const Divider(height: 14),
          ]).toList()..removeLast(),
        ),
      );
}

class _LegendItem {
  final Color color;
  final String label;
  final String value;
  final String percent;
  const _LegendItem({required this.color, required this.label,
      required this.value, required this.percent});
}

class _TypeBreakdownCard extends StatelessWidget {
  final List<dynamic> assets;
  const _TypeBreakdownCard({required this.assets});

  @override
  Widget build(BuildContext context) {
    final map = <String, double>{};
    for (final a in assets) {
      final label = kAssetTypeLabels[a.type] ?? (a.type as String);
      map[label] = (map[label] ?? 0) + (a.effectiveValue as double);
    }
    final sorted = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = sorted.fold<double>(0, (s, e) => s + e.value);

    return Container(
      padding: const EdgeInsets.all(kPad),
      decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(kRadiusLg),
          border: Border.all(color: kDivider)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('By Asset Type',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const Gap(12),
        ...sorted.map((e) {
          final pct = total > 0 ? e.value / total : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(e.key,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                Text('${(pct * 100).toStringAsFixed(1)}%  ${formatCurrency(e.value)}',
                    style: const TextStyle(fontSize: 12, color: kTextSecondary)),
              ]),
              const Gap(4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct, minHeight: 6,
                  backgroundColor: kDivider,
                  valueColor: const AlwaysStoppedAnimation<Color>(kPrimary),
                ),
              ),
            ]),
          );
        }),
      ]),
    );
  }
}
