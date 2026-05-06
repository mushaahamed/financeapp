import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../../core/constants.dart';
import '../../../core/formatters.dart';
import '../../../data/models/investment_asset_model.dart';
import '../../../data/models/investment_transaction_model.dart';
import '../../../providers/providers.dart';
import '../../../presentation/widgets/amount_badge.dart';

class AssetDetailScreen extends ConsumerWidget {
  final int assetId;
  const AssetDetailScreen({super.key, required this.assetId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assetsAsync = ref.watch(investmentAssetsProvider);
    final txAsync = ref.watch(transactionsProvider(assetId));
    final isRefreshing = ref.watch(priceRefreshingProvider);

    final asset = assetsAsync.value
        ?.firstWhere((a) => a.id == assetId, orElse: () => _dummy);

    if (asset == null || asset.id == null) {
      return Scaffold(
          appBar: AppBar(),
          body: const Center(child: CircularProgressIndicator()));
    }

    final symbol = kDefaultCurrencySymbol;
    final currentValue = asset.currentValue;
    final pnl = asset.unrealizedPnl;
    final pct = asset.returnPercent;

    return Scaffold(
      appBar: AppBar(
        title: Text(asset.name),
        actions: [
          if (isRefreshing)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh price',
              onPressed: () => _refreshPrice(context, ref, asset),
            ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'edit') _showEditSheet(context, ref, asset);
              if (v == 'delete') _confirmDelete(context, ref);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit asset')),
              PopupMenuItem(
                value: 'delete',
                child:
                    Text('Delete asset', style: TextStyle(color: kLoss)),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(kPad, 0, kPad, 100),
        children: [
          // ── Asset stats ──
          const Gap(12),
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
                      child: _StatCell(
                        label: 'Units Held',
                        value: asset.unitsHeld.toStringAsFixed(4),
                      ),
                    ),
                    Expanded(
                      child: _StatCell(
                        label: 'Avg Buy Price',
                        value: formatCurrency(asset.avgBuyPricePerUnit,
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
                      child: _StatCell(
                        label: 'Total Invested',
                        value: formatCurrency(asset.totalInvested,
                            symbol: symbol),
                      ),
                    ),
                    Expanded(
                      child: _StatCell(
                        label: 'Current Value',
                        value: currentValue != null
                            ? formatCurrency(currentValue, symbol: symbol)
                            : '—',
                      ),
                    ),
                  ],
                ),
                if (pnl != null) ...[
                  const Gap(12),
                  const Divider(height: 1),
                  const Gap(12),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCell(
                          label: 'Unrealised P&L',
                          value: formatCurrency(pnl, symbol: symbol),
                          valueColor: pnl >= 0 ? kGain : kLoss,
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            if (pct != null) PnlBadge(percent: pct),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
                if (asset.lastPriceUpdateAt != null) ...[
                  const Gap(10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Price updated ${formatDateTime(asset.lastPriceUpdateAt!)}',
                      style: const TextStyle(
                          fontSize: 11, color: kTextSecondary),
                    ),
                  ),
                ],
              ],
            ),
          ),

          if (asset.symbol != null || asset.notes != null) ...[
            const Gap(12),
            Container(
              padding: const EdgeInsets.all(kPad),
              decoration: BoxDecoration(
                color: kCard,
                borderRadius: BorderRadius.circular(kRadius),
                border: Border.all(color: kDivider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (asset.symbol != null)
                    _InfoRow(
                        'Symbol / ID', asset.symbol!),
                  if (asset.notes != null) _InfoRow('Notes', asset.notes!),
                ],
              ),
            ),
          ],

          const Gap(20),

          // ── Transactions ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TRANSACTIONS',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kTextSecondary,
                    letterSpacing: 0.5),
              ),
              TextButton.icon(
                onPressed: () =>
                    _showAddTransactionSheet(context, ref, asset),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add'),
                style: TextButton.styleFrom(
                    foregroundColor: kPrimary,
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const Gap(8),
          txAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
            data: (txList) {
              if (txList.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'No transactions yet. Add one above.',
                      style: TextStyle(color: kTextSecondary),
                    ),
                  ),
                );
              }
              return Column(
                children: txList
                    .map((tx) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _TxTile(tx: tx, ref: ref),
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _refreshPrice(
      BuildContext ctx, WidgetRef ref, InvestmentAsset asset) async {
    ref.read(priceRefreshingProvider.notifier).state = true;
    final error = await ref
        .read(investmentAssetsProvider.notifier)
        .refreshPrice(asset);
    ref.read(priceRefreshingProvider.notifier).state = false;
    if (!ctx.mounted) return;
    ref.refresh(transactionsProvider(assetId));
    if (error != null) {
      ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
              content: Text('Could not fetch price for ${asset.name}: $error'),
              backgroundColor: kLoss));
    } else {
      ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('Price updated')));
    }
  }

  void _showEditSheet(
      BuildContext ctx, WidgetRef ref, InvestmentAsset asset) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditAssetSheet(asset: asset, ref: ref),
    );
  }

  void _confirmDelete(BuildContext ctx, WidgetRef ref) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Delete asset?'),
        content: const Text(
            'This will delete the asset and all its transactions. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(investmentAssetsProvider.notifier)
                  .deleteAsset(assetId);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: kLoss),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  static final _dummy = InvestmentAsset(name: '', type: 'other');
}

