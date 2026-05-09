import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../../core/constants.dart';
import '../../../core/formatters.dart';
import '../../../data/models/investment_asset_model.dart';
import '../../../data/services/search_service.dart';
import '../../../providers/providers.dart';
import '../../widgets/amount_badge.dart';
import 'asset_detail_screen.dart';

class InvestmentsScreen extends ConsumerStatefulWidget {
  const InvestmentsScreen({super.key});

  @override
  ConsumerState<InvestmentsScreen> createState() => _InvestmentsScreenState();
}

class _InvestmentsScreenState extends ConsumerState<InvestmentsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoRefresh());
  }

  Future<void> _autoRefresh() async {
    final key = await ref.read(settingsRepoProvider).getGeminiApiKey();
    if (key == null || key.isEmpty) return;
    final assets = ref.read(investmentsProvider).value ?? [];
    if (assets.isEmpty) return;
    final stale = assets.any((a) =>
        a.lastUpdatedAt == null ||
        DateTime.now().difference(a.lastUpdatedAt!).inHours > 6);
    if (!stale) return;
    ref.read(priceRefreshingProvider.notifier).state = true;
    await ref.read(investmentsProvider.notifier).refreshAll();
    ref.read(priceRefreshingProvider.notifier).state = false;
  }

  Future<void> _manualRefresh() async {
    final key = await ref.read(settingsRepoProvider).getGeminiApiKey();
    if (!mounted) return;
    if (key == null || key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Add your Gemini API key in Settings first'),
          backgroundColor: kLoss));
      return;
    }
    ref.read(priceRefreshingProvider.notifier).state = true;
    final err = await ref.read(investmentsProvider.notifier).refreshAll();
    ref.read(priceRefreshingProvider.notifier).state = false;
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(err),
          backgroundColor: kLoss,
          duration: const Duration(seconds: 6)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✓ Prices updated via Gemini')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final assetsAsync = ref.watch(investmentsProvider);
    final summary = ref.watch(portfolioSummaryProvider);
    final settings = ref.watch(settingsProvider).value;
    final isRefreshing = ref.watch(priceRefreshingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Investments'),
        actions: [
          if (isRefreshing)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                  child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh all prices',
              onPressed: _manualRefresh,
            ),
        ],
      ),
      body: assetsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (assets) {
          if (assets.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.show_chart_rounded,
                      size: 60, color: kTextSecondary),
                  const Gap(16),
                  const Text('No investments yet',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: kTextPrimary)),
                  const Gap(8),
                  const Text('Track where your money is growing.',
                      style: TextStyle(color: kTextSecondary, fontSize: 14)),
                  const Gap(24),
                  FilledButton.icon(
                    onPressed: () => _showAddSheet(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Investment'),
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(kPad, 0, kPad, 100),
            children: [
              if (settings?.lastPortfolioUpdate != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.update, size: 13, color: kTextSecondary),
                      const Gap(4),
                      Text(
                        'Updated ${relativeDate(settings!.lastPortfolioUpdate!)}',
                        style: const TextStyle(
                            color: kTextSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                )
              else
                const Gap(8),

              // ── Summary card ──
              Container(
                padding: const EdgeInsets.all(kPad),
                decoration: BoxDecoration(
                  color: kCard,
                  borderRadius: BorderRadius.circular(kRadiusLg),
                  border: Border.all(color: kDivider),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _SummaryCell(
                            label: 'Invested',
                            value: formatCurrency(summary.totalInvested)),
                        _SummaryCell(
                            label: 'Current Value',
                            value: formatCurrency(summary.currentValue)),
                      ],
                    ),
                    const Gap(10),
                    const Divider(height: 1),
                    const Gap(10),
                    Row(
                      children: [
                        _SummaryCell(
                          label: 'P&L',
                          value:
                              '${summary.pnl >= 0 ? '+' : ''}${formatCurrency(summary.pnl)}',
                          valueColor: summary.pnl >= 0 ? kGain : kLoss,
                        ),
                        _SummaryCell(
                          label: 'Return',
                          value:
                              '${summary.returnPercent >= 0 ? '+' : ''}${summary.returnPercent.toStringAsFixed(2)}%',
                          valueColor:
                              summary.returnPercent >= 0 ? kGain : kLoss,
                        ),
                      ],
                    ),
                    if (summary.hasMissing) ...[
                      const Gap(8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.info_outline,
                                size: 13, color: Color(0xFFD97706)),
                            Gap(6),
                            Expanded(
                              child: Text(
                                'Tap ↻ to fetch live prices via Gemini',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFFD97706),
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const Gap(16),

              ...assets.map((a) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _AssetCard(asset: a),
                  )),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Investment'),
      ),
    );
  }
}

class _SummaryCell extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _SummaryCell(
      {required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    color: kTextSecondary,
                    fontWeight: FontWeight.w500)),
            const Gap(2),
            Text(value,
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: valueColor ?? kTextPrimary,
                    letterSpacing: -0.3)),
          ],
        ),
      );
}

