import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/formatters.dart';
import '../../data/models/expense_model.dart';
import '../../providers/providers.dart';

// ── Category data (shared across screens) ─────────────────────────────────────

class ExpCat {
  final String label;
  final IconData icon;
  final Color color;
  const ExpCat(this.label, this.icon, this.color);
}

const kExpCats = [
  ExpCat('Food & Dining',  Icons.restaurant_rounded,     Color(0xFFEF4444)),
  ExpCat('Shopping',       Icons.shopping_bag_rounded,   Color(0xFFF97316)),
  ExpCat('Transport',      Icons.directions_bus_rounded, Color(0xFF3B82F6)),
  ExpCat('Health',         Icons.favorite_rounded,       Color(0xFFEC4899)),
  ExpCat('Entertainment',  Icons.movie_rounded,          Color(0xFF8B5CF6)),
  ExpCat('Bills',          Icons.receipt_long_rounded,   Color(0xFF06B6D4)),
  ExpCat('Friends',        Icons.people_rounded,         Color(0xFF10B981)),
  ExpCat('Education',      Icons.school_rounded,         Color(0xFF6366F1)),
  ExpCat('Groceries',      Icons.local_grocery_store_rounded, Color(0xFF84CC16)),
  ExpCat('Other',          Icons.payments_rounded,       Color(0xFF64748B)),
];

const kIncCats = [
  ExpCat('Salary',                 Icons.work_rounded,              Color(0xFF10B981)),
  ExpCat('Freelance / Consulting', Icons.laptop_rounded,            Color(0xFF0EA5E9)),
  ExpCat('Business',               Icons.storefront_rounded,        Color(0xFF6366F1)),
  ExpCat('Investment Returns',     Icons.trending_up_rounded,       Color(0xFF8B5CF6)),
  ExpCat('Rental Income',          Icons.home_work_rounded,         Color(0xFFF59E0B)),
  ExpCat('Gift / Bonus',           Icons.card_giftcard_rounded,     Color(0xFFEC4899)),
  ExpCat('Refund',                 Icons.replay_rounded,            Color(0xFF14B8A6)),
  ExpCat('Other Income',           Icons.payments_rounded,          Color(0xFF64748B)),
];

const kPaymentMethods = [
  'Cash',
  'UPI',
  'Debit Card',
  'Credit Card',
  'Net Banking',
  'EMI',
];

ExpCat expCatFor(String? label) =>
    kExpCats.firstWhere((c) => c.label == label, orElse: () => kExpCats.last);

ExpCat incCatFor(String? label) =>
    kIncCats.firstWhere((c) => c.label == label, orElse: () => kIncCats.last);

ExpCat catForExpense(Expense e) =>
    e.isIncome ? incCatFor(e.category) : expCatFor(e.category);

// ── Add / Edit transaction sheet ──────────────────────────────────────────────

class AddTransactionSheet extends StatefulWidget {
  final WidgetRef ref;
  final Expense? editing;
  final DateTime initialDate;

  const AddTransactionSheet({
    super.key,
    required this.ref,
    this.editing,
    required this.initialDate,
  });

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  final _amountCtrl = TextEditingController();
  final _titleCtrl  = TextEditingController();
  final _notesCtrl  = TextEditingController();
  String? _category;
  String? _paymentMethod;
  late DateTime _date;
  bool _saving = false;
  bool _isIncome = false;

  bool get _isEdit  => widget.editing != null;
  bool get _isToday => _isSameDay(_date, DateTime.now());

