class InvestmentAsset {
  final int? id;
  final String name;
  final String type;
  final String? symbol;
  final String currency;
  final double amountInvested;   // total money you put in
  final double? currentValue;    // Gemini-estimated current value
  final DateTime createdAt;
  final DateTime? lastUpdatedAt;
  final String? notes;

  const InvestmentAsset({
    this.id,
    required this.name,
    this.type = 'other',
    this.symbol,
    this.currency = 'INR',
    required this.amountInvested,
    this.currentValue,
    required this.createdAt,
    this.lastUpdatedAt,
    this.notes,
  });

  double get effectiveValue => currentValue ?? amountInvested;
  double? get pnl => currentValue != null ? currentValue! - amountInvested : null;
  double? get returnPct =>
      (pnl != null && amountInvested > 0) ? (pnl! / amountInvested * 100) : null;

  InvestmentAsset copyWith({
    String? name,
    String? type,
    String? symbol,
    String? currency,
    double? amountInvested,
    double? currentValue,
    DateTime? lastUpdatedAt,
    String? notes,
    bool clearValue = false,
  }) =>
      InvestmentAsset(
        id: id,
        name: name ?? this.name,
        type: type ?? this.type,
        symbol: symbol ?? this.symbol,
        currency: currency ?? this.currency,
        amountInvested: amountInvested ?? this.amountInvested,
        currentValue: clearValue ? null : (currentValue ?? this.currentValue),
        createdAt: createdAt,
        lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
        notes: notes ?? this.notes,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'type': type,
        'symbol': symbol,
        'currency': currency,
        'amount_invested': amountInvested,
        'current_value': currentValue,
        'created_at': createdAt.toIso8601String(),
        'last_updated_at': lastUpdatedAt?.toIso8601String(),
        'notes': notes,
      };

  factory InvestmentAsset.fromMap(Map<String, dynamic> m) => InvestmentAsset(
        id: m['id'] as int?,
        name: m['name'] as String,
        type: m['type'] as String,
        symbol: m['symbol'] as String?,
        currency: m['currency'] as String,
        amountInvested: (m['amount_invested'] as num).toDouble(),
        currentValue: m['current_value'] != null
            ? (m['current_value'] as num).toDouble()
            : null,
        createdAt: DateTime.parse(m['created_at'] as String),
        lastUpdatedAt: m['last_updated_at'] != null
            ? DateTime.parse(m['last_updated_at'] as String)
            : null,
        notes: m['notes'] as String?,
      );
}
