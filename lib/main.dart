import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'data/models/app_settings.dart';
import 'providers/app_providers.dart';
import 'providers/auth_provider.dart';
import 'providers/settings_provider.dart';
import 'ui/screens/auth/login_screen.dart';
import 'ui/screens/home_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: CuimsApp(),
    ),
  );
}

class CuimsApp extends ConsumerStatefulWidget {
  const CuimsApp({super.key});

  @override
  ConsumerState<CuimsApp> createState() => _CuimsAppState();
}

class _CuimsAppState extends ConsumerState<CuimsApp> {
  @override
  void initState() {
    super.initState();
    // Request notification permission at start as specified:
    // "Also, take the permission of motification at start. i willtell it's use."
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestNotificationPermission();
    });
  }

  Future<void> _requestNotificationPermission() async {
    // Initialize deadline alarm & local notification system
    try {
      await ref.read(alarmServiceProvider).initialize();
    } catch (_) {}

    final notificationService = ref.read(notificationServiceProvider);
    final hasPrompted = await notificationService.hasPromptedBefore();
    if (!hasPrompted) {
      await notificationService.requestNotificationPermission();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final authState = ref.watch(authProvider);

    ThemeMode themeMode = ThemeMode.system;
    switch (settings.themeMode) {
      case AppThemeMode.light:
        themeMode = ThemeMode.light;
        break;
      case AppThemeMode.dark:
      case AppThemeMode.amoled:
        themeMode = ThemeMode.dark;
        break;
      case AppThemeMode.system:
        themeMode = ThemeMode.system;
        break;
    }

    final isAmoled = settings.themeMode == AppThemeMode.amoled;

    return MaterialApp(
      title: 'CUIMS LMS',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.lightTheme(settings.fontFamily),
      darkTheme: AppTheme.darkTheme(settings.fontFamily, isAmoled: isAmoled),
      home: authState.isAuthenticated ? const HomeShell() : const LoginScreen(),
    );
  }
}
