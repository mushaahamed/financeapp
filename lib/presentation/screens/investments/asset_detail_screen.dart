import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../../core/constants.dart';
import '../../../core/formatters.dart';
import '../../../data/models/investment_asset_model.dart';
import '../../../providers/providers.dart';
import '../../widgets/amount_badge.dart';

class AssetDetailScreen extends ConsumerWidget {
  final int assetId;
  const AssetDetailScreen({super.key, required this.assetId});

  static final _dummy = InvestmentAsset(
      name: '', amountInvested: 0, createdAt: DateTime.now());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assetsAsync = ref.watch(investmentsProvider);
    final isRefreshing = ref.watch(priceRefreshingProvider);

    final asset = assetsAsync.value
        ?.firstWhere((a) => a.id == assetId, orElse: () => _dummy);

    if (asset == null || asset.name.isEmpty) {
      return Scaffold(
          appBar: AppBar(),
          body: const Center(child: CircularProgressIndicator()));
    }

    final pct = asset.returnPct;

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
                      child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh price',
              onPressed: () => _refresh(context, ref, asset),
            ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'edit') _showEditSheet(context, ref, asset);
              if (v == 'delete') _confirmDelete(context, ref, asset);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete', style: TextStyle(color: kLoss))),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(kPad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(kPad),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: pct != null && pct >= 0
                      ? [const Color(0xFF059669), const Color(0xFF047857)]
                      : pct != null
                          ? [const Color(0xFFDC2626), const Color(0xFFB91C1C)]
                          : [kPrimary, const Color(0xFF1D4ED8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(kRadiusLg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    asset.currentValue != null ? 'Current Value' : 'Invested Amount',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const Gap(4),
                  Text(
                    formatCurrency(asset.currentValue ?? asset.amountInvested),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5),
                  ),
                  if (asset.pnl != null) ...[
                    const Gap(8),
                    Row(children: [
                      Text(
                        '${asset.pnl! >= 0 ? '+' : ''}${formatCurrency(asset.pnl!)}',
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      const Gap(8),
                      if (pct != null) PnlBadge(percent: pct),
                    ]),
                  ],
                  if (asset.lastUpdatedAt != null) ...[
                    const Gap(8),
                    Text('Updated ${relativeDate(asset.lastUpdatedAt!)}',
                        style: const TextStyle(color: Colors.white60, fontSize: 11)),
                  ],
                ],
              ),
            ),
            const Gap(20),
            _infoCard([
              _infoRow('Invested', formatCurrency(asset.amountInvested)),
              _infoRow('Type', kAssetTypeLabels[asset.type] ?? asset.type),
              if (asset.symbol != null) _infoRow('Symbol', asset.symbol!),
              _infoRow('Added on', formatDate(asset.createdAt)),
              if (asset.notes != null) _infoRow('Notes', asset.notes!),
            ]),
            const Gap(20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showAddMoreSheet(context, ref, asset),
                icon: const Icon(Icons.add),
                label: const Text('Add more to this investment'),
              ),
            ),
            const Gap(12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isRefreshing ? null : () => _refresh(context, ref, asset),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Refresh price via Gemini'),
                style: FilledButton.styleFrom(backgroundColor: kGain),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(List<Widget> rows) => Container(
        padding: const EdgeInsets.all(kPad),
        decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(kRadiusLg),
            border: Border.all(color: kDivider)),
        child: Column(
          children: rows
              .expand((w) => [w, const Divider(height: 16)])
              .toList()
            ..removeLast(),
        ),
      );

  Widget _infoRow(String label, String value) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: kTextSecondary, fontSize: 13)),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          ),
        ],
      );

  Future<void> _refresh(BuildContext ctx, WidgetRef ref, InvestmentAsset asset) async {
    ref.read(priceRefreshingProvider.notifier).state = true;
    final err = await ref.read(investmentsProvider.notifier).refreshOne(asset);
    ref.read(priceRefreshingProvider.notifier).state = false;
    if (!ctx.mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text(err ?? 'Price updated'),
        backgroundColor: err != null ? kLoss : null));
  }

  void _showEditSheet(BuildContext ctx, WidgetRef ref, InvestmentAsset asset) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditSheet(asset: asset, ref: ref),
    );
  }

  void _showAddMoreSheet(BuildContext ctx, WidgetRef ref, InvestmentAsset asset) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddMoreSheet(asset: asset, ref: ref),
    );
  }

  Future<void> _confirmDelete(BuildContext ctx, WidgetRef ref, InvestmentAsset asset) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Delete Investment?'),
        content: Text(
            'Deletes ${asset.name} and refunds ₹${asset.amountInvested.toStringAsFixed(0)} to cash.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: kLoss),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(investmentsProvider.notifier).delete(asset.id!, asset.amountInvested);
      if (ctx.mounted) Navigator.pop(ctx);
    }
  }
}

class _EditSheet extends StatefulWidget {
  final InvestmentAsset asset;
  final WidgetRef ref;
  const _EditSheet({required this.asset, required this.ref});
  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
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
  void dispose() { _nameCtrl.dispose(); _symbolCtrl.dispose(); _notesCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
            color: kCard, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        padding: const EdgeInsets.all(kPad),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Edit Investment',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const Gap(16),
          TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
          const Gap(10),
          DropdownButtonFormField<String>(
            value: _type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: kAssetTypes.map((t) => DropdownMenuItem(value: t, child: Text(kAssetTypeLabels[t] ?? t))).toList(),
            onChanged: (v) => setState(() => _type = v ?? 'other'),
          ),
          const Gap(10),
          TextFormField(controller: _symbolCtrl, decoration: const InputDecoration(labelText: 'Symbol (optional)')),
          const Gap(10),
          TextFormField(controller: _notesCtrl, decoration: const InputDecoration(hintText: 'Notes')),
          const Gap(16),
          SizedBox(width: double.infinity, child: FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Save'),
          )),
          const Gap(8),
        ]),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.ref.read(investmentsProvider.notifier).update(widget.asset.copyWith(
      name: _nameCtrl.text.trim(),
      type: _type,
      symbol: _symbolCtrl.text.trim().isEmpty ? null : _symbolCtrl.text.trim(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    ));
    if (mounted) Navigator.pop(context);
  }
}

class _AddMoreSheet extends StatefulWidget {
  final InvestmentAsset asset;
  final WidgetRef ref;
  const _AddMoreSheet({required this.asset, required this.ref});
  @override
  State<_AddMoreSheet> createState() => _AddMoreSheetState();
}

class _AddMoreSheetState extends State<_AddMoreSheet> {
  final _amountCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() { _amountCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
            color: kCard, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        padding: const EdgeInsets.all(kPad),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Add more to ${widget.asset.name}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const Gap(4),
          const Text('Will be deducted from your cash.',
              style: TextStyle(fontSize: 13, color: kTextSecondary)),
          const Gap(16),
          TextFormField(
            controller: _amountCtrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
            decoration: const InputDecoration(labelText: 'Amount (₹)', prefixText: '₹  ', hintText: '10000'),
          ),
          const Gap(16),
          SizedBox(width: double.infinity, child: FilledButton(
            onPressed: _saving ? null : _save,
            child: const Text('Add Investment'),
          )),
          const Gap(8),
        ]),
      ),
    );
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) return;
    setState(() => _saving = true);
    await widget.ref.read(investmentsProvider.notifier).addMore(widget.asset.id!, amount);
    if (mounted) Navigator.pop(context);
  }
}
