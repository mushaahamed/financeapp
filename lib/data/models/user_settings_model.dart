class UserSettings {
  final int id;
  final double currentCash;
  final String currency;
  final int weeklyUpdateDay; // 0=Monday … 6=Sunday
  final String weeklyUpdateTime; // "HH:mm" 24h
  final bool autoUpdateEnabled;
  final String geminiModel;
  final DateTime? lastPortfolioUpdate;

  const UserSettings({
    this.id = 1,
    this.currentCash = 0,
    this.currency = 'INR',
    this.weeklyUpdateDay = 0,
    this.weeklyUpdateTime = '09:00',
    this.autoUpdateEnabled = true,
    this.geminiModel = 'gemini-2.0-flash',
    this.lastPortfolioUpdate,
  });

  UserSettings copyWith({
    double? currentCash,
    String? currency,
    int? weeklyUpdateDay,
    String? weeklyUpdateTime,
    bool? autoUpdateEnabled,
    String? geminiModel,
    DateTime? lastPortfolioUpdate,
    bool clearLastUpdate = false,
  }) {
    return UserSettings(
      id: id,
      currentCash: currentCash ?? this.currentCash,
      currency: currency ?? this.currency,
      weeklyUpdateDay: weeklyUpdateDay ?? this.weeklyUpdateDay,
      weeklyUpdateTime: weeklyUpdateTime ?? this.weeklyUpdateTime,
      autoUpdateEnabled: autoUpdateEnabled ?? this.autoUpdateEnabled,
      geminiModel: geminiModel ?? this.geminiModel,
      lastPortfolioUpdate:
          clearLastUpdate ? null : (lastPortfolioUpdate ?? this.lastPortfolioUpdate),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'current_cash': currentCash,
        'currency': currency,
        'weekly_update_day': weeklyUpdateDay,
        'weekly_update_time': weeklyUpdateTime,
        'auto_update_enabled': autoUpdateEnabled ? 1 : 0,
        'gemini_model': geminiModel,
        'last_portfolio_update': lastPortfolioUpdate?.toIso8601String(),
      };

  factory UserSettings.fromMap(Map<String, dynamic> map) => UserSettings(
        id: map['id'] as int,
        currentCash: (map['current_cash'] as num).toDouble(),
        currency: map['currency'] as String,
        weeklyUpdateDay: map['weekly_update_day'] as int,
        weeklyUpdateTime: map['weekly_update_time'] as String,
        autoUpdateEnabled: (map['auto_update_enabled'] as int) == 1,
        geminiModel: map['gemini_model'] as String,
        lastPortfolioUpdate: map['last_portfolio_update'] != null
            ? DateTime.parse(map['last_portfolio_update'] as String)
            : null,
      );
}
