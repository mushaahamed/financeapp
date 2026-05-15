import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import '../../../core/constants.dart';
import '../../../core/formatters.dart';
import '../../../data/models/goal_model.dart';
import '../../../data/models/liability_model.dart';
import '../../../providers/providers.dart';

// ── Goal category metadata ────────────────────────────────────────────────────

class _GoalCatMeta {
  final IconData icon;
  final Color color;
  const _GoalCatMeta(this.icon, this.color);
}

const _goalCatMeta = <String, _GoalCatMeta>{
  'Emergency Fund':    _GoalCatMeta(Icons.security_rounded,            Color(0xFF10B981)),
  'Retirement':        _GoalCatMeta(Icons.beach_access_rounded,        Color(0xFF8B5CF6)),
  'Education':         _GoalCatMeta(Icons.school_rounded,              Color(0xFF3B82F6)),
  'House / Property':  _GoalCatMeta(Icons.home_rounded,                Color(0xFFF59E0B)),
  'Car / Vehicle':     _GoalCatMeta(Icons.directions_car_rounded,      Color(0xFFEF4444)),
  'Vacation':          _GoalCatMeta(Icons.flight_rounded,              Color(0xFF06B6D4)),
  'Wedding':           _GoalCatMeta(Icons.favorite_rounded,            Color(0xFFEC4899)),
  'Business':          _GoalCatMeta(Icons.business_center_rounded,     Color(0xFF6366F1)),
  'Medical':           _GoalCatMeta(Icons.medical_services_rounded,    Color(0xFFF97316)),
  'Other':             _GoalCatMeta(Icons.flag_rounded,                Color(0xFF64748B)),
};

// ── Liability type metadata ────────────────────────────────────────────────────

class _LiabMeta {
  final IconData icon;
  final Color color;
  const _LiabMeta(this.icon, this.color);
}

const _liabMeta = <String, _LiabMeta>{
  'Home Loan':        _LiabMeta(Icons.home_work_rounded,        Color(0xFF3B82F6)),
  'Car Loan':         _LiabMeta(Icons.directions_car_rounded,   Color(0xFFF59E0B)),
  'Personal Loan':    _LiabMeta(Icons.person_rounded,           Color(0xFF8B5CF6)),
  'Credit Card':      _LiabMeta(Icons.credit_card_rounded,      Color(0xFFEF4444)),
  'Education Loan':   _LiabMeta(Icons.school_rounded,           Color(0xFF10B981)),
  'Business Loan':    _LiabMeta(Icons.business_center_rounded,  Color(0xFF6366F1)),
  'Other':            _LiabMeta(Icons.money_off_rounded,        Color(0xFF64748B)),
};

_GoalCatMeta _goalMeta(String? cat) =>
    _goalCatMeta[cat] ?? const _GoalCatMeta(Icons.flag_rounded, Color(0xFF64748B));

_LiabMeta _liabMetaFor(String? type) =>
    _liabMeta[type] ?? const _LiabMeta(Icons.money_off_rounded, Color(0xFF64748B));

// ── Screen ────────────────────────────────────────────────────────────────────

class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});
  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

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
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text('Goals & Debts'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.flag_rounded), text: 'Goals'),
            Tab(icon: Icon(Icons.account_balance_rounded), text: 'Liabilities'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [_GoalsTab(), _LiabilitiesTab()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _tabs.index == 0
            ? _showGoalSheet(context, ref)
            : _showLiabilitySheet(context, ref),
        icon: const Icon(Icons.add),
        label: Text(_tabs.index == 0 ? 'Add Goal' : 'Add Liability'),
      ),
    );
  }
}

// ── Goals tab ─────────────────────────────────────────────────────────────────

