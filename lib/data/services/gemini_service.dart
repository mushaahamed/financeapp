import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/investment_asset_model.dart';
import '../../core/constants.dart';

class GeminiResult {
  final double? currentValue;
  final double? returnPercent;
  final String? error;

  const GeminiResult({this.currentValue, this.returnPercent, this.error});
  bool get success => currentValue != null && currentValue! > 0;
}

class GeminiService {
  final String apiKey;
  final String model;

  GeminiService({required this.apiKey, required this.model});

  static const _base =
      'https://generativelanguage.googleapis.com/v1beta/models';

  // Fallback model chain — tried in order if configured model fails
  static const _fallbackModels = [
    'gemini-2.5-flash',
    'gemini-2.0-flash',
    'gemini-2.0-flash-lite',
  ];

  String _prompt(InvestmentAsset a) {
    final sym = (a.symbol != null &&
            a.symbol!.isNotEmpty &&
            !RegExp(r'^\d+$').hasMatch(a.symbol!))
        ? ' (ticker: ${a.symbol})'
        : '';
    final since = a.investedAt ?? a.createdAt;
    final months = DateTime.now().difference(since).inDays ~/ 30;
    final holdingStr = months <= 0
        ? '< 1 month'
        : months < 12
            ? '$months months'
            : '${(months / 12).toStringAsFixed(1)} years';

    // Typical CAGR hints so Gemini doesn't fabricate wild numbers
    final hint = _cagrHint(a.type);

    return 'Indian personal finance app needs an estimated current value for a portfolio asset.\n'
        'Asset: "${a.name}"$sym\n'
        'Type: ${a.type}, Invested: ₹${a.amountInvested.toStringAsFixed(0)}, Holding period: $holdingStr\n'
        '$hint\n'
        'Calculate currentValue = invested × (1 + annualRate)^years for the holding period.\n'
        'Be conservative. Do NOT invent specific fund performance.\n'
        'Reply ONLY with this JSON, no markdown:\n'
        '{"currentValue":NNNN,"returnPercent":NN.N}';
  }

  static String _cagrHint(String type) {
    switch (type) {
      case 'mutual_fund':
        return 'Equity mutual fund avg CAGR in India: 12-15%/yr. Debt: 6-8%/yr. Use 12% if unknown.';
      case 'stocks':
        return 'Indian large-cap stock avg CAGR: 12-15%/yr. Use 12% if unknown.';
      case 'us_stocks':
        return 'US large-cap avg CAGR: ~14%/yr in USD. Add ~2% for INR depreciation.';
      case 'gold_etf':
        return 'Gold ETF mirrors gold price. India gold CAGR: 8-12%/yr. Use 10%.';
      case 'silver_etf':
        return 'Silver ETF India CAGR: 6-10%/yr. Use 8%.';
      case 'physical_gold':
        return 'Physical gold India CAGR: 8-12%/yr. Use 10%.';
      case 'physical_silver':
        return 'Physical silver India CAGR: 6-10%/yr. Use 8%.';
      case 'sgb':
        return 'SGB: gold price appreciation + 2.5% interest. Total ~10-12%/yr. Use 10%.';
      case 'reit':
        return 'Indian REIT avg return: 8-12%/yr (yield + appreciation). Use 9%.';
      case 'crypto':
        return 'Crypto is volatile. Use conservative 15%/yr for established coins (BTC/ETH). May be negative.';
      case 'fixed_deposit':
        return 'FD interest rate in India: 6.5-7.5%/yr. Use 7%.';
      case 'recurring_deposit':
        return 'RD interest rate in India: 6-7%/yr. Use 6.5%.';
      case 'ppf':
        return 'PPF current rate: 7.1%/yr, compounded annually, tax-free.';
      case 'epf':
        return 'EPF current rate: 8.25%/yr, compounded annually, tax-free on maturity.';
      case 'nps':
        return 'NPS equity-heavy avg CAGR: 10-12%/yr. Debt: 7-9%/yr. Use 10%.';
      case 'nsc':
        return 'NSC current rate: 7.7%/yr, compounded half-yearly.';
      case 'bonds':
        return 'Indian govt/corporate bonds avg: 7-8%/yr. Use 7.5%.';
      case 'post_office':
        return 'Post office schemes (MIS/TD/SCSS/SSY/KVP): 7-8.2%/yr. Use 7.5%.';
      case 'real_estate':
        return 'Real estate appreciation in India: 6-10%/yr. Use 7%. Add rental yield if applicable.';
      case 'ulip':
        return 'ULIP equity avg CAGR after charges: 8-12%/yr. Use 10%.';
      case 'gold_scheme':
        return 'Gold saving scheme: tracks gold price. India gold CAGR: 8-12%/yr. Use 10%.';
      case 'chit_fund':
        return 'Chit fund: returns vary 8-15%/yr depending on auction discounts. Use 10%.';
      default:
        return 'Use a conservative 8% annual return estimate.';
    }
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<GeminiResult> fetchValue(InvestmentAsset asset) async {
    // Build model list: configured model first, then fallbacks (deduplicated)
    final models = [
      model,
      ..._fallbackModels.where((m) => m != model),
    ];

    String lastError = 'Unknown error';

    for (final m in models) {
      for (int attempt = 0; attempt < 2; attempt++) {
        if (attempt > 0) await Future.delayed(const Duration(seconds: 5));

        final result = await _call(asset, m);

        if (result == null) {
          // 429 rate-limited — retry once
          lastError = 'Rate limit hit on $m';
          continue;
        }

        if (result.success) return result;

        // Hard error (auth, not found, etc.) — try next model
        lastError = result.error ?? 'Failed on $m';
        break;
      }
    }

    return GeminiResult(error: lastError);
  }

  // ── Internal call ──────────────────────────────────────────────────────────

  /// Returns null on 429 (rate limited — caller retries).
  Future<GeminiResult?> _call(InvestmentAsset asset, String modelName) async {
    final url =
        Uri.parse('$_base/$modelName:generateContent?key=$apiKey');

    try {
      final res = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': _prompt(asset)}
                  ]
                }
              ],
              'generationConfig': {
                'temperature': 0.1,
                'maxOutputTokens': 200,
                'response_mime_type': 'application/json',
                // Disable thinking for 2.5-flash — otherwise it uses
                // hundreds of tokens "thinking" and hits maxOutputTokens
                'thinkingConfig': {'thinkingBudget': 0},
              },
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (res.statusCode == 429) return null; // caller retries

