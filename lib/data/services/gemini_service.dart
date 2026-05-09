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
    final sym = (a.symbol != null && a.symbol!.isNotEmpty)
        ? ' ticker/code:${a.symbol}'
        : '';
    final since = a.investedAt ?? a.createdAt;
    final months = DateTime.now().difference(since).inDays ~/ 30;
    final holdingStr = months <= 0
        ? 'recently invested'
        : months < 12
            ? '$months months ago'
            : '${(months / 12).toStringAsFixed(1)} years ago';
    return 'Indian investment portfolio tracker needs estimated current value.\n'
        'Asset: "${a.name}"$sym\n'
        'Type: ${a.type}, Amount invested: ₹${a.amountInvested.toStringAsFixed(0)}, Invested: $holdingStr\n'
        'Use typical Indian market returns for this asset class over this holding period.\n'
        'Reply ONLY with this JSON, no other text:\n'
        '{"currentValue":NNNN,"returnPercent":NN}';
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
