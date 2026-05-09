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

  // Nifty 50 + popular mid-caps
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
    ("Dr Reddy's", 'DRREDDY'),
    ('Cipla', 'CIPLA'),
    ('Adani Ports', 'ADANIPORTS'),
    ('ONGC', 'ONGC'),
    ('JSW Steel', 'JSWSTEEL'),
    ('Bajaj Auto', 'BAJAJ-AUTO'),
    ('Hero MotoCorp', 'HEROMOTOCO'),
    ('Eicher Motors', 'EICHERMOT'),
    ('Apollo Hospitals', 'APOLLOHOSP'),
    ("Divi's Laboratories", 'DIVISLAB'),
    ('Tata Consumer', 'TATACONSUM'),
    ('Britannia', 'BRITANNIA'),
    ('Hindalco', 'HINDALCO'),
    ('IndusInd Bank', 'INDUSINDBK'),
    ('Tech Mahindra', 'TECHM'),
    ('Zomato', 'ZOMATO'),
    ('Paytm', 'PAYTM'),
    ('Nykaa', 'FSN'),
    ('Jio Financial', 'JIOFIN'),
    ('Adani Green', 'ADANIGREEN'),
    ('Adani Enterprises', 'ADANIENT'),
    ('Tata Power', 'TATAPOWER'),
    ('Vedanta', 'VEDL'),
    ('Coal India', 'COALINDIA'),
    ('BPCL', 'BPCL'),
    ('IOC', 'IOC'),
  ];

  // US Stocks
  static const _usStocks = [
    ('Apple', 'AAPL', 'us_stocks'),
    ('Microsoft', 'MSFT', 'us_stocks'),
    ('Google / Alphabet', 'GOOGL', 'us_stocks'),
    ('Amazon', 'AMZN', 'us_stocks'),
    ('Meta / Facebook', 'META', 'us_stocks'),
    ('Tesla', 'TSLA', 'us_stocks'),
    ('Nvidia', 'NVDA', 'us_stocks'),
    ('Netflix', 'NFLX', 'us_stocks'),
    ('S&P 500 Index', 'SPY', 'us_stocks'),
    ('NASDAQ Index', 'QQQ', 'us_stocks'),
  ];

  // Gold / Silver ETFs and commodities
  static const _goldSilver = [
    ('Nippon Gold BeES', 'GOLDBEES', 'gold_etf'),
    ('HDFC Gold ETF', 'HDFCGOLD', 'gold_etf'),
    ('SBI Gold ETF', 'SBIGOLD', 'gold_etf'),
    ('Axis Gold ETF', 'AXISGOLD', 'gold_etf'),
    ('Kotak Gold ETF', 'KOTAKGOLD', 'gold_etf'),
    ('ICICI Pru Gold ETF', 'IPGETF', 'gold_etf'),
    ('Nippon Silver ETF', 'SILVERIETF', 'silver_etf'),
    ('HDFC Silver ETF', 'HDFCSILVER', 'silver_etf'),
    ('Kotak Silver ETF', 'KOTAKSILVE', 'silver_etf'),
    ('Physical Gold (Jewellery / Bar / Coin)', null, 'physical_gold'),
    ('Physical Silver', null, 'physical_silver'),
  ];

  // Sovereign Gold Bond series (approximate)
  static const _sgb = [
    ('Sovereign Gold Bond (SGB)', 'SGB', 'sgb'),
    ('SGB 2016-17 Series', 'SGB2016', 'sgb'),
    ('SGB 2020-21 Series', 'SGB2021', 'sgb'),
    ('SGB 2022-23 Series', 'SGB2023', 'sgb'),
  ];

  // Popular REITs
  static const _reits = [
    ('Embassy Office Parks REIT', 'EMBASSY', 'reit'),
    ('Mindspace Business Parks REIT', 'MINDSPACE', 'reit'),
    ('Brookfield India REIT', 'BIRET', 'reit'),
    ('Nexus Select Trust REIT', 'NEXUS', 'reit'),
  ];

  // Crypto
  static const _crypto = [
    ('Bitcoin (BTC)', 'BTC', 'crypto'),
    ('Ethereum (ETH)', 'ETH', 'crypto'),
    ('Solana (SOL)', 'SOL', 'crypto'),
    ('Binance Coin (BNB)', 'BNB', 'crypto'),
    ('XRP', 'XRP', 'crypto'),
    ('Cardano (ADA)', 'ADA', 'crypto'),
    ('Dogecoin (DOGE)', 'DOGE', 'crypto'),
    ('Polygon (MATIC)', 'MATIC', 'crypto'),
    ('Shiba Inu (SHIB)', 'SHIB', 'crypto'),
  ];

  // Fixed / government instruments
  static const _fixed = [
    ('Fixed Deposit - SBI', null, 'fixed_deposit'),
    ('Fixed Deposit - HDFC Bank', null, 'fixed_deposit'),
    ('Fixed Deposit - ICICI Bank', null, 'fixed_deposit'),
    ('Fixed Deposit - Axis Bank', null, 'fixed_deposit'),
    ('Fixed Deposit - Kotak Bank', null, 'fixed_deposit'),
    ('Fixed Deposit - Post Office', null, 'fixed_deposit'),
    ('Recurring Deposit (RD)', null, 'recurring_deposit'),
    ('PPF - Public Provident Fund', 'PPF', 'ppf'),
    ('EPF - Employee Provident Fund', 'EPF', 'epf'),
    ('NPS - National Pension System', 'NPS', 'nps'),
    ('NPS Tier 1', 'NPS-T1', 'nps'),
    ('NPS Tier 2', 'NPS-T2', 'nps'),
    ('NSC - National Savings Certificate', 'NSC', 'nsc'),
    ('Post Office MIS', null, 'post_office'),
    ('Post Office TD (Time Deposit)', null, 'post_office'),
    ('Post Office Senior Citizen Scheme', null, 'post_office'),
    ('Senior Citizen Savings Scheme (SCSS)', null, 'post_office'),
    ('Sukanya Samriddhi Yojana (SSY)', 'SSY', 'post_office'),
    ('Kisan Vikas Patra (KVP)', 'KVP', 'post_office'),
    ('GOI Bonds (Government of India)', null, 'bonds'),
    ('RBI Floating Rate Bond', null, 'bonds'),
    ('Corporate Bonds', null, 'bonds'),
    ('Tax-free Bonds', null, 'bonds'),
  ];

  // Real estate
  static const _realEstate = [
    ('Residential Property', null, 'real_estate'),
    ('Commercial Property', null, 'real_estate'),
    ('Plot / Land', null, 'real_estate'),
  ];

  // ULIP
  static const _ulips = [
    ('ULIP - LIC', null, 'ulip'),
    ('ULIP - HDFC Life', null, 'ulip'),
    ('ULIP - ICICI Pru', null, 'ulip'),
    ('ULIP - SBI Life', null, 'ulip'),
    ('ULIP - Bajaj Allianz', null, 'ulip'),
  ];

  /// Search mutual funds (live mfapi.in) + all offline instruments.
  /// Returns up to [limit] deduplicated results. Never throws.
  static Future<List<InvestmentSuggestion>> search(String query,
      {int limit = 8}) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    final seen = <String>{};
    final results = <InvestmentSuggestion>[];

    void add(InvestmentSuggestion s) {
      final key = s.name.toLowerCase();
      if (!seen.contains(key) && results.length < limit) {
        seen.add(key);
        results.add(s);
      }
    }

    // 1. Mutual funds from mfapi.in (live, free, exact NAV available)
    try {
      final uri = Uri.parse('$_mfBase?q=${Uri.encodeComponent(q)}');
      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        for (final item in list.take(5)) {
          final name = item['schemeName'] as String? ?? '';
          if (name.isEmpty) continue;
          add(InvestmentSuggestion(
            name: name,
            symbol: item['schemeCode']?.toString(),
            type: 'mutual_fund',
          ));
        }
      }
    } catch (_) {}

    // 2-9. Offline lists
    for (final (name, sym) in _stocks) {
      if (_matches(q, name, sym)) {
        add(InvestmentSuggestion(name: name, symbol: sym, type: 'stocks'));
      }
    }
    for (final (name, sym, type) in _usStocks) {
      if (_matches(q, name, sym)) {
        add(InvestmentSuggestion(name: name, symbol: sym, type: type));
      }
    }
    for (final (name, sym, type) in _goldSilver) {
      if (_matches(q, name, sym)) {
        add(InvestmentSuggestion(name: name, symbol: sym, type: type));
      }
    }
    for (final (name, sym, type) in _sgb) {
      if (_matches(q, name, sym)) {
        add(InvestmentSuggestion(name: name, symbol: sym, type: type));
      }
    }
    for (final (name, sym, type) in _reits) {
      if (_matches(q, name, sym)) {
        add(InvestmentSuggestion(name: name, symbol: sym, type: type));
      }
    }
    for (final (name, sym, type) in _crypto) {
      if (_matches(q, name, sym)) {
        add(InvestmentSuggestion(name: name, symbol: sym, type: type));
      }
    }
    for (final (name, sym, type) in _fixed) {
      if (_matches(q, name, sym)) {
        add(InvestmentSuggestion(name: name, symbol: sym, type: type));
      }
    }
    for (final (name, _, type) in _realEstate) {
      if (name.toLowerCase().contains(q)) {
        add(InvestmentSuggestion(name: name, symbol: null, type: type));
      }
    }
    for (final (name, _, type) in _ulips) {
      if (name.toLowerCase().contains(q)) {
        add(InvestmentSuggestion(name: name, symbol: null, type: type));
      }
    }

    return results;
  }

  static bool _matches(String q, String name, String? sym) =>
      name.toLowerCase().contains(q) ||
      (sym != null && sym.toLowerCase().contains(q));
}
