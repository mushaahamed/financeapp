import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../../core/constants.dart';
import '../../../data/models/user_settings_model.dart';
import '../../../data/services/background_service.dart';
import '../../../providers/providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _cashCtrl = TextEditingController();
  final _apiKeyCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  bool _showApiKey = false;
  bool _saving = false;
  bool _initialized = false;

  static const _weekDays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday'
  ];

  @override
  void dispose() {
    _cashCtrl.dispose();
    _apiKeyCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  void _initControllers(UserSettings s, String? key) {
    if (_initialized) return;
    _cashCtrl.text = s.currentCash.toStringAsFixed(2);
    _apiKeyCtrl.text = key ?? '';
    _modelCtrl.text = s.geminiModel;
    _initialized = true;
  }

  Future<void> _save(UserSettings current) async {
    setState(() => _saving = true);
    try {
      final cash = double.tryParse(_cashCtrl.text.trim());
      if (cash != null) {
        final updated = current.copyWith(
          currentCash: cash,
          geminiModel: _modelCtrl.text.trim().isEmpty
              ? kGeminiDefaultModel
              : _modelCtrl.text.trim(),
        );
        await ref.read(settingsProvider.notifier).saveSettings(updated);
      }

      final key = _apiKeyCtrl.text.trim();
      if (key.isEmpty) {
        await ref.read(settingsRepoProvider).clearGeminiApiKey();
      } else {
        await ref.read(settingsRepoProvider).saveGeminiApiKey(key);
      }
      ref.invalidate(geminiApiKeyProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved')),
        );
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);
    final apiKeyAsync = ref.watch(geminiApiKeyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (settings) {
          if (settings == null) return const SizedBox();

          return apiKeyAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (_, __) => const SizedBox(),
            data: (apiKey) {
              _initControllers(settings, apiKey);
              return ListView(
                padding:
                    const EdgeInsets.fromLTRB(kPad, kPad, kPad, 40),
                children: [
                  // ── General ──
                  _sectionHeader('GENERAL'),
                  const Gap(8),
                  _card(children: [
                    _fieldLabel('Current Cash'),
                    const Gap(6),
                    TextFormField(
                      controller: _cashCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                              decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*'))
                      ],
                      decoration: const InputDecoration(
                          prefixText: '₹  ', hintText: '0.00'),
                    ),
                    const Gap(12),
                    _fieldLabel('Default Currency'),
                    const Gap(6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: kBackground,
                        borderRadius: BorderRadius.circular(kRadius),
                        border: Border.all(color: kDivider),
                      ),
                      child: const Row(
                        children: [
                          Text('₹  INR',
                              style: TextStyle(fontSize: 14)),
                          Spacer(),
                          Text('Indian Rupee',
                              style: TextStyle(
                                  color: kTextSecondary, fontSize: 13)),
                        ],
                      ),
                    ),
                  ]),

                  const Gap(20),

                  // ── Gemini ──
                  _sectionHeader('GEMINI AI (PRICE UPDATES)'),
                  const Gap(8),
                  _card(children: [
                    _fieldLabel('API Key'),
                    const Gap(6),
                    TextFormField(
                      controller: _apiKeyCtrl,
                      obscureText: !_showApiKey,
                      decoration: InputDecoration(
                        hintText: 'AIza...',
                        suffixIcon: IconButton(
                          icon: Icon(_showApiKey
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined),
                          onPressed: () => setState(
                              () => _showApiKey = !_showApiKey),
                          color: kTextSecondary,
                        ),
                      ),
                    ),
                    const Gap(6),
                    const Row(
                      children: [
                        Icon(Icons.lock_outline,
                            size: 12, color: kTextSecondary),
                        Gap(4),
                        Text(
                          'Stored encrypted on-device.',
                          style: TextStyle(
                              fontSize: 11, color: kTextSecondary),
                        ),
                      ],
                    ),
                    const Gap(12),
                    _fieldLabel('Model'),
                    const Gap(6),
                    TextFormField(
                      controller: _modelCtrl,
                      decoration: InputDecoration(
                        hintText: kGeminiDefaultModel,
                        helperText: 'e.g. gemini-2.0-flash',
                      ),
                    ),
                  ]),

                  const Gap(20),

                  // ── Auto update ──
                  _sectionHeader('AUTO PRICE UPDATE'),
                  const Gap(8),
                  _card(children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Enable weekly auto-update',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500)),
                      subtitle: const Text(
                          'Updates all asset prices once a week.',
                          style: TextStyle(
                              fontSize: 12, color: kTextSecondary)),
                      value: settings.autoUpdateEnabled,
                      activeColor: kPrimary,
                      onChanged: (v) async {
                        final updated = settings.copyWith(
                            autoUpdateEnabled: v);
                        await ref
                            .read(settingsProvider.notifier)
                            .saveSettings(updated);
                        if (v) {
                          await BackgroundService.scheduleWeeklyUpdate();
                        } else {
                          await BackgroundService.cancelWeeklyUpdate();
                        }
                      },
                    ),
                    if (settings.autoUpdateEnabled) ...[
                      const Divider(),
                      const Gap(8),
                      _fieldLabel('Day of week'),
                      const Gap(6),
                      DropdownButtonFormField<int>(
                        value: settings.weeklyUpdateDay,
                        decoration: const InputDecoration(),
                        items: List.generate(
                          7,
                          (i) => DropdownMenuItem(
                              value: i, child: Text(_weekDays[i])),
                        ),
                        onChanged: (v) async {
                          if (v == null) return;
                          final updated =
                              settings.copyWith(weeklyUpdateDay: v);
                          await ref
                              .read(settingsProvider.notifier)
                              .saveSettings(updated);
                        },
                      ),
                      const Gap(10),
                      _fieldLabel('Approximate time'),
                      const Gap(6),
                      GestureDetector(
                        onTap: () => _pickTime(context, settings),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                          decoration: BoxDecoration(
                            color: kBackground,
                            borderRadius:
                                BorderRadius.circular(kRadius),
                            border: Border.all(color: kDivider),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time_outlined,
                                  size: 16, color: kTextSecondary),
                              const Gap(10),
                              Text(settings.weeklyUpdateTime,
                                  style:
                                      const TextStyle(fontSize: 14)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ]),

                  const Gap(28),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving
                          ? null
                          : () => _save(settings),
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text('Save Settings'),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _pickTime(BuildContext ctx, UserSettings s) async {
    final parts = s.weeklyUpdateTime.split(':');
    final initial = TimeOfDay(
        hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    final picked = await showTimePicker(
        context: ctx, initialTime: initial);
    if (picked != null) {
      final hh = picked.hour.toString().padLeft(2, '0');
      final mm = picked.minute.toString().padLeft(2, '0');
      final updated = s.copyWith(weeklyUpdateTime: '$hh:$mm');
      await ref.read(settingsProvider.notifier).saveSettings(updated);
    }
  }

  Widget _sectionHeader(String title) => Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: kTextSecondary,
          letterSpacing: 0.5,
        ),
      );

  Widget _fieldLabel(String label) => Text(
        label,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: kTextPrimary),
      );

  Widget _card({required List<Widget> children}) => Container(
        padding: const EdgeInsets.all(kPad),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(kRadiusLg),
          border: Border.all(color: kDivider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      );
}