class _GoalsTab extends ConsumerWidget {
  const _GoalsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsProvider);

    return goalsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (goals) {
        if (goals.isEmpty) {
          return _EmptyState(
            icon: Icons.flag_outlined,
            title: 'No goals yet',
            subtitle: 'Set a savings goal and track your progress',
          );
        }

        // Summary header
        final totalTarget = goals.fold<double>(0, (s, g) => s + g.targetAmount);
        final totalSaved = goals.fold<double>(0, (s, g) => s + g.savedAmount);
        final completed = goals.where((g) => g.isComplete).length;

        return ListView(
          padding: const EdgeInsets.fromLTRB(kPad, kPad, kPad, 120),
          children: [
            // Summary card
            Container(
              padding: const EdgeInsets.all(kPad),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(kRadiusLg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.flag_rounded, color: Colors.white70, size: 16),
                    const Gap(6),
                    const Text('GOALS OVERVIEW',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5)),
                    const Spacer(),
                    Text('$completed/${goals.length} completed',
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 12)),
                  ]),
                  const Gap(10),
                  Text(formatCurrency(totalSaved),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5)),
                  const Gap(2),
                  Text('of ${formatCurrency(totalTarget)} total target',
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 13)),
                  const Gap(12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: totalTarget > 0
                          ? (totalSaved / totalTarget).clamp(0.0, 1.0)
                          : 0,
                      minHeight: 6,
                      backgroundColor: Colors.white24,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ],
              ),
            ),

            const Gap(16),

            ...goals.map((g) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _GoalCard(
                    goal: g,
                    onTap: () => _showGoalSheet(context, ref, editing: g),
                    onAddMoney: () =>
                        _showAddMoneySheet(context, ref, goal: g),
                  ),
                )),
          ],
        );
      },
    );
  }
}

class _GoalCard extends StatelessWidget {
  final Goal goal;
  final VoidCallback onTap;
  final VoidCallback onAddMoney;

  const _GoalCard({
    required this.goal,
    required this.onTap,
    required this.onAddMoney,
  });

  @override
  Widget build(BuildContext context) {
    final meta = _goalMeta(goal.category);
    final days = goal.daysRemaining;

    Color progressColor;
    if (goal.isComplete) {
      progressColor = kGain;
    } else if (goal.isOverdue) {
      progressColor = kLoss;
    } else if (goal.progressPct >= 0.75) {
      progressColor = kGain;
    } else if (goal.progressPct >= 0.4) {
      progressColor = const Color(0xFFF59E0B);
    } else {
      progressColor = kPrimary;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(kPad),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(kRadiusLg),
          border: Border.all(
              color: goal.isComplete
                  ? kGain.withOpacity(0.3)
                  : kDivider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: meta.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(meta.icon, size: 20, color: meta.color),
              ),
              const Gap(12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(goal.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  Text(goal.category,
                      style: const TextStyle(
                          color: kTextSecondary, fontSize: 12)),
                ]),
              ),
              // Status badge
              if (goal.isComplete)
                _Badge(label: '✓ Done', color: kGain)
              else if (goal.isOverdue)
                _Badge(label: 'Overdue', color: kLoss)
              else if (days != null && days <= 30)
                _Badge(label: '$days days left', color: const Color(0xFFF97316)),
            ]),
            const Gap(12),
            Row(children: [
              Text(formatCurrency(goal.savedAmount),
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5)),
              const Text(' / ',
                  style: TextStyle(color: kTextSecondary, fontSize: 14)),
              Text(formatCurrency(goal.targetAmount),
                  style: const TextStyle(
                      color: kTextSecondary, fontSize: 14)),
              const Spacer(),
              Text('${(goal.progressPct * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: progressColor)),
            ]),
            const Gap(8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: goal.progressPct,
                minHeight: 7,
                backgroundColor: kDivider,
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
            ),
            if (!goal.isComplete) ...[
              const Gap(10),
              Row(children: [
                Expanded(
                  child: Text(
                    '${formatCurrency(goal.remaining)} remaining',
                    style: const TextStyle(
                        color: kTextSecondary, fontSize: 12),
                  ),
                ),
                GestureDetector(
                  onTap: onAddMoney,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: kPrimaryLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, size: 14, color: kPrimary),
                        Gap(4),
                        Text('Add Money',
                            style: TextStyle(
                                color: kPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Liabilities tab ───────────────────────────────────────────────────────────

class _LiabilitiesTab extends ConsumerWidget {
  const _LiabilitiesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liabAsync = ref.watch(liabilitiesProvider);

    return liabAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (liabs) {
        if (liabs.isEmpty) {
          return _EmptyState(
            icon: Icons.account_balance_outlined,
            title: 'No liabilities',
            subtitle: 'Track your loans, EMIs, and credit card dues',
          );
        }

        final totalDebt =
            liabs.fold<double>(0, (s, l) => s + l.outstandingBalance);
        final totalEmi =
            liabs.fold<double>(0, (s, l) => s + (l.emiAmount ?? 0));

        return ListView(
          padding: const EdgeInsets.fromLTRB(kPad, kPad, kPad, 120),
          children: [
            // Summary card
            Container(
              padding: const EdgeInsets.all(kPad),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFDC2626), Color(0xFF991B1B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(kRadiusLg),
              ),
              child: Row(children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('TOTAL OUTSTANDING',
                        style: TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5)),
                    const Gap(4),
                    Text(formatCurrency(totalDebt),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5)),
                  ],
                )),
                if (totalEmi > 0)
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    const Text('Monthly EMI',
                        style: TextStyle(
                            color: Colors.white60, fontSize: 11)),
                    const Gap(4),
                    Text(formatCurrency(totalEmi),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                  ]),
              ]),
            ),

            const Gap(16),

            ...liabs.map((l) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _LiabilityCard(
                    liability: l,
                    onTap: () => _showLiabilitySheet(context, ref, editing: l),
                    onPayment: () => _showPaymentSheet(context, ref, liability: l),
                  ),
                )),
          ],
        );
      },
    );
  }
}

