import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/investment_asset_model.dart';

class FmpResult {
  final double currentValue;
  final double currentPrice;
  final double? priceAtInvestment;
  final double? units;
  final bool needsInvestmentDate;
  final String? error;

  const FmpResult({
    required this.currentValue,
    required this.currentPrice,
    this.priceAtInvestment,
    this.units,
    this.needsInvestmentDate = false,
    this.error,
  });

  bool get success => error == null;
}

class FmpService {
  static const _apiKey = 'lkq00ADv8NIo9kUx77N78qJVxEMjB0MI';
  static const _base = 'https://financialmodelingprep.com/api/v3';

  /// Asset types that can use FMP for real-time prices
  static const _eligibleTypes = {
    'stocks', 'us_stocks', 'gold_etf', 'silver_etf', 'reit',
  };

  /// True when asset should use FMP (has a non-numeric market symbol and eligible type)
  static bool isEligible(InvestmentAsset a) {
    if (a.symbol == null || a.symbol!.isEmpty) return false;
    if (RegExp(r'^\d+$').hasMatch(a.symbol!)) return false; // mfapi scheme code
    return _eligibleTypes.contains(a.type);
  }

  /// Convert stored symbol to FMP format
  static String _fmpSymbol(InvestmentAsset a) {
    final sym = a.symbol!;
    if (a.type == 'us_stocks') return sym; // AAPL, MSFT etc — no suffix
    if (sym.contains('.')) return sym;     // already has suffix
    return '$sym.NS';                      // Indian stocks → RELIANCE.NS
  }

  /// Fetch current price for a symbol. Returns null on failure.
  static Future<double?> fetchCurrentPrice(String fmpSymbol) async {
    try {
      final uri = Uri.parse('$_base/quote/$fmpSymbol?apikey=$_apiKey');
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final list = jsonDecode(res.body) as List<dynamic>;
      if (list.isEmpty) return null;
      final price = list[0]['price'];
      return price is num ? price.toDouble() : null;
    } catch (_) {
      return null;
    }
  }

  /// Fetch closing price for a symbol on a specific date (looks back up to 7 days).
  static Future<double?> fetchPriceOnDate(
      String fmpSymbol, DateTime date) async {
    try {
      for (int offset = 0; offset <= 7; offset++) {
        final d = date.subtract(Duration(days: offset));
        final from = _fmt(d);
        final to = _fmt(d);
        final uri = Uri.parse(
            '$_base/historical-price-full/$fmpSymbol?from=$from&to=$to&apikey=$_apiKey');
        final res = await http.get(uri).timeout(const Duration(seconds: 10));
        if (res.statusCode != 200) continue;
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final hist = body['historical'] as List<dynamic>?;
        if (hist == null || hist.isEmpty) continue;
        final close = hist[0]['close'];
        if (close is num) return close.toDouble();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

  /// Calculate current portfolio value using real market data.
  static Future<FmpResult?> calculate(InvestmentAsset asset) async {
    if (!isEligible(asset)) return null;
    final sym = _fmpSymbol(asset);

    final currentPrice = await fetchCurrentPrice(sym);
    if (currentPrice == null || currentPrice <= 0) return null;

    final investedAt = asset.investedAt;
    if (investedAt == null) {
      return FmpResult(
        currentValue: asset.amountInvested,
        currentPrice: currentPrice,
        needsInvestmentDate: true,
      );
    }

    final priceAtInvestment = await fetchPriceOnDate(sym, investedAt);
    if (priceAtInvestment == null || priceAtInvestment <= 0) {
      return FmpResult(
        currentValue: asset.amountInvested,
        currentPrice: currentPrice,
        needsInvestmentDate: true,
      );
    }

    final units = asset.amountInvested / priceAtInvestment;
    final currentValue = units * currentPrice;
    return FmpResult(
      currentValue: currentValue,
      currentPrice: currentPrice,
      priceAtInvestment: priceAtInvestment,
      units: units,
    );
  }
}
