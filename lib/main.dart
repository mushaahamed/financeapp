import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'data/services/background_service.dart';
import 'providers/providers.dart';
import 'presentation/screens/onboarding/onboarding_screen.dart';
import 'presentation/screens/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  await BackgroundService.initialize();

  runApp(const ProviderScope(child: PaisaApp()));
}

class PaisaApp extends ConsumerWidget {
  const PaisaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Paisa',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const _AppEntry(),
    );
  }
}

class _AppEntry extends ConsumerWidget {
  const _AppEntry();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);

    return settingsAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Startup error: $e')),
      ),
      data: (settings) {
        if (settings == null) {
          return const OnboardingScreen();
        }

        // First launch after onboarding: schedule background job if enabled
        if (settings.autoUpdateEnabled) {
          BackgroundService.scheduleWeeklyUpdate();
        }

        return const MainShell();
      },
    );
  }
}