class _AssetCard extends ConsumerWidget {
  final InvestmentAsset asset;
  const _AssetCard({required this.asset});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pct = asset.returnPct;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => AssetDetailScreen(assetId: asset.id!)),
      ),
      child: Container(
        padding: const EdgeInsets.all(kPad),
        decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(kRadius),
            border: Border.all(color: kDivider)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(asset.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                ),
                if (pct != null) PnlBadge(percent: pct),
              ],
            ),
            const Gap(4),
            Row(
              children: [
                _Chip(kAssetTypeLabels[asset.type] ?? asset.type),
                if (asset.symbol != null && asset.symbol!.isNotEmpty)
                  _Chip(asset.symbol!),
                if (asset.investedAt != null)
                  _Chip(
                      'Since ${_shortDate(asset.investedAt!)}'),
              ],
            ),
            const Gap(10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Invested',
                          style:
                              TextStyle(fontSize: 11, color: kTextSecondary)),
                      Text(formatCurrency(asset.amountInvested),
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          asset.currentValue != null
                              ? 'Current Value'
                              : 'No price yet',
                          style: const TextStyle(
                              fontSize: 11, color: kTextSecondary)),
                      Text(
                          asset.currentValue != null
                              ? formatCurrency(asset.currentValue!)
                              : '—',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: asset.pnl != null
                                  ? (asset.pnl! >= 0 ? kGain : kLoss)
                                  : kTextPrimary)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _shortDate(DateTime d) =>
      '${_months[d.month - 1]} ${d.year}';

  static const _months = [
    'Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec'
  ];
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip(this.label);

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(right: 6, bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
            color: kBackground,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kDivider)),
        child: Text(label,
            style: const TextStyle(
                fontSize: 11,
                color: kTextSecondary,
                fontWeight: FontWeight.w500)),
      );
}

// ── Add Investment Sheet ──────────────────────────────────────────────────────

void _showAddSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddInvestmentSheet(parentRef: ref),
  );
}

class _AddInvestmentSheet extends StatefulWidget {
  final WidgetRef parentRef;
  const _AddInvestmentSheet({required this.parentRef});

  @override
  State<_AddInvestmentSheet> createState() => _AddInvestmentSheetState();
}

class _AddInvestmentSheetState extends State<_AddInvestmentSheet> {
  final _searchCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  List<InvestmentSuggestion> _suggestions = [];
  bool _searching = false;
  String _type = 'other';
  String? _autoFilledFrom;
  DateTime? _investedAt;
  bool _saving = false;

  // Debounce + stale-result guard
  String _lastQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSearchChanged(String raw) async {
    final q = raw.trim();
    if (q.length < 2) {
      setState(() { _suggestions = []; _searching = false; });
      return;
    }

    // Debounce: wait 400ms, then check if query is still the same
    _lastQuery = q;
    setState(() => _searching = true);
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted || _lastQuery != q) return; // user kept typing

