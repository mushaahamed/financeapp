import 'dart:convert';
import 'package:http/http.dart' as http;

class InvestmentSuggestion {
  final String name;
  final String? symbol;
  final String type;

  const InvestmentSuggestion(
      {required this.name, this.symbol, required this.type});
}

class SearchService {
  static const _mfBase = 'https://api.mfapi.in/mf/search';

  // Popular Nifty 50 / large-cap stocks for quick offline matching
  static const _stocks = [
    ('Reliance Industries', 'RELIANCE'),
    ('HDFC Bank', 'HDFCBANK'),
    ('ICICI Bank', 'ICICIBANK'),
    ('Infosys', 'INFY'),
    ('TCS', 'TCS'),
    ('Bajaj Finance', 'BAJFINANCE'),
    ('Kotak Mahindra Bank', 'KOTAKBANK'),
    ('Hindustan Unilever', 'HINDUNILVR'),
    ('Axis Bank', 'AXISBANK'),
    ('State Bank of India', 'SBIN'),
    ('Wipro', 'WIPRO'),
    ('HCL Technologies', 'HCLTECH'),
    ('ITC', 'ITC'),
    ('Maruti Suzuki', 'MARUTI'),
    ('Sun Pharma', 'SUNPHARMA'),
    ('Titan Company', 'TITAN'),
    ('Asian Paints', 'ASIANPAINT'),
    ('Larsen & Toubro', 'LT'),
    ('Power Grid', 'POWERGRID'),
    ('NTPC', 'NTPC'),
    ('Bharti Airtel', 'BHARTIARTL'),
    ('Tata Motors', 'TATAMOTORS'),
    ('Tata Steel', 'TATASTEEL'),
    ('UltraTech Cement', 'ULTRACEMCO'),
    ('Nestle India', 'NESTLEIND'),
    ('Dr Reddy\'s', 'DRREDDY'),
    ('Cipla', 'CIPLA'),
    ('Adani Ports', 'ADANIPORTS'),
    ('ONGC', 'ONGC'),
    ('JSW Steel', 'JSWSTEEL'),
    ('Bajaj Auto', 'BAJAJ-AUTO'),
    ('Hero MotoCorp', 'HEROMOTOCO'),
    ('Eicher Motors', 'EICHERMOT'),
    ('Apollo Hospitals', 'APOLLOHOSP'),
    ('Divi\'s Laboratories', 'DIVISLAB'),
    ('Tata Consumer', 'TATACONSUM'),
    ('Britannia', 'BRITANNIA'),
    ('Hindalco', 'HINDALCO'),
    ('IndusInd Bank', 'INDUSINDBK'),
    ('Tech Mahindra', 'TECHM'),
  ];

  // Also include common gold/silver products
  static const _commodities = [
    ('Physical Gold', null, 'physical_gold'),
    ('Sovereign Gold Bond', 'SGB', 'physical_gold'),
    ('HDFC Gold ETF', 'HDFCGOLD', 'gold_etf'),
    ('SBI Gold ETF', 'SBIGOLD', 'gold_etf'),
    ('Nippon Gold BeES', 'GOLDBEES', 'gold_etf'),
    ('Axis Gold ETF', 'AXISGOLD', 'gold_etf'),
    ('Kotak Gold ETF', 'KOTAKGOLD', 'gold_etf'),
    ('HDFC Silver ETF', 'HDFCSILVER', 'silver_etf'),
    ('Nippon Silver ETF', 'SILVERIETF', 'silver_etf'),
    ('Kotak Silver ETF', null, 'silver_etf'),
  ];

  /// Search mutual funds via mfapi.in + offline stocks + commodities.
  /// Returns up to [limit] results. Never throws.
  static Future<List<InvestmentSuggestion>> search(String query,
      {int limit = 7}) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    final results = <InvestmentSuggestion>[];

    // 1. Mutual funds from mfapi.in (live, free)
    try {
      final uri = Uri.parse('$_mfBase?q=${Uri.encodeComponent(q)}');
      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        for (final item in list.take(5)) {
          final name = item['schemeName'] as String? ?? '';
          if (name.isEmpty) continue;
          results.add(InvestmentSuggestion(
            name: name,
            symbol: item['schemeCode']?.toString(),
            type: 'mutual_fund',
          ));
        }
      }
    } catch (_) {
      // Network unavailable — fall through to offline results
    }

    // 2. Offline stocks
    for (final (name, sym) in _stocks) {
      if (name.toLowerCase().contains(q) || sym.toLowerCase().contains(q)) {
        results.add(
            InvestmentSuggestion(name: name, symbol: sym, type: 'stocks'));
        if (results.length >= limit) break;
      }
    }

    // 3. Offline commodities
    for (final (name, sym, type) in _commodities) {
      if (name.toLowerCase().contains(q) ||
          (sym != null && sym.toLowerCase().contains(q))) {
        results.add(InvestmentSuggestion(name: name, symbol: sym, type: type));
        if (results.length >= limit) break;
      }
    }

    return results.take(limit).toList();
  }
}
