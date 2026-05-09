import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../../core/constants.dart';
import '../../../core/formatters.dart';
import '../../../data/models/investment_asset_model.dart';
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
    // Auto-refresh when screen opens if Gemini key is set
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoRefresh());
  }

  Future<void> _autoRefresh() async {
    final key = await ref.read(settingsRepoProvider).getGeminiApiKey();
    if (key == null || key.isEmpty) return;
    final assets = ref.read(investmentsProvider).value ?? [];
    if (assets.isEmpty) return;
    // Only refresh if prices are stale (older than 6 hours)
    final stale = assets.any((a) =>
        a.lastUpdatedAt == null ||
        DateTime.now().difference(a.lastUpdatedAt!).inHours > 6);
    if (!stale) return;
    ref.read(priceRefreshingProvider.notifier).state = true;
    await ref.read(investmentsProvider.notifier).refreshAll();
    ref.read(priceRefreshingProvider.notifier).state = false;
  }

  Future<void> _manualRefresh() async {
    ref.read(priceRefreshingProvider.notifier).state = true;
    final err = await ref.read(investmentsProvider.notifier).refreshAll();
    ref.read(priceRefreshingProvider.notifier).state = false;
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err), backgroundColor: kLoss));
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Prices updated via Gemini')));
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
                          value: '${summary.pnl >= 0 ? '+' : ''}${formatCurrency(summary.pnl)}',
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
  const _SummaryCell({required this.label, required this.value, this.valueColor});

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
        MaterialPageRoute(builder: (_) => AssetDetailScreen(assetId: asset.id!)),
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
                          style: TextStyle(fontSize: 11, color: kTextSecondary)),
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
                          style:
                              const TextStyle(fontSize: 11, color: kTextSecondary)),
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
    builder: (_) => _AddInvestmentSheet(ref: ref),
  );
}

class _AddInvestmentSheet extends StatefulWidget {
  final WidgetRef ref;
  const _AddInvestmentSheet({required this.ref});

  @override
  State<_AddInvestmentSheet> createState() => _AddInvestmentSheetState();
}

class _AddInvestmentSheetState extends State<_AddInvestmentSheet> {
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _symbolCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _type = 'other';
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _symbolCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
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
        padding: const EdgeInsets.all(kPad),
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
              const Gap(4),
              const Text(
                'Gemini will auto-estimate the current value.',
                style: TextStyle(fontSize: 13, color: kTextSecondary),
              ),
              const Gap(16),
              TextFormField(
                controller: _nameCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                    labelText: 'Investment name',
                    hintText: 'e.g. HDFC Nifty 50 Index Fund, Physical Gold'),
              ),
              const Gap(10),
              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: kAssetTypes
                    .map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(kAssetTypeLabels[t] ?? t)))
                    .toList(),
                onChanged: (v) => setState(() => _type = v ?? 'other'),
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
                    labelText: 'Amount invested (₹)',
                    hintText: '50000',
                    prefixText: '₹  '),
              ),
              const Gap(10),
              TextFormField(
                controller: _symbolCtrl,
                decoration: const InputDecoration(
                    labelText: 'Symbol / Fund name (optional, helps Gemini)',
                    hintText: 'e.g. HDFCNIFTY, GOLDBEES'),
              ),
              const Gap(10),
              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(hintText: 'Notes (optional)'),
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
                      : const Text('Add & Fetch Price'),
                ),
              ),
              const Gap(8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter investment name')));
      return;
    }
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid amount')));
      return;
    }
    setState(() => _saving = true);
    final asset = InvestmentAsset(
      name: name,
      type: _type,
      symbol: _symbolCtrl.text.trim().isEmpty ? null : _symbolCtrl.text.trim(),
      amountInvested: amount,
      createdAt: DateTime.now(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );
    await widget.ref.read(investmentsProvider.notifier).add(asset);
    if (mounted) Navigator.pop(context);
    // Auto-fetch price after adding
    final assets = widget.ref.read(investmentsProvider).value ?? [];
    final added = assets.isNotEmpty ? assets.last : null;
    if (added != null) {
      widget.ref.read(priceRefreshingProvider.notifier).state = true;
      await widget.ref.read(investmentsProvider.notifier).refreshOne(added);
      widget.ref.read(priceRefreshingProvider.notifier).state = false;
    }
  }
}