class _LiabilityCard extends StatelessWidget {
  final Liability liability;
  final VoidCallback onTap;
  final VoidCallback onPayment;

  const _LiabilityCard({
    required this.liability,
    required this.onTap,
    required this.onPayment,
  });

  @override
  Widget build(BuildContext context) {
    final meta = _liabMetaFor(liability.type);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(kPad),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(kRadiusLg),
          border: Border.all(color: kDivider),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: meta.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(meta.icon, size: 20, color: meta.color),
            ),
            const Gap(12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(liability.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
                Text(liability.type,
                    style: const TextStyle(
                        color: kTextSecondary, fontSize: 12)),
              ]),
            ),
            if (liability.interestRate != null)
              _Badge(
                  label: '${liability.interestRate!.toStringAsFixed(1)}% p.a.',
                  color: kTextSecondary),
          ]),
          const Gap(12),
          Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Outstanding',
                  style: TextStyle(fontSize: 11, color: kTextSecondary)),
              const Gap(2),
              Text(formatCurrency(liability.outstandingBalance),
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: kLoss,
                      letterSpacing: -0.5)),
            ]),
            const Spacer(),
            if (liability.emiAmount != null)
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                const Text('Monthly EMI',
                    style: TextStyle(fontSize: 11, color: kTextSecondary)),
                const Gap(2),
                Text(formatCurrency(liability.emiAmount!),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ]),
          ]),
          // Repayment progress
          if (liability.principal > 0) ...[
            const Gap(10),
            Row(children: [
              Text(
                  '${(liability.repaidPct * 100).toStringAsFixed(1)}% repaid',
                  style: const TextStyle(
                      fontSize: 12, color: kTextSecondary)),
              const Spacer(),
              GestureDetector(
                onTap: onPayment,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: kGain.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.payment_rounded, size: 14, color: kGain),
                    Gap(4),
                    Text('Log Payment',
                        style: TextStyle(
                            color: kGain,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ]),
            const Gap(6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: liability.repaidPct,
                minHeight: 6,
                backgroundColor: kDivider,
                valueColor: const AlwaysStoppedAnimation<Color>(kGain),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyState(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 56, color: kTextSecondary.withOpacity(0.4)),
          const Gap(16),
          Text(title,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: kTextPrimary)),
          const Gap(6),
          Text(subtitle,
              style: const TextStyle(color: kTextSecondary, fontSize: 13),
              textAlign: TextAlign.center),
        ]),
      );
}

// ── Goal add/edit sheet ───────────────────────────────────────────────────────

Future<void> _showGoalSheet(BuildContext context, WidgetRef ref,
    {Goal? editing}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _GoalSheet(ref: ref, editing: editing),
  );
}

