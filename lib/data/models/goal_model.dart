class Goal {
  final int? id;
  final String title;
  final double targetAmount;
  final double savedAmount;
  final String category;
  final DateTime? deadline;
  final String? notes;
  final DateTime createdAt;

  const Goal({
    this.id,
    required this.title,
    required this.targetAmount,
    this.savedAmount = 0,
    this.category = 'Other',
    this.deadline,
    this.notes,
    required this.createdAt,
  });

  double get progressPct =>
      targetAmount > 0 ? (savedAmount / targetAmount).clamp(0.0, 1.0) : 0.0;
  bool get isComplete => savedAmount >= targetAmount;
  double get remaining => (targetAmount - savedAmount).clamp(0.0, double.infinity);

  int? get daysRemaining {
    if (deadline == null) return null;
    return deadline!.difference(DateTime.now()).inDays;
  }

  bool get isOverdue =>
      deadline != null &&
      deadline!.isBefore(DateTime.now()) &&
      !isComplete;

  Goal copyWith({
    String? title,
    double? targetAmount,
    double? savedAmount,
    String? category,
    DateTime? deadline,
    String? notes,
    bool clearDeadline = false,
  }) =>
      Goal(
        id: id,
        title: title ?? this.title,
        targetAmount: targetAmount ?? this.targetAmount,
        savedAmount: savedAmount ?? this.savedAmount,
        category: category ?? this.category,
        deadline: clearDeadline ? null : (deadline ?? this.deadline),
        notes: notes ?? this.notes,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'title': title,
        'target_amount': targetAmount,
        'saved_amount': savedAmount,
        'category': category,
        'deadline': deadline?.toIso8601String(),
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
      };

  factory Goal.fromMap(Map<String, dynamic> m) => Goal(
        id: m['id'] as int?,
        title: m['title'] as String,
        targetAmount: (m['target_amount'] as num).toDouble(),
        savedAmount: (m['saved_amount'] as num? ?? 0).toDouble(),
        category: m['category'] as String? ?? 'Other',
        deadline: m['deadline'] != null
            ? DateTime.parse(m['deadline'] as String)
            : null,
        notes: m['notes'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

const kGoalCategories = [
  'Emergency Fund',
  'Retirement',
  'Education',
  'House / Property',
  'Car / Vehicle',
  'Vacation',
  'Wedding',
  'Business',
  'Medical',
  'Other',
];