      if (res.statusCode != 200) {
        String msg;
        try {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          msg = body['error']?['message'] as String? ??
              'HTTP ${res.statusCode}';
        } catch (_) {
          msg = 'HTTP ${res.statusCode}';
        }
        return GeminiResult(error: msg);
      }

      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final text = decoded['candidates']?[0]?['content']?['parts']?[0]
          ?['text'] as String?;

      if (text == null || text.trim().isEmpty) {
        final reason =
            decoded['candidates']?[0]?['finishReason'] as String?;
        return GeminiResult(
            error: reason != null
                ? 'Gemini stopped: $reason'
                : 'Empty response');
      }

      return _parse(text.trim());
    } on Exception catch (e) {
      return GeminiResult(error: 'Network: $e');
    }
  }

  // ── JSON extraction ────────────────────────────────────────────────────────

  GeminiResult _parse(String text) {
    final clean = text
        .replaceAll(RegExp(r'```json\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'```\s*'), '')
        .trim();

    Map<String, dynamic>? json;

    // 1. Direct parse
    try {
      json = jsonDecode(clean) as Map<String, dynamic>;
    } catch (_) {}

    // 2. Find first {...} block
    if (json == null) {
      final match = RegExp(r'\{[^{}]+\}').firstMatch(clean);
      if (match != null) {
        try {
          json = jsonDecode(match.group(0)!) as Map<String, dynamic>;
        } catch (_) {}
      }
    }

    // 3. Field-by-field regex
    if (json == null) {
      final cv = RegExp(r'"currentValue"\s*:\s*([\d.]+)').firstMatch(clean);
      final rp = RegExp(r'"returnPercent"\s*:\s*(-?[\d.]+)').firstMatch(clean);
      if (cv != null) {
        json = {
          'currentValue': double.tryParse(cv.group(1)!),
          'returnPercent':
              rp != null ? double.tryParse(rp.group(1)!) : null,
        };
      }
    }

    if (json == null) return GeminiResult(error: 'Could not parse: $clean');

    final cv = json['currentValue'];
    if (cv == null) return const GeminiResult(error: 'No value in response');

    final cvDouble = cv is num ? cv.toDouble() : double.tryParse('$cv');
    if (cvDouble == null || cvDouble <= 0) {
      return const GeminiResult(error: 'Invalid value returned');
    }

    final rp = json['returnPercent'];
    final rpDouble = rp is num ? rp.toDouble() : double.tryParse('$rp');

    return GeminiResult(currentValue: cvDouble, returnPercent: rpDouble);
  }
}
