class Liability {
  final int? id;
  final String name;
  final String type;
  final double principal;
  final double outstandingBalance;
  final double? emiAmount;
  final double? interestRate;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? notes;

  const Liability({
    this.id,
    required this.name,
    this.type = 'other',
    required this.principal,
    required this.outstandingBalance,
    this.emiAmount,
    this.interestRate,
    this.startDate,
    this.endDate,
    this.notes,
  });

  double get repaidAmount => (principal - outstandingBalance).clamp(0.0, principal);
  double get repaidPct =>
      principal > 0 ? (repaidAmount / principal).clamp(0.0, 1.0) : 0.0;

  Liability copyWith({
    String? name,
    String? type,
    double? principal,
    double? outstandingBalance,
    double? emiAmount,
    double? interestRate,
    DateTime? startDate,
    DateTime? endDate,
    String? notes,
  }) =>
      Liability(
        id: id,
        name: name ?? this.name,
        type: type ?? this.type,
        principal: principal ?? this.principal,
        outstandingBalance: outstandingBalance ?? this.outstandingBalance,
        emiAmount: emiAmount ?? this.emiAmount,
        interestRate: interestRate ?? this.interestRate,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        notes: notes ?? this.notes,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'type': type,
        'principal': principal,
        'outstanding_balance': outstandingBalance,
        'emi_amount': emiAmount,
        'interest_rate': interestRate,
        'start_date': startDate?.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
        'notes': notes,
      };

  factory Liability.fromMap(Map<String, dynamic> m) => Liability(
        id: m['id'] as int?,
        name: m['name'] as String,
        type: m['type'] as String? ?? 'other',
        principal: (m['principal'] as num).toDouble(),
        outstandingBalance: (m['outstanding_balance'] as num).toDouble(),
        emiAmount: m['emi_amount'] != null
            ? (m['emi_amount'] as num).toDouble()
            : null,
        interestRate: m['interest_rate'] != null
            ? (m['interest_rate'] as num).toDouble()
            : null,
        startDate: m['start_date'] != null
            ? DateTime.parse(m['start_date'] as String)
            : null,
        endDate: m['end_date'] != null
            ? DateTime.parse(m['end_date'] as String)
            : null,
        notes: m['notes'] as String?,
      );
}

const kLiabilityTypes = [
  'Home Loan',
  'Car Loan',
  'Personal Loan',
  'Credit Card',
  'Education Loan',
  'Business Loan',
  'Other',
];
