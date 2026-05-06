class Expense {
  final int? id;
  final String title;
  final double amount;
  final DateTime timestamp;
  final String? category;
  final String? notes;

  const Expense({
    this.id,
    required this.title,
    required this.amount,
    required this.timestamp,
    this.category,
    this.notes,
  });

  Expense copyWith({
    String? title,
    double? amount,
    DateTime? timestamp,
    String? category,
    String? notes,
  }) {
    return Expense(
      id: id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      timestamp: timestamp ?? this.timestamp,
      category: category ?? this.category,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'title': title,
        'amount': amount,
        'timestamp': timestamp.toIso8601String(),
        'category': category,
        'notes': notes,
      };

  factory Expense.fromMap(Map<String, dynamic> map) => Expense(
        id: map['id'] as int?,
        title: map['title'] as String,
        amount: (map['amount'] as num).toDouble(),
        timestamp: DateTime.parse(map['timestamp'] as String),
        category: map['category'] as String?,
        notes: map['notes'] as String?,
      );
}
