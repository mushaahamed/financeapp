import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/investment_asset_model.dart';

class NavResult {
  final double currentValue;
  final double currentNav;
  final double? navAtInvestment;
  final double? units;
  /// True when investedAt was not set — currentValue = amountInvested,
  /// P&L is unknown. UI should prompt user to set investment date.
  final bool needsInvestmentDate;
  final String? error;

  const NavResult({
    required this.currentValue,
    required this.currentNav,
    this.navAtInvestment,
    this.units,
    this.needsInvestmentDate = false,
    this.error,
  });

  bool get success => error == null;
  bool get hasPnl => units != null && navAtInvestment != null;
}

class NavService {
  static const _base = 'https://api.mfapi.in/mf';

  /// True when the asset has a numeric mfapi.in scheme code as symbol.
  static bool isEligible(InvestmentAsset a) =>
      a.symbol != null && RegExp(r'^\d+$').hasMatch(a.symbol!);

  /// Fetch only the latest NAV for a scheme code. Returns null on failure.
  static Future<double?> fetchCurrentNav(String schemeCode) async {
    try {
      final uri = Uri.parse('$_base/$schemeCode');
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final data = body['data'] as List<dynamic>?;
      if (data == null || data.isEmpty) return null;
      return double.tryParse(data[0]['nav'] as String? ?? '');
    } catch (_) {
      return null;
    }
  }

  /// Calculate current portfolio value for a mfapi-eligible asset.
  ///
  /// If [investedAt] is set:
  ///   units = amountInvested ÷ NAV_on_investedAt
  ///   currentValue = units × currentNAV  (exact P&L)
  ///
  /// If [investedAt] is not set:
  ///   currentValue = amountInvested (safe, no fabricated P&L)
  ///   needsInvestmentDate = true  (UI shows prompt to set date)
  ///   currentNav is still returned so user can see live NAV
  static Future<NavResult?> calculate(InvestmentAsset asset) async {
    if (!isEligible(asset)) return null;
    final schemeCode = asset.symbol!;

    try {
      final uri = Uri.parse('$_base/$schemeCode');
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final data = body['data'] as List<dynamic>?;
      if (data == null || data.isEmpty) return null;

      final currentNav =
          double.tryParse(data[0]['nav'] as String? ?? '');
      if (currentNav == null || currentNav <= 0) return null;

      final investedAt = asset.investedAt;
      if (investedAt == null) {
        // No investment date — show live NAV but can't compute P&L
        return NavResult(
          currentValue: asset.amountInvested,
          currentNav: currentNav,
          needsInvestmentDate: true,
        );
      }

      // Find NAV closest to investedAt (look back up to 7 days for holidays)
      final navAtInvestment = _findNavOnDate(data, investedAt);
      if (navAtInvestment == null || navAtInvestment <= 0) {
        return NavResult(
          currentValue: asset.amountInvested,
          currentNav: currentNav,
          needsInvestmentDate: true,
        );
      }

      final units = asset.amountInvested / navAtInvestment;
      final currentValue = units * currentNav;

      return NavResult(
        currentValue: currentValue,
        currentNav: currentNav,
        navAtInvestment: navAtInvestment,
        units: units,
      );
    } catch (_) {
      return null;
    }
  }

  static double? _findNavOnDate(List<dynamic> data, DateTime target) {
    for (int offset = 0; offset <= 7; offset++) {
      final d = target.subtract(Duration(days: offset));
      final key = _toMfapiDate(d);
      for (final entry in data) {
        if (entry['date'] == key) {
          return double.tryParse(entry['nav'] as String? ?? '');
        }
      }
    }
    return null;
  }

  static String _toMfapiDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd-$mm-${d.year}';
  }
}
