import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/investment_asset_model.dart';
import '../../core/constants.dart';

class GeminiResult {
  final double? currentValue;
  final double? returnPercent;
  final String? error;

  const GeminiResult({this.currentValue, this.returnPercent, this.error});
  bool get success => currentValue != null;
}

class GeminiService {
  final String apiKey;
  final String model;

  GeminiService({required this.apiKey, required this.model});

  static const _base =
      'https://generativelanguage.googleapis.com/v1beta/models';

  // ── Prompt ────────────────────────────────────────────────────────────────
  // Keep it SHORT and direct. Free-tier Gemini refuses long "financial data"
  // prompts. Framing it as "rough estimate for personal tracking" works.
  String _prompt(InvestmentAsset a) {
    final sym = (a.symbol != null && a.symbol!.isNotEmpty)
        ? ' (${a.symbol})'
        : '';
    final typeLabel = kAssetTypeLabels[a.type] ?? a.type;
    return 'Rough estimate for personal portfolio tracking (not financial advice).\n'
        'Indian investment: ${a.name}$sym, type: $typeLabel\n'
        'Amount invested: INR ${a.amountInvested.toStringAsFixed(0)}\n'
        'Estimate current value and return % based on typical Indian market performance.\n'
        '{"currentValue": <number>, "returnPercent": <number>}';
  }

  // ── Single fetch with retry on 429 ────────────────────────────────────────
  Future<GeminiResult> fetchValue(InvestmentAsset asset) async {
    for (int attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) {
        // Back-off: 3s, 7s
        await Future.delayed(Duration(seconds: attempt * 3 + 1));
      }
      final result = await _doFetch(asset);
      if (result != null) return result;
    }
    return const GeminiResult(error: 'Could not get a response after retries');
  }

  Future<GeminiResult?> _doFetch(InvestmentAsset asset) async {
    final url = Uri.parse('$_base/$model:generateContent?key=$apiKey');
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
                'maxOutputTokens': 64,
                // Force JSON output — key fix for free-tier reliability
                'response_mime_type': 'application/json',
              },
            }),
          )
          .timeout(const Duration(seconds: 25));

      if (res.statusCode == 429) {
        // Rate-limited — caller will retry
        return null;
      }

      if (res.statusCode != 200) {
        final body = jsonDecode(res.body);
        final msg = body['error']?['message'] as String? ??
            'HTTP ${res.statusCode}';
        return GeminiResult(error: msg);
      }

      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final text = decoded['candidates']?[0]?['content']?['parts']?[0]
          ?['text'] as String?;
      if (text == null || text.trim().isEmpty) {
        return const GeminiResult(error: 'Empty response from Gemini');
      }

      return _parseResult(text);
    } catch (e) {
      return GeminiResult(error: e.toString());
    }
  }

  // ── Robust JSON extraction ────────────────────────────────────────────────
  GeminiResult _parseResult(String text) {
    try {
      // Strip markdown fences if present
      final clean = text
          .replaceAll(RegExp(r'```json\s*', caseSensitive: false), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();

      // Try direct parse first
      Map<String, dynamic>? json;
      try {
        json = jsonDecode(clean) as Map<String, dynamic>;
      } catch (_) {
        // Fallback: find first {...} block via regex
        final match = RegExp(r'\{[^}]+\}').firstMatch(clean);
        if (match != null) {
          json = jsonDecode(match.group(0)!) as Map<String, dynamic>;
        }
      }

      if (json == null) {
        return GeminiResult(error: 'Could not parse response: $clean');
      }

      final cv = json['currentValue'];
      final rp = json['returnPercent'];

      if (cv == null) {
        return const GeminiResult(error: 'No value returned by Gemini');
      }

      return GeminiResult(
        currentValue: (cv as num).toDouble(),
        returnPercent: rp != null ? (rp as num).toDouble() : null,
      );
    } catch (e) {
      return GeminiResult(error: 'Parse error: $e');
    }
  }

  // ── Batch fetch (with 1.5 s gap to stay within free-tier 15 RPM) ─────────
  Future<Map<int, GeminiResult>> fetchAllValues(
      List<InvestmentAsset> assets) async {
    final results = <int, GeminiResult>{};
    for (final a in assets) {
      if (a.id == null) continue;
      results[a.id!] = await fetchValue(a);
      await Future.delayed(const Duration(milliseconds: 1500));
    }
    return results;
  }
}
