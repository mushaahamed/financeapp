import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/investment_asset_model.dart';

class NavResult {
  final double currentValue;
  final double currentNav;
  final double? navAtInvestment;
  final double? units;
  final String? error;

  const NavResult({
    required this.currentValue,
    required this.currentNav,
    this.navAtInvestment,
    this.units,
    this.error,
  });

  bool get success => error == null;
}

class NavService {
  static const _base = 'https://api.mfapi.in/mf';

  /// Returns true if this asset can get an exact NAV from mfapi.in.
  /// True when symbol is a numeric string (mfapi schemeCode) or type is mutual_fund.
  static bool isEligible(InvestmentAsset a) {
    if (a.symbol != null && RegExp(r'^\d+$').hasMatch(a.symbol!)) return true;
    return false;
  }

  /// Fetch current NAV and calculate accurate current value.
  /// If [investedAt] is set, calculates units and real P&L.
  /// If not set, just returns current value = amount invested (no fabricated P&L).
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

      // data[0] is the most recent NAV (DD-MM-YYYY, nav as string)
      final currentNav = double.tryParse(data[0]['nav'] as String? ?? '');
      if (currentNav == null || currentNav <= 0) return null;

      final investedAt = asset.investedAt;
      if (investedAt == null) {
        // No investment date — can't calculate units.
        // Show current value = amount invested to avoid fabricated P&L.
        return NavResult(
          currentValue: asset.amountInvested,
          currentNav: currentNav,
          error: null,
        );
      }

      // Find NAV closest to investedAt date
      final navAtInvestment = _findNavOnDate(data, investedAt);
      if (navAtInvestment == null || navAtInvestment <= 0) {
        // Can't find historical NAV — use current NAV, P&L unknown
        return NavResult(
          currentValue: asset.amountInvested,
          currentNav: currentNav,
          error: null,
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

  /// Find NAV for a date, searching backward up to 7 days (for weekends/holidays).
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

  /// Convert DateTime to mfapi date format: DD-MM-YYYY
  static String _toMfapiDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd-$mm-${d.year}';
  }
}
