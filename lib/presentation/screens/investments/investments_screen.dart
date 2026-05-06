import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../../core/constants.dart';
import '../../../core/formatters.dart';
import '../../../data/models/investment_asset_model.dart';
import '../../../providers/providers.dart';
import '../../../presentation/widgets/amount_badge.dart';
import '../../../presentation/widgets/section_header.dart';
import 'asset_detail_screen.dart';

class InvestmentsScreen extends ConsumerWidget {
  const InvestmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assetsAsync = ref.watch(investmentAssetsProvider);
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
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh all prices',
              onPressed: () => _refreshAll(context, ref),
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
                      size: 56, color: kTextSecondary),
                  const Gap(16),
                  const Text(
                    'No investments yet.',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: kTextPrimary),
                  ),
                  const Gap(8),
                  const Text(
                    'Track your portfolio here.',
                    style:
                        TextStyle(color: kTextSecondary, fontSize: 14),
                  ),
                  const Gap(24),
                  FilledButton.icon(
                    onPressed: () => _showAddAssetSheet(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Asset'),
                  ),
                ],
              ),
            );
          }

          final symbol = kDefaultCurrencySymbol;
          return ListView(
            padding:
                const EdgeInsets.fromLTRB(kPad, 0, kPad, 100),
            children: [
              // ── Last updated ──
              if (settings?.lastPortfolioUpdate != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Text(
                    'Last updated: ${formatDateTime(settings!.lastPortfolioUpdate!)}',
                    style: const TextStyle(
                        color: kTextSecondary, fontSize: 12),
                  ),
                )
              else
                const Gap(8),

              // ── Portfolio summary ──
              Container(
                padding: const EdgeInsets.all(kPad),
                decoration: BoxDecoration(
                  color: kPrimaryLight,
                  borderRadius: BorderRadius.circular(kRadiusLg),
                  border: Border.all(color: kDivider),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryCell(
                            label: 'Portfolio Value',
                            value: formatCurrency(
                                summary.portfolioValue,
                                symbol: symbol),
                          ),
                        ),
                        Expanded(
                          child: _SummaryCell(
                            label: 'Invested',
                            value: formatCurrency(
                                summary.totalInvested,
                                symbol: symbol),
                          ),
                        ),
                      ],
                    ),
                    const Gap(12),
                    const Divider(height: 1),
                    const Gap(12),
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryCell(
                            label: 'Unrealised P&L',
                            value: formatCurrency(summary.pnl,
                                symbol: symbol),
                            valueColor: summary.pnl >= 0
                                ? kGain
                                : kLoss,
                          ),
                        ),
                        Expanded(
                          child: _SummaryCell(
                            label: 'Return',
                            value:
                                '${summary.returnPercent >= 0 ? '+' : ''}${summary.returnPercent.toStringAsFixed(2)}%',
                            valueColor: summary.returnPercent >= 0
                                ? kGain
                                : kLoss,
                          ),
                        ),
                      ],
                    ),
                    if (summary.hasMissingPrices) ...[
                      const Gap(10),
                      const Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 13, color: kTextSecondary),
                          Gap(4),
                          Text(
                            'Some assets have no price data yet.',
                            style: TextStyle(
                                fontSize: 11, color: kTextSecondary),
                          ),
                        ],
                      )
                    ]
                  ],
                ),
              ),
              const Gap(20),
              const SectionHeader(title: 'ASSETS'),
              const Gap(10),
              ...assets.map((a) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _AssetTile(a),
                  )),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddAssetSheet(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _refreshAll(BuildContext ctx, WidgetRef ref) async {
    ref.read(priceRefreshingProvider.notifier).state = true;
    final error =
        await ref.read(investmentAssetsProvider.notifier).refreshAllPrices();
    ref.read(priceRefreshingProvider.notifier).state = false;
    if (!ctx.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: kLoss),
      );
    } else {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('Prices updated')),
      );
    }
  }
}

class _SummaryCell extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _SummaryCell(
      {required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
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
              letterSpacing: -0.3,
            )),
      ],
    );
  }
}

class _AssetTile extends ConsumerWidget {
  final InvestmentAsset asset;
  const _AssetTile(this.asset);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final symbol = kDefaultCurrencySymbol;
    final pct = asset.returnPercent;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => AssetDetailScreen(assetId: asset.id!)),
      ),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: kPad, vertical: 14),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(kRadius),
          border: Border.all(color: kDivider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    asset.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
                if (pct != null) PnlBadge(percent: pct),
              ],
            ),
            const Gap(4),
            Wrap(
              children: [
                _Chip(kAssetTypeLabels[asset.type] ?? asset.type),
                if (asset.symbol != null && asset.symbol!.isNotEmpty)
                  _Chip(asset.symbol!),
              ],
            ),
            const Gap(8),
            Row(
              children: [
                Expanded(
                  child: _StatPair(
                    label: 'Invested',
                    value: formatCurrency(asset.totalInvested,
                        symbol: symbol),
                  ),
                ),
                if (asset.lastKnownPricePerUnit != null)
                  Expanded(
                    child: _StatPair(
                      label: 'Current',
                      value: formatCurrency(
                          asset.unitsHeld * asset.lastKnownPricePerUnit!,
                          symbol: symbol),
                      valueColor: asset.unrealizedPnl != null &&
                              asset.unrealizedPnl! >= 0
                          ? kGain
                          : kLoss,
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
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: kBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kDivider),
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: 11,
              color: kTextSecondary,
              fontWeight: FontWeight.w500)),
    );
  }
}

class _StatPair extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _StatPair(
      {required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: kTextSecondary)),
        Text(value,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: valueColor ?? kTextPrimary)),
      ],
    );
  }
}

// ── Add Asset Sheet ───────────────────────────────────────────────────────────

void _showAddAssetSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddAssetSheet(ref: ref),
  );
}

class _AddAssetSheet extends StatefulWidget {
  final WidgetRef ref;
  const _AddAssetSheet({required this.ref});

  @override
  State<_AddAssetSheet> createState() => _AddAssetSheetState();
}

class _AddAssetSheetState extends State<_AddAssetSheet> {
  final _nameCtrl = TextEditingController();
  final _symbolCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _type = kAssetTypes.first;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _symbolCtrl.dispose();
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
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Gap(16),
              const Text('Add Asset',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const Gap(16),
              TextFormField(
                controller: _nameCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'e.g. Gold ETF, Reliance Industries'),
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
                onChanged: (v) =>
                    setState(() => _type = v ?? kAssetTypes.first),
              ),
              const Gap(10),
              TextFormField(
                controller: _symbolCtrl,
                decoration: const InputDecoration(
                  labelText: 'Symbol / Identifier (optional)',
                  hintText: 'e.g. GOLDBEES, NIFTYBEES',
                ),
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
                      : const Text('Add Asset'),
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
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an asset name')),
      );
      return;
    }
    setState(() => _saving = true);
    final asset = InvestmentAsset(
      name: name,
      type: _type,
      symbol: _symbolCtrl.text.trim().isEmpty
          ? null
          : _symbolCtrl.text.trim(),
      notes: _notesCtrl.text.trim().isEmpty
          ? null
          : _notesCtrl.text.trim(),
    );
    await widget.ref
        .read(investmentAssetsProvider.notifier)
        .addAsset(asset);
    if (mounted) Navigator.pop(context);
  }
}
