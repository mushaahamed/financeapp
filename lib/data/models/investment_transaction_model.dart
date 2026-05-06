class InvestmentTransaction {
  final int? id;
  final int assetId;
  final String type; // 'buy' or 'sell'
  final double units;
  final double pricePerUnit;
  final DateTime timestamp;

  const InvestmentTransaction({
    this.id,
    required this.assetId,
    required this.type,
    required this.units,
    required this.pricePerUnit,
    required this.timestamp,
  });

  double get totalValue => units * pricePerUnit;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'asset_id': assetId,
        'type': type,
        'units': units,
        'price_per_unit': pricePerUnit,
        'timestamp': timestamp.toIso8601String(),
      };

  factory InvestmentTransaction.fromMap(Map<String, dynamic> map) =>
      InvestmentTransaction(
        id: map['id'] as int?,
        assetId: map['asset_id'] as int,
        type: map['type'] as String,
        units: (map['units'] as num).toDouble(),
        pricePerUnit: (map['price_per_unit'] as num).toDouble(),
        timestamp: DateTime.parse(map['timestamp'] as String),
      );
}
