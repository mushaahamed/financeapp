import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/investment_asset_model.dart';
import '../../core/constants.dart';

class GeminiPriceResult {
  final double? price;
  final String? error;
  const GeminiPriceResult({this.price, this.error});
  bool get success => price != null;
}

class GeminiService {
  final String apiKey;
  final String model;

  GeminiService({required this.apiKey, required this.model});

  static const _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  String _buildPrompt(InvestmentAsset asset) {
    final symbolHint =
        (asset.symbol != null && asset.symbol!.isNotEmpty)
            ? ', symbol/identifier: ${asset.symbol}'
            : '';
    return '''You are a financial data assistant. Return ONLY valid JSON with no markdown.
For the asset below, provide the current approximate market price per unit in ${asset.currency}.
Asset: name="${asset.name}", type="${kAssetTypeLabels[asset.type] ?? asset.type}"$symbolHint.
Output format (JSON only, nothing else): {"price": <number>, "currency": "${asset.currency}"}
If you cannot determine the price, output: {"price": null, "currency": "${asset.currency}", "error": "reason"}''';
  }

  Future<GeminiPriceResult> fetchPrice(InvestmentAsset asset) async {
    final url = Uri.parse('$_baseUrl/$model:generateContent?key=$apiKey');
    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': _buildPrompt(asset)}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.1,
        'maxOutputTokens': 256,
      }
    });

    try {
      final response = await http
          .post(url, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        final decoded = jsonDecode(response.body);
        final msg = decoded['error']?['message'] ?? 'HTTP ${response.statusCode}';
        return GeminiPriceResult(error: msg);
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final text = decoded['candidates']?[0]?['content']?['parts']?[0]?['text']
          as String?;
      if (text == null) {
        return const GeminiPriceResult(error: 'Empty response from Gemini');
      }

      // Strip possible markdown code fences
      final cleaned = text
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();

      final json = jsonDecode(cleaned) as Map<String, dynamic>;
      if (json['price'] == null) {
        return GeminiPriceResult(
            error: json['error']?.toString() ?? 'Price not available');
      }

      final price = (json['price'] as num).toDouble();
      return GeminiPriceResult(price: price);
    } catch (e) {
      return GeminiPriceResult(error: e.toString());
    }
  }

  Future<Map<int, GeminiPriceResult>> fetchAllPrices(
      List<InvestmentAsset> assets) async {
    final results = <int, GeminiPriceResult>{};
    for (final asset in assets) {
      if (asset.id == null) continue;
      results[asset.id!] = await fetchPrice(asset);
      // small delay between calls to avoid hitting free-tier rate limits
      await Future.delayed(const Duration(milliseconds: 1200));
    }
    return results;
  }
}