class _GoalSheet extends StatefulWidget {
  final WidgetRef ref;
  final Goal? editing;
  const _GoalSheet({required this.ref, this.editing});
  @override
  State<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<_GoalSheet> {
  final _titleCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  final _savedCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _category = 'Other';
  DateTime? _deadline;
  bool _saving = false;

  bool get _isEdit => widget.editing != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final g = widget.editing!;
      _titleCtrl.text = g.title;
      _targetCtrl.text = _fmt(g.targetAmount);
      _savedCtrl.text = _fmt(g.savedAmount);
      _notesCtrl.text = g.notes ?? '';
      _category = g.category;
      _deadline = g.deadline;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _targetCtrl.dispose();
    _savedCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  String _fmt(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final target = double.tryParse(_targetCtrl.text.trim());
    final saved = double.tryParse(_savedCtrl.text.trim()) ?? 0;
    if (title.isEmpty || target == null || target <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid title and target amount')));
      return;
    }
    setState(() => _saving = true);
    final goal = Goal(
      id: widget.editing?.id,
      title: title,
      targetAmount: target,
      savedAmount: saved,
      category: _category,
      deadline: _deadline,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      createdAt: widget.editing?.createdAt ?? DateTime.now(),
    );
    if (_isEdit) {
      await widget.ref.read(goalsProvider.notifier).update(goal);
    } else {
      await widget.ref.read(goalsProvider.notifier).add(goal);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete goal?'),
        content: Text('"${widget.editing!.title}"'),
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
    await widget.ref.read(goalsProvider.notifier).delete(widget.editing!.id!);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime(now.year + 1, now.month),
      firstDate: now,
      lastDate: DateTime(now.year + 30),
      helpText: 'Goal deadline (optional)',
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  @override
  Widget build(BuildContext context) {
    final meta = _goalMeta(_category);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(kPad, 16, kPad, 24),
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: kDivider, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const Gap(16),
            Text(_isEdit ? 'Edit Goal' : 'New Goal',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const Gap(16),

            // Title
            TextFormField(
              controller: _titleCtrl,
              autofocus: !_isEdit,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  labelText: 'Goal name',
                  hintText: 'e.g. Emergency Fund'),
            ),
            const Gap(12),

            // Target + Saved row
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _targetCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                  ],
                  decoration: const InputDecoration(
                      labelText: 'Target (₹)', prefixText: '₹  '),
                ),
              ),
              const Gap(12),
              Expanded(
                child: TextFormField(
                  controller: _savedCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                  ],
                  decoration: const InputDecoration(
                      labelText: 'Already saved (₹)', prefixText: '₹  '),
                ),
              ),
            ]),
            const Gap(12),

            // Category
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
              children: kGoalCategories.map((cat) {
                final m = _goalMeta(cat);
                final sel = _category == cat;
                return GestureDetector(
                  onTap: () => setState(() => _category = cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: sel ? m.color.withOpacity(0.15) : kBackground,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: sel ? m.color : kDivider,
                          width: sel ? 1.5 : 1),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(m.icon, size: 13, color: sel ? m.color : kTextSecondary),
                      const Gap(5),
                      Text(cat,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                              color: sel ? m.color : kTextSecondary)),
                    ]),
                  ),
                );
              }).toList(),
            ),
            const Gap(12),

            // Deadline
            GestureDetector(
              onTap: _pickDeadline,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: kBackground,
                  borderRadius: BorderRadius.circular(kRadius),
                  border: Border.all(color: kDivider),
                ),
                child: Row(children: [
                  const Icon(Icons.calendar_today_rounded,
                      size: 16, color: kTextSecondary),
                  const Gap(10),
                  Expanded(
                    child: Text(
                      _deadline == null
                          ? 'Set deadline (optional)'
                          : 'Deadline: ${DateFormat('d MMM yyyy').format(_deadline!)}',
                      style: TextStyle(
                          fontSize: 14,
                          color: _deadline == null
                              ? kTextSecondary
                              : kTextPrimary),
                    ),
                  ),
                  if (_deadline != null)
                    GestureDetector(
                      onTap: () => setState(() => _deadline = null),
                      child: const Icon(Icons.close, size: 16, color: kTextSecondary),
                    ),
                ]),
              ),
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
            if (_isEdit)
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
                        backgroundColor: meta.color,
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: _saving
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('Save Changes'),
                  ),
                ),
              ])
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                      backgroundColor: meta.color,
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: _saving
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Create Goal'),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

// ── Add money to goal sheet ───────────────────────────────────────────────────