    final results = await SearchService.search(q);
    if (!mounted || _lastQuery != q) return; // stale result
    setState(() { _suggestions = results; _searching = false; });
  }

  void _selectSuggestion(InvestmentSuggestion s) {
    setState(() {
      _nameCtrl.text = s.name;
      _type = s.type;
      _suggestions = [];
      _searchCtrl.clear();
      _autoFilledFrom = s.name;
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _pickType(BuildContext context) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _TypePickerSheet(),
    );
    if (picked != null) setState(() => _type = picked);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _investedAt ?? now,
      firstDate: DateTime(2000),
      lastDate: now,
      helpText: 'When did you invest?',
    );
    if (picked != null) setState(() => _investedAt = picked);
  }

  static const _months = [
    'Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec'
  ];

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter investment name')));
      return;
    }
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
      return;
    }
    setState(() => _saving = true);
    // Find symbol from search suggestions history — if name matches autoFill, use suggestion symbol
    final asset = InvestmentAsset(
      name: name,
      type: _type,
      amountInvested: amount,
      createdAt: DateTime.now(),
      investedAt: _investedAt,
    );
    final newId =
        await widget.parentRef.read(investmentsProvider.notifier).addAndGetId(asset);
    if (mounted) Navigator.pop(context);
    if (newId != null) {
      final assets = widget.parentRef.read(investmentsProvider).value ?? [];
      final candidates = assets.where((a) => a.id == newId).toList();
      if (candidates.isNotEmpty) {
        widget.parentRef.read(priceRefreshingProvider.notifier).state = true;
        await widget.parentRef
            .read(investmentsProvider.notifier)
            .refreshOne(candidates.first);
        widget.parentRef.read(priceRefreshingProvider.notifier).state = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        padding: const EdgeInsets.fromLTRB(kPad, kPad, kPad, 0),
        child: SingleChildScrollView(
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
                        borderRadius: BorderRadius.circular(2))),
              ),
              const Gap(16),
              const Text('Add Investment',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const Gap(16),

              // ── Search bar (populates name below) ──
              TextField(
                controller: _searchCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  labelText: 'Search fund / stock / scheme',
                  hintText: 'Type to search: HDFC, Gold, GRT, FD…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2)))
                      : _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _suggestions = []);
                              })
                          : null,
                ),
              ),

              // ── Dropdown results ──
              if (_suggestions.isNotEmpty) ...[
                const Gap(4),
                Container(
                  constraints: const BoxConstraints(maxHeight: 220),
                  decoration: BoxDecoration(
                    color: kCard,
                    border: Border.all(color: kDivider),
                    borderRadius: BorderRadius.circular(kRadius),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2)),
                    ],
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _suggestions.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 16),
                    itemBuilder: (_, i) {
                      final s = _suggestions[i];
                      return ListTile(
                        dense: true,
                        leading: _typeIcon(s.type),
                        title: Text(s.name,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500)),
                        subtitle: Text(
                            kAssetTypeLabels[s.type] ?? s.type,
                            style: const TextStyle(
                                fontSize: 11, color: kTextSecondary)),
                        onTap: () => _selectSuggestion(s),
                      );
                    },
                  ),
                ),
              ],

              const Gap(12),

              // ── Name field (always editable) ──
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) {
                  if (_autoFilledFrom != null &&
                      _nameCtrl.text != _autoFilledFrom) {
                    setState(() => _autoFilledFrom = null);
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Investment name',
                  hintText: 'e.g. HDFC Nifty 50, GRT Gold, PPF',
                  helperText: _autoFilledFrom != null
                      ? 'Auto-filled — edit freely'
                      : null,
                  helperStyle: const TextStyle(
                      color: kPrimary, fontSize: 11),
                ),
              ),

              const Gap(12),

              // ── Type picker ──
              GestureDetector(
                onTap: () => _pickType(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: kDivider),
                    borderRadius: BorderRadius.circular(kRadius),
                  ),
                  child: Row(
                    children: [
                      _typeIcon(_type),
                      const Gap(10),
                      Expanded(
                        child: Text(
                          kAssetTypeLabels[_type] ?? _type,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down,
                          color: kTextSecondary),
                    ],
                  ),
                ),
              ),

              const Gap(12),

              // ── Amount ──
              TextFormField(
                controller: _amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                ],
                decoration: const InputDecoration(
                    labelText: 'Amount invested (₹)',
                    hintText: '50000',
                    prefixText: '₹  '),
              ),

              const Gap(12),

              // ── Investment date ──
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: kDivider),
                    borderRadius: BorderRadius.circular(kRadius),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded,
                          size: 18, color: kTextSecondary),
                      const Gap(10),
                      Expanded(
                        child: Text(
                          _investedAt != null
                              ? 'Invested on ${_investedAt!.day} ${_months[_investedAt!.month - 1]} ${_investedAt!.year}'
                              : 'Investment date (optional — for exact P&L)',
                          style: TextStyle(
                              fontSize: 14,
                              color: _investedAt != null
                                  ? kTextPrimary
                                  : kTextSecondary),
                        ),
                      ),
                      if (_investedAt != null)
                        GestureDetector(
                          onTap: () => setState(() => _investedAt = null),
                          child: const Icon(Icons.close_rounded,
                              size: 16, color: kTextSecondary),
                        ),
                    ],
                  ),
                ),
              ),

              const Gap(20),
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
                      : const Text('Add & Fetch Price'),
                ),
              ),
              const Gap(kPad),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeIcon(String type) {
    final icons = <String, IconData>{
      'mutual_fund': Icons.account_balance_rounded,
      'stocks': Icons.trending_up_rounded,
      'us_stocks': Icons.public_rounded,
      'gold_etf': Icons.bar_chart_rounded,
      'silver_etf': Icons.bar_chart_rounded,
      'reit': Icons.apartment_rounded,
      'crypto': Icons.currency_bitcoin_rounded,
      'fixed_deposit': Icons.lock_rounded,
      'recurring_deposit': Icons.repeat_rounded,
      'ppf': Icons.account_balance_rounded,
      'epf': Icons.work_rounded,
      'nps': Icons.elderly_rounded,
      'nsc': Icons.savings_rounded,
      'sgb': Icons.monetization_on_rounded,
      'bonds': Icons.receipt_long_rounded,
      'post_office': Icons.mail_rounded,
      'physical_gold': Icons.diamond_rounded,
      'physical_silver': Icons.circle_rounded,
      'real_estate': Icons.home_rounded,
      'ulip': Icons.security_rounded,
      'gold_scheme': Icons.diamond_rounded,
      'chit_fund': Icons.groups_rounded,
    };
    return Icon(icons[type] ?? Icons.savings_rounded,
        size: 18, color: kTextSecondary);
  }
}

// ── Type picker sheet (grouped) ───────────────────────────────────────────────

class _TypePickerSheet extends StatelessWidget {
  const _TypePickerSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Gap(12),
          Center(
            child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: kDivider,
                    borderRadius: BorderRadius.circular(2))),
          ),
          const Gap(12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: kPad),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Select Investment Type',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          const Gap(8),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(kPad, 0, kPad, kPad),
              children: kAssetTypeGroups.entries.map((group) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Gap(12),
                    Text(group.key,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: kTextSecondary,
                            letterSpacing: 0.8)),
                    const Gap(6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: group.value.map((type) {
                        return GestureDetector(
                          onTap: () => Navigator.pop(context, type),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: kDivider),
                              borderRadius: BorderRadius.circular(20),
                              color: kBackground,
                            ),
                            child: Text(
                              kAssetTypeLabels[type] ?? type,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