  @override
  void initState() {
    super.initState();
    _date = DateTime(
        widget.initialDate.year,
        widget.initialDate.month,
        widget.initialDate.day);
    if (_isEdit) {
      final e = widget.editing!;
      _amountCtrl.text = e.amount == e.amount.truncateToDouble()
          ? e.amount.toInt().toString()
          : e.amount.toStringAsFixed(2);
      _titleCtrl.text   = e.title;
      _notesCtrl.text   = e.notes ?? '';
      _category         = e.category;
      _paymentMethod    = e.paymentMethod;
      _isIncome         = e.isIncome;
      _date = DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day);
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _titleCtrl.dispose();
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
      helpText: 'Select date',
    );
    if (picked != null) setState(() => _date = picked);
  }

  List<ExpCat> get _activeCats => _isIncome ? kIncCats : kExpCats;

  Future<void> _save() async {
    final title  = _titleCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.trim());

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
      return;
    }
    if (title.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter a description')));
      return;
    }

    setState(() => _saving = true);

    final now = DateTime.now();
    final timestamp = _isEdit
        ? DateTime(_date.year, _date.month, _date.day,
            widget.editing!.timestamp.hour, widget.editing!.timestamp.minute)
        : DateTime(
            _date.year, _date.month, _date.day, now.hour, now.minute, now.second);

    final notesVal =
        _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim();

    if (_isEdit) {
      final updated = widget.editing!.copyWith(
        title: title,
        amount: amount,
        timestamp: timestamp,
        category: _category,
        notes: notesVal,
        isIncome: _isIncome,
        paymentMethod: _paymentMethod,
      );
      await widget.ref
          .read(expensesProvider.notifier)
          .update(updated, widget.editing!.amount, widget.editing!.isIncome);
    } else {
      await widget.ref.read(expensesProvider.notifier).add(Expense(
            title: title,
            amount: amount,
            timestamp: timestamp,
            category: _category,
            notes: notesVal,
            isIncome: _isIncome,
            paymentMethod: _paymentMethod,
          ));
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: Text(
            '"${widget.editing!.title}" — ${formatCurrency(widget.editing!.amount)}'),
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
    await widget.ref
        .read(expensesProvider.notifier)
        .delete(widget.editing!);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = _isIncome ? kGain : kLoss;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(kPad, 16, kPad, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: kDivider,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const Gap(16),

              // ── Income / Expense toggle ──────────────────────────────────
              if (!_isEdit)
                Container(
                  decoration: BoxDecoration(
                    color: kBackground,
                    borderRadius: BorderRadius.circular(kRadius),
                    border: Border.all(color: kDivider),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(children: [
                    Expanded(
                        child: _TypeToggle(
                      label: '💸  Expense',
                      selected: !_isIncome,
                      color: kLoss,
                      onTap: () => setState(() {
                        _isIncome = false;
                        _category = null;
                      }),
                    )),
                    Expanded(
                        child: _TypeToggle(
                      label: '💰  Income',
                      selected: _isIncome,
                      color: kGain,
                      onTap: () => setState(() {
                        _isIncome = true;
                        _category = null;
                      }),
                    )),
                  ]),
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: accentColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: accentColor.withAlpha(76)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                        _isIncome
                            ? Icons.arrow_downward_rounded
                            : Icons.arrow_upward_rounded,
                        size: 14,
                        color: accentColor),
                    const Gap(6),
                    Text(_isIncome ? 'Income' : 'Expense',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: accentColor)),
                  ]),
                ),

              const Gap(16),

              // ── Title row ────────────────────────────────────────────────
              Row(children: [
                Text(
                    _isEdit
                        ? 'Edit ${_isIncome ? "Income" : "Expense"}'
                        : (_isIncome ? 'Add Income' : 'Add Expense'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const Spacer(),
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isToday
                          ? kPrimaryLight
                          : const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: _isToday
                              ? kPrimary
                              : const Color(0xFFF97316)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
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
                                : const Color(0xFFF97316)),
                      ),
                    ]),
                  ),
                ),
              ]),
              if (!_isToday)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    DateFormat('EEEE, d MMMM yyyy').format(_date),
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFFF97316)),
                  ),
                ),
              const Gap(16),

              // ── Amount ───────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: kBackground,
                  borderRadius: BorderRadius.circular(kRadius),
                  border: Border.all(
                      color: _saving
                          ? kDivider
                          : accentColor.withAlpha(76)),
                ),
                child: Row(children: [
                  Text('₹',
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: accentColor.withAlpha(127))),
                  const Gap(8),
                  Expanded(
                    child: TextField(
                      controller: _amountCtrl,
                      autofocus: !_isEdit,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*'))
                      ],
                      style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        fillColor: Colors.transparent,
                        hintText: '0',
                        hintStyle: TextStyle(color: kDivider),
                      ),
                    ),
                  ),
                ]),
              ),
              const Gap(12),

              // ── Description ──────────────────────────────────────────────
              TextFormField(
                controller: _titleCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                    hintText: _isIncome
                        ? 'Source (e.g. Monthly Salary)'
                        : 'What was this for?',
                    prefixIcon:
                        const Icon(Icons.edit_outlined, size: 18)),
              ),
              const Gap(12),

              // ── Category ─────────────────────────────────────────────────
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
                children: _activeCats.map((cat) {
                  final sel = _category == cat.label;
                  return GestureDetector(
                    onTap: () => setState(
                        () => _category = sel ? null : cat.label),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: sel
                            ? cat.color.withAlpha(38)
                            : kBackground,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: sel ? cat.color : kDivider,
                            width: sel ? 1.5 : 1),
                      ),
                      child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(cat.icon,
                                size: 14,
                                color: sel
                                    ? cat.color
                                    : kTextSecondary),
                            const Gap(5),
                            Text(cat.label,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: sel
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: sel
                                        ? cat.color
                                        : kTextSecondary)),
                          ]),
                    ),
                  );
                }).toList(),
              ),
              const Gap(12),

              // ── Payment method ───────────────────────────────────────────
              if (!_isIncome) ...[
                const Text('PAYMENT METHOD',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: kTextSecondary,
                        letterSpacing: 0.5)),
                const Gap(8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: kPaymentMethods.map((m) {
                    final sel = _paymentMethod == m;
                    return GestureDetector(
                      onTap: () => setState(
                          () => _paymentMethod = sel ? null : m),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: sel
                              ? kPrimary.withAlpha(25)
                              : kBackground,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: sel ? kPrimary : kDivider,
                              width: sel ? 1.5 : 1),
                        ),
                        child: Text(m,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: sel
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: sel
                                    ? kPrimary
                                    : kTextSecondary)),
                      ),
                    );
                  }).toList(),
                ),
                const Gap(12),
              ],

              // ── Notes ────────────────────────────────────────────────────
              TextFormField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                    hintText: 'Notes (optional)',
                    prefixIcon:
                        Icon(Icons.notes_rounded, size: 18)),
              ),
              const Gap(20),

              // ── Action buttons ───────────────────────────────────────────
              if (_isEdit)
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : _delete,
                      icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 16),
                      label: const Text('Delete'),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: kLoss,
                          side: const BorderSide(color: kLoss),
                          padding: const EdgeInsets.symmetric(
                              vertical: 14)),
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                          backgroundColor: accentColor,
                          padding: const EdgeInsets.symmetric(
                              vertical: 14)),
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2))
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
                        backgroundColor: accentColor,
                        padding: const EdgeInsets.symmetric(
                            vertical: 14)),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text(_isIncome
                            ? (_isToday
                                ? 'Add Income'
                                : 'Add for ${DateFormat("d MMM").format(_date)}')
                            : (_isToday
                                ? 'Add Expense'
                                : 'Add for ${DateFormat("d MMM").format(_date)}')),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Toggle button ─────────────────────────────────────────────────────────────

class _TypeToggle extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _TypeToggle({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : kTextSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Helper ────────────────────────────────────────────────────────────────────

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