Future<void> _showAddMoneySheet(BuildContext ctx, WidgetRef ref,
    {required Goal goal}) async {
  await showModalBottomSheet(
    context: ctx,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddMoneySheet(ref: ref, goal: goal),
  );
}

class _AddMoneySheet extends StatefulWidget {
  final WidgetRef ref;
  final Goal goal;
  const _AddMoneySheet({required this.ref, required this.goal});
  @override
  State<_AddMoneySheet> createState() => _AddMoneySheetState();
}

class _AddMoneySheetState extends State<_AddMoneySheet> {
  final _ctrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    final amount = double.tryParse(_ctrl.text.trim());
    if (amount == null || amount <= 0) return;
    setState(() => _saving = true);
    await widget.ref.read(goalsProvider.notifier).addToSaved(widget.goal.id!, amount);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final meta = _goalMeta(widget.goal.category);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(kPad, 16, kPad, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: kDivider, borderRadius: BorderRadius.circular(2)))),
          const Gap(16),
          Text('Add to "${widget.goal.title}"',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const Gap(4),
          Text('${formatCurrency(widget.goal.remaining)} remaining',
              style: const TextStyle(color: kTextSecondary, fontSize: 13)),
          const Gap(16),
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
            decoration: const InputDecoration(prefixText: '₹  ', hintText: '0'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const Gap(20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                  backgroundColor: meta.color,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('Add Money'),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Liability add/edit sheet ──────────────────────────────────────────────────

Future<void> _showLiabilitySheet(BuildContext context, WidgetRef ref,
    {Liability? editing}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _LiabilitySheet(ref: ref, editing: editing),
  );
}

class _LiabilitySheet extends StatefulWidget {
  final WidgetRef ref;
  final Liability? editing;
  const _LiabilitySheet({required this.ref, this.editing});
  @override
  State<_LiabilitySheet> createState() => _LiabilitySheetState();
}

class _LiabilitySheetState extends State<_LiabilitySheet> {
  final _nameCtrl = TextEditingController();
  final _principalCtrl = TextEditingController();
  final _outstandingCtrl = TextEditingController();
  final _emiCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _type = 'Personal Loan';
  bool _saving = false;

  bool get _isEdit => widget.editing != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final l = widget.editing!;
      _nameCtrl.text = l.name;
      _principalCtrl.text = _fmt(l.principal);
      _outstandingCtrl.text = _fmt(l.outstandingBalance);
      _emiCtrl.text = l.emiAmount != null ? _fmt(l.emiAmount!) : '';
      _rateCtrl.text = l.interestRate != null ? l.interestRate!.toStringAsFixed(2) : '';
      _notesCtrl.text = l.notes ?? '';
      _type = l.type;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _principalCtrl.dispose();
    _outstandingCtrl.dispose(); _emiCtrl.dispose();
    _rateCtrl.dispose(); _notesCtrl.dispose();
    super.dispose();
  }

  String _fmt(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final principal = double.tryParse(_principalCtrl.text.trim()) ?? 0;
    final outstanding = double.tryParse(_outstandingCtrl.text.trim());
    if (name.isEmpty || outstanding == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter name and outstanding balance')));
      return;
    }
    setState(() => _saving = true);
    final liability = Liability(
      id: widget.editing?.id,
      name: name,
      type: _type,
      principal: principal,
      outstandingBalance: outstanding,
      emiAmount: double.tryParse(_emiCtrl.text.trim()),
      interestRate: double.tryParse(_rateCtrl.text.trim()),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );
    if (_isEdit) {
      await widget.ref.read(liabilitiesProvider.notifier).update(liability);
    } else {
      await widget.ref.read(liabilitiesProvider.notifier).add(liability);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete liability?'),
        content: Text('"${widget.editing!.name}"'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: kLoss), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await widget.ref.read(liabilitiesProvider.notifier).delete(widget.editing!.id!);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final meta = _liabMetaFor(_type);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(kPad, 16, kPad, 24),
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: kDivider, borderRadius: BorderRadius.circular(2)))),
            const Gap(16),
            Text(_isEdit ? 'Edit Liability' : 'Add Liability',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const Gap(16),

            // Type chips
            const Text('TYPE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                color: kTextSecondary, letterSpacing: 0.5)),
            const Gap(8),
            Wrap(spacing: 8, runSpacing: 8,
              children: kLiabilityTypes.map((t) {
                final m = _liabMetaFor(t);
                final sel = _type == t;
                return GestureDetector(
                  onTap: () => setState(() => _type = t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: sel ? m.color.withOpacity(0.15) : kBackground,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: sel ? m.color : kDivider, width: sel ? 1.5 : 1),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(m.icon, size: 13, color: sel ? m.color : kTextSecondary),
                      const Gap(5),
                      Text(t, style: TextStyle(fontSize: 12,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                          color: sel ? m.color : kTextSecondary)),
                    ]),
                  ),
                );
              }).toList(),
            ),
            const Gap(12),

            TextFormField(controller: _nameCtrl, autofocus: !_isEdit,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Loan / Liability name')),
            const Gap(12),

            Row(children: [
              Expanded(child: TextFormField(
                controller: _principalCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                decoration: const InputDecoration(labelText: 'Principal (₹)', prefixText: '₹  '),
              )),
              const Gap(12),
              Expanded(child: TextFormField(
                controller: _outstandingCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                decoration: const InputDecoration(labelText: 'Outstanding (₹)', prefixText: '₹  '),
              )),
            ]),
            const Gap(12),

            Row(children: [
              Expanded(child: TextFormField(
                controller: _emiCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                decoration: const InputDecoration(labelText: 'Monthly EMI (₹)', prefixText: '₹  '),
              )),
              const Gap(12),
              Expanded(child: TextFormField(
                controller: _rateCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                decoration: const InputDecoration(labelText: 'Interest Rate (%)', suffixText: '%'),
              )),
            ]),
            const Gap(12),

            TextFormField(controller: _notesCtrl, maxLines: 2,
                decoration: const InputDecoration(hintText: 'Notes (optional)',
                    prefixIcon: Icon(Icons.notes_rounded, size: 18))),
            const Gap(20),

            if (_isEdit)
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: _saving ? null : _delete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text('Delete'),
                  style: OutlinedButton.styleFrom(foregroundColor: kLoss,
                      side: const BorderSide(color: kLoss),
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                )),
                const Gap(12),
                Expanded(flex: 2, child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(backgroundColor: meta.color,
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('Save Changes'),
                )),
              ])
            else
              SizedBox(width: double.infinity, child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(backgroundColor: meta.color,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Add Liability'),
              )),
          ]),
        ),
      ),
    );
  }
}

