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

  // Very short, direct prompt — free tier refuses long "financial advice" prompts
  String _prompt(InvestmentAsset a) {
    final sym = (a.symbol != null && a.symbol!.isNotEmpty)
        ? ' ticker:${a.symbol}'
        : '';
    return 'Indian investment tracker needs a rough estimate.\n'
        'Asset: "${a.name}"$sym type:${a.type} invested:${a.amountInvested.toStringAsFixed(0)} INR\n'
        'Based on typical Indian market performance, estimate current value.\n'
        'Reply with ONLY this JSON (numbers only, no text before or after):\n'
        '{"currentValue":NNNN,"returnPercent":NN}';
  }

  Future<GeminiResult> fetchValue(InvestmentAsset asset) async {
    // Try up to 3 times; on 429 back off, on 400 try without JSON mime type
    for (int attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) await Future.delayed(Duration(seconds: attempt * 4));

      // First attempt: with response_mime_type (forces JSON on supported models)
      // Second attempt: without (fallback for older endpoints)
      final useMime = attempt < 2;
      final result = await _call(asset, useJsonMime: useMime);

      if (result == null) continue; // 429 — retry
      return result;
    }
    return const GeminiResult(error: 'No response after 3 attempts. Check API key in Settings.');
  }

  /// Returns null only on 429 (caller should retry). All other cases return a GeminiResult.
  Future<GeminiResult?> _call(InvestmentAsset asset, {required bool useJsonMime}) async {
    final url = Uri.parse('$_base/$model:generateContent?key=$apiKey');

    final genConfig = <String, dynamic>{
      'temperature': 0.1,
      'maxOutputTokens': 80,
    };
    if (useJsonMime) genConfig['response_mime_type'] = 'application/json';

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
              'generationConfig': genConfig,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (res.statusCode == 429) return null; // rate-limited, retry

      if (res.statusCode == 400 && useJsonMime) {
        // This model may not support response_mime_type — caller retries without it
        return null;
      }

      if (res.statusCode != 200) {
        String msg;
        try {
          msg = (jsonDecode(res.body) as Map)['error']?['message'] as String? ??
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
        // Check for safety block
        final reason = decoded['candidates']?[0]?['finishReason'] as String?;
        return GeminiResult(
            error: reason == 'SAFETY'
                ? 'Blocked by Gemini safety filter'
                : 'Empty response');
      }

      return _parse(text.trim());
    } on Exception catch (e) {
      return GeminiResult(error: 'Network error: $e');
    }
  }

  GeminiResult _parse(String text) {
    // Strip markdown fences
    final clean = text
        .replaceAll(RegExp(r'```json\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'```\s*'), '')
        .trim();

    Map<String, dynamic>? json;

    // 1. Direct parse
    try {
      json = jsonDecode(clean) as Map<String, dynamic>;
    } catch (_) {}

    // 2. Find first {...} in the text
    if (json == null) {
      final match = RegExp(r'\{[^{}]+\}').firstMatch(clean);
      if (match != null) {
        try {
          json = jsonDecode(match.group(0)!) as Map<String, dynamic>;
        } catch (_) {}
      }
    }

    // 3. Regex extract individual numbers
    if (json == null) {
      final cvMatch =
          RegExp(r'"currentValue"\s*:\s*([\d.]+)').firstMatch(clean);
      final rpMatch =
          RegExp(r'"returnPercent"\s*:\s*(-?[\d.]+)').firstMatch(clean);
      if (cvMatch != null) {
        json = {
          'currentValue': double.tryParse(cvMatch.group(1)!),
          'returnPercent': rpMatch != null
              ? double.tryParse(rpMatch.group(1)!)
              : null,
        };
      }
    }

    if (json == null) {
      return GeminiResult(error: 'Could not parse: $clean');
    }

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
