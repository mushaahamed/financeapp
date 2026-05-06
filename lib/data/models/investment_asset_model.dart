class InvestmentAsset {
  final int? id;
  final String name;
  final String type; // physical_gold | gold_etf | silver_etf | mutual_fund | stocks | other
  final String? symbol;
  final String currency;
  final double unitsHeld;
  final double avgBuyPricePerUnit;
  final double totalInvested;
  final double? lastKnownPricePerUnit;
  final DateTime? lastPriceUpdateAt;
  final String? notes;

  const InvestmentAsset({
    this.id,
    required this.name,
    required this.type,
    this.symbol,
    this.currency = 'INR',
    this.unitsHeld = 0,
    this.avgBuyPricePerUnit = 0,
    this.totalInvested = 0,
    this.lastKnownPricePerUnit,
    this.lastPriceUpdateAt,
    this.notes,
  });

  double? get currentValue => lastKnownPricePerUnit != null
      ? unitsHeld * lastKnownPricePerUnit!
      : null;

  double? get unrealizedPnl => currentValue != null
      ? currentValue! - totalInvested
      : null;

  double? get returnPercent {
    if (totalInvested == 0) return null;
    final pnl = unrealizedPnl;
    if (pnl == null) return null;
    return (pnl / totalInvested) * 100;
  }

  InvestmentAsset copyWith({
    String? name,
    String? type,
    String? symbol,
    String? currency,
    double? unitsHeld,
    double? avgBuyPricePerUnit,
    double? totalInvested,
    double? lastKnownPricePerUnit,
    DateTime? lastPriceUpdateAt,
    String? notes,
    bool clearPrice = false,
  }) {
    return InvestmentAsset(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      symbol: symbol ?? this.symbol,
      currency: currency ?? this.currency,
      unitsHeld: unitsHeld ?? this.unitsHeld,
      avgBuyPricePerUnit: avgBuyPricePerUnit ?? this.avgBuyPricePerUnit,
      totalInvested: totalInvested ?? this.totalInvested,
      lastKnownPricePerUnit:
          clearPrice ? null : (lastKnownPricePerUnit ?? this.lastKnownPricePerUnit),
      lastPriceUpdateAt:
          clearPrice ? null : (lastPriceUpdateAt ?? this.lastPriceUpdateAt),
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'type': type,
        'symbol': symbol,
        'currency': currency,
        'units_held': unitsHeld,
        'avg_buy_price_per_unit': avgBuyPricePerUnit,
        'total_invested': totalInvested,
        'last_known_price_per_unit': lastKnownPricePerUnit,
        'last_price_update_at': lastPriceUpdateAt?.toIso8601String(),
        'notes': notes,
      };

  factory InvestmentAsset.fromMap(Map<String, dynamic> map) => InvestmentAsset(
        id: map['id'] as int?,
        name: map['name'] as String,
        type: map['type'] as String,
        symbol: map['symbol'] as String?,
        currency: map['currency'] as String,
        unitsHeld: (map['units_held'] as num).toDouble(),
        avgBuyPricePerUnit: (map['avg_buy_price_per_unit'] as num).toDouble(),
        totalInvested: (map['total_invested'] as num).toDouble(),
        lastKnownPricePerUnit: map['last_known_price_per_unit'] != null
            ? (map['last_known_price_per_unit'] as num).toDouble()
            : null,
        lastPriceUpdateAt: map['last_price_update_at'] != null
            ? DateTime.parse(map['last_price_update_at'] as String)
            : null,
        notes: map['notes'] as String?,
      );
}