// ── Log payment sheet ─────────────────────────────────────────────────────────

Future<void> _showPaymentSheet(BuildContext ctx, WidgetRef ref,
    {required Liability liability}) async {
  await showModalBottomSheet(
    context: ctx,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PaymentSheet(ref: ref, liability: liability),
  );
}

class _PaymentSheet extends StatefulWidget {
  final WidgetRef ref;
  final Liability liability;
  const _PaymentSheet({required this.ref, required this.liability});
  @override
  State<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<_PaymentSheet> {
  late final TextEditingController _ctrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: widget.liability.emiAmount != null
            ? widget.liability.emiAmount!.toInt().toString()
            : '');
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    final amount = double.tryParse(_ctrl.text.trim());
    if (amount == null || amount <= 0) return;
    setState(() => _saving = true);
    await widget.ref.read(liabilitiesProvider.notifier).makePayment(widget.liability.id!, amount);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(color: kCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.fromLTRB(kPad, 16, kPad, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: kDivider, borderRadius: BorderRadius.circular(2)))),
          const Gap(16),
          Text('Log Payment — ${widget.liability.name}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const Gap(4),
          Text('Outstanding: ${formatCurrency(widget.liability.outstandingBalance)}',
              style: const TextStyle(color: kTextSecondary, fontSize: 13)),
          const Gap(16),
          TextField(
            controller: _ctrl, autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
            decoration: const InputDecoration(prefixText: '₹  ', hintText: '0'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const Gap(20),
          SizedBox(width: double.infinity, child: FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
                backgroundColor: kGain,
                padding: const EdgeInsets.symmetric(vertical: 14)),
            child: const Text('Log Payment'),
          )),
        ]),
      ),
    );
  }
}