// ── Transaction tile ──────────────────────────────────────────────────────────

class _TxTile extends ConsumerWidget {
  final InvestmentTransaction tx;
  final WidgetRef ref;
  const _TxTile({required this.tx, required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBuy = tx.type == 'buy';
    final symbol = kDefaultCurrencySymbol;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: kPad, vertical: 12),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: kDivider),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isBuy
                  ? const Color(0xFFD1FAE5)
                  : const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isBuy ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              size: 18,
              color: isBuy ? kGain : kLoss,
            ),
          ),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isBuy ? 'Buy' : 'Sell',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isBuy ? kGain : kLoss,
                      fontSize: 14),
                ),
                Text(
                  '${tx.units} units @ ${formatCurrency(tx.pricePerUnit, symbol: symbol)}',
                  style:
                      const TextStyle(color: kTextSecondary, fontSize: 12),
                ),
                Text(
                  relativeDate(tx.timestamp),
                  style:
                      const TextStyle(color: kTextSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatCurrency(tx.totalValue, symbol: symbol),
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14),
              ),
              GestureDetector(
                onTap: () => _confirmDeleteTx(context, ref),
                child: const Text(
                  'Remove',
                  style:
                      TextStyle(color: kLoss, fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDeleteTx(BuildContext ctx, WidgetRef ref) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Remove transaction?'),
        content: const Text(
            'This will adjust units and cash accordingly.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(investmentAssetsProvider.notifier)
                  .deleteTransaction(tx);
              ref.refresh(transactionsProvider(tx.assetId));
            },
            style: TextButton.styleFrom(foregroundColor: kLoss),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

// ── Info row ─────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, color: kTextSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

// ── Stat cell ─────────────────────────────────────────────────────────────────

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _StatCell(
      {required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: kTextSecondary)),
        const Gap(2),
        Text(value,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: valueColor ?? kTextPrimary)),
      ],
    );
  }
}

// ── Add Transaction Sheet ─────────────────────────────────────────────────────

void _showAddTransactionSheet(
    BuildContext context, WidgetRef ref, InvestmentAsset asset) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddTransactionSheet(asset: asset, ref: ref),
  );
}

class _AddTransactionSheet extends StatefulWidget {
  final InvestmentAsset asset;
  final WidgetRef ref;
  const _AddTransactionSheet({required this.asset, required this.ref});

