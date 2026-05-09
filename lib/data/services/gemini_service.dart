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

  String _prompt(InvestmentAsset a) {
    final sym = (a.symbol != null && a.symbol!.isNotEmpty)
        ? ', symbol: ${a.symbol}'
        : '';
    return '''You are a financial data assistant for Indian markets.
Estimate the current market value of this investment in ${a.currency}.

Investment details:
- Name: ${a.name}
- Type: ${kAssetTypeLabels[a.type] ?? a.type}$sym
- Amount originally invested: ${a.amountInvested} ${a.currency}

Based on current market conditions, estimate:
1. Current value of this investment
2. Approximate % return (positive = gain, negative = loss)

Return ONLY valid JSON, nothing else:
{"currentValue": <number>, "returnPercent": <number>}

If you cannot estimate, return:
{"currentValue": null, "returnPercent": null}''';
  }

  Future<GeminiResult> fetchValue(InvestmentAsset asset) async {
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
                'maxOutputTokens': 128,
              }
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (res.statusCode != 200) {
        final msg = jsonDecode(res.body)['error']?['message'] ??
            'HTTP ${res.statusCode}';
        return GeminiResult(error: msg);
      }

      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final text = decoded['candidates']?[0]?['content']?['parts']?[0]
          ?['text'] as String?;
      if (text == null) return const GeminiResult(error: 'Empty response');

      final clean = text
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();

      final json = jsonDecode(clean) as Map<String, dynamic>;
      if (json['currentValue'] == null) {
        return const GeminiResult(error: 'Could not estimate value');
      }

      return GeminiResult(
        currentValue: (json['currentValue'] as num).toDouble(),
        returnPercent: json['returnPercent'] != null
            ? (json['returnPercent'] as num).toDouble()
            : null,
      );
    } catch (e) {
      return GeminiResult(error: e.toString());
    }
  }

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
