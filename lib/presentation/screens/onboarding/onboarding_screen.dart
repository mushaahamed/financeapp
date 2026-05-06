import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../../core/constants.dart';
import '../../../providers/providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _cashController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _showApiKey = false;

  @override
  void dispose() {
    _cashController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _getStarted() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final cash = double.parse(_cashController.text.trim());
      await ref.read(settingsProvider.notifier).initialize(cash);

      final apiKey = _apiKeyController.text.trim();
      if (apiKey.isNotEmpty) {
        await ref.read(settingsRepoProvider).saveGeminiApiKey(apiKey);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Gap(40),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: kPrimary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.account_balance_wallet_rounded,
                      color: Colors.white, size: 28),
                ),
                const Gap(24),
                const Text(
                  'Welcome to Paisa',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const Gap(8),
                const Text(
                  'Your private, local-first finance tracker.\nNo cloud. No account. Just your data.',
                  style: TextStyle(
                    fontSize: 15,
                    color: kTextSecondary,
                    height: 1.5,
                  ),
                ),
                const Gap(40),
                _label('How much cash do you have right now?'),
                const Gap(8),
                TextFormField(
                  controller: _cashController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d*'))
                  ],
                  decoration: const InputDecoration(
                    prefixText: '₹  ',
                    hintText: '0.00',
                  ),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Enter your current cash amount';
                    }
                    final n = double.tryParse(v.trim());
                    if (n == null || n < 0) return 'Enter a valid amount';
                    return null;
                  },
                ),
                const Gap(28),
                _label('Gemini API key'),
                const Gap(4),
                const Text(
                  'Optional — needed for automatic investment price updates.',
                  style: TextStyle(fontSize: 13, color: kTextSecondary),
                ),
                const Gap(8),
                TextFormField(
                  controller: _apiKeyController,
                  obscureText: !_showApiKey,
                  decoration: InputDecoration(
                    hintText: 'AIza...',
                    suffixIcon: IconButton(
                      icon: Icon(_showApiKey
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      onPressed: () =>
                          setState(() => _showApiKey = !_showApiKey),
                      color: kTextSecondary,
                    ),
                  ),
                ),
                const Gap(8),
                Row(
                  children: [
                    const Icon(Icons.lock_outline,
                        size: 13, color: kTextSecondary),
                    const Gap(4),
                    const Text(
                      'Stored securely on-device only.',
                      style:
                          TextStyle(fontSize: 12, color: kTextSecondary),
                    ),
                  ],
                ),
                const Gap(40),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _loading ? null : _getStarted,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Get Started'),
                  ),
                ),
                const Gap(24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: kTextPrimary,
        ),
      );
}