  @override
  State<_AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<_AddTransactionSheet> {
  final _unitsCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  String _type = 'buy';
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _unitsCtrl.dispose();
    _priceCtrl.dispose();
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
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const Gap(16),
            Text('Add Transaction — ${widget.asset.name}',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const Gap(16),
            Row(
              children: ['buy', 'sell'].map((t) {
                final selected = _type == t;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: t == 'buy' ? 8 : 0),
                    child: GestureDetector(
                      onTap: () => setState(() => _type = t),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: selected
                              ? (t == 'buy' ? kGain : kLoss)
                              : kBackground,
                          borderRadius: BorderRadius.circular(kRadius),
                          border: Border.all(
                            color: selected
                                ? (t == 'buy' ? kGain : kLoss)
                                : kDivider,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            t == 'buy' ? 'Buy' : 'Sell',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: selected ? Colors.white : kTextSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const Gap(12),
            TextFormField(
              controller: _unitsCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
              ],
              decoration:
                  const InputDecoration(labelText: 'Units', hintText: '0.0'),
            ),
            const Gap(10),
            TextFormField(
              controller: _priceCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
              ],
              decoration: const InputDecoration(
                  labelText: 'Price per unit', prefixText: '₹  ', hintText: '0.00'),
            ),
            const Gap(10),
            GestureDetector(
              onTap: () => _pickDate(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: kBackground,
                  borderRadius: BorderRadius.circular(kRadius),
                  border: Border.all(color: kDivider),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 16, color: kTextSecondary),
                    const Gap(10),
                    Text(
                      formatDate(_date),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
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
                    : const Text('Add Transaction'),
              ),
            ),
            const Gap(8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate(BuildContext ctx) async {
    final picked = await showDatePicker(
      context: ctx,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final units = double.tryParse(_unitsCtrl.text.trim());
    final price = double.tryParse(_priceCtrl.text.trim());
    if (units == null || units <= 0 || price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid units and price')),
      );
      return;
    }
    setState(() => _saving = true);
    final tx = InvestmentTransaction(
      assetId: widget.asset.id!,
      type: _type,
      units: units,
      pricePerUnit: price,
      timestamp: _date,
    );
    await widget.ref
        .read(investmentAssetsProvider.notifier)
        .addTransaction(tx);
    widget.ref.refresh(transactionsProvider(widget.asset.id!));
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _type == 'buy'
                ? '${formatCurrency(units * price)} deducted from cash'
                : '${formatCurrency(units * price)} added to cash',
          ),
        ),
      );
    }
  }
}

// ── Edit Asset Sheet ──────────────────────────────────────────────────────────

class _EditAssetSheet extends StatefulWidget {
  final InvestmentAsset asset;
  final WidgetRef ref;
  const _EditAssetSheet({required this.asset, required this.ref});

  @override
  State<_EditAssetSheet> createState() => _EditAssetSheetState();
}

class _EditAssetSheetState extends State<_EditAssetSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _symbolCtrl;
  late final TextEditingController _notesCtrl;
  late String _type;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.asset.name);
    _symbolCtrl = TextEditingController(text: widget.asset.symbol ?? '');
    _notesCtrl = TextEditingController(text: widget.asset.notes ?? '');
    _type = widget.asset.type;
  }

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
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const Gap(16),
            const Text('Edit Asset',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const Gap(16),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const Gap(10),
            DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: kAssetTypes
                  .map((t) => DropdownMenuItem(
                      value: t, child: Text(kAssetTypeLabels[t] ?? t)))
                  .toList(),
              onChanged: (v) => setState(() => _type = v ?? kAssetTypes.first),
            ),
            const Gap(10),
            TextFormField(
              controller: _symbolCtrl,
              decoration:
                  const InputDecoration(labelText: 'Symbol / Identifier'),
            ),
            const Gap(10),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(hintText: 'Notes'),
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
                    : const Text('Save Changes'),
              ),
            ),
            const Gap(8),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    final updated = widget.asset.copyWith(
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
        .updateAsset(updated);
    if (mounted) Navigator.pop(context);
  }
}
