import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/auth_state.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/settings_provider.dart';
import 'captcha_dialog.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
  final _uidController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final creds = await ref.read(cookieServiceProvider).getSavedCredentials();
    if (creds != null && mounted) {
      if (_uidController.text.isEmpty) {
        _uidController.text = creds.uid;
      }
    }
  }

  @override
  void dispose() {
    _uidController.dispose();
    _passwordController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    final uid = _uidController.text.trim();
    final pass = _passwordController.text.trim();
    if (uid.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both student UID and password.')),
      );
      return;
    }
    ref.read(authProvider.notifier).login(uid: uid, password: pass);
  }

  void _showGatewayConfigSheet() {
    final settings = ref.read(settingsProvider);
    final urlCtrl = TextEditingController(text: settings.ssoGatewayUrl);
    final tokenCtrl = TextEditingController(text: settings.ssoApiToken.isEmpty ? 'dont_use_please' : settings.ssoApiToken);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'SSO Gateway Configuration',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Customize the serverless gateway endpoint and bearer token.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: urlCtrl,
              decoration: InputDecoration(
                labelText: 'Gateway Endpoint URL',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: tokenCtrl,
              decoration: InputDecoration(
                labelText: 'Bearer Authorization Token',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                ref.read(settingsProvider.notifier).updateSsoGatewayUrl(urlCtrl.text.trim());
                ref.read(settingsProvider.notifier).updateSsoApiToken(tokenCtrl.text.trim());
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Gateway configuration saved')),
                );
              },
              child: const Text('Save Settings'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isProcessing = authState.status == AuthStatus.connectingGateway ||
        authState.status == AuthStatus.loggingInMoodle;

    // Show Captcha Dialog when manual verification is needed
    if (authState.status == AuthStatus.captchaRequired && authState.pendingCaptcha != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => CaptchaDialog(
            captchaImageBase64: authState.pendingCaptcha?.captchaImage,
            onSubmit: (captchaText) {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).submitCaptcha(
                    uid: _uidController.text.trim(),
                    password: _passwordController.text.trim(),
                    captcha: captchaText,
                  );
            },
            onCancel: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).cancelCaptcha();
            },
          ),
        );
      });
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Emblem & Branding
                  Center(
                    child: Container(
                      height: 76,
                      width: 76,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Image.asset(
                        'assets/images/app_icon_red_glyph.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.school_rounded,
                          color: theme.primaryColor,
                          size: 38,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'CUIMS Portal',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Student Learning Management & Resource Hub',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Main Form Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // UID Input
                          TextField(
                            controller: _uidController,
                            enabled: !isProcessing,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'University UID',
                              hintText: 'Enter your UID',
                              prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Password Input
                          TextField(
                            controller: _passwordController,
                            enabled: !isProcessing,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _handleLogin(),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Error Message banner
                          if (authState.status == AuthStatus.error && authState.errorMessage != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.red.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      authState.errorMessage!,
                                      style: const TextStyle(color: Colors.red, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Loading Delay State Indicator (Step 2.2 in Technical Plan)
                          if (isProcessing) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: theme.primaryColor.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: theme.primaryColor.withOpacity(0.2)),
                              ),
                              child: Column(
                                children: [
                                  const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2.5),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    authState.statusMessage ?? 'Connecting to Cloud SSO Gateway...',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: theme.primaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Accommodating university gateway delay (~5s)',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Login Submit Button
                          FilledButton(
                            onPressed: isProcessing ? null : _handleLogin,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              child: isProcessing
                                  ? const Row(
                                      key: ValueKey('auth_loading'),
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        ),
                                        SizedBox(width: 10),
                                        Text(
                                          'Authorizing...',
                                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    )
                                  : const Text(
                                      'Sign In with SSO',
                                      key: ValueKey('auth_idle'),
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Bottom Utilities
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: _showGatewayConfigSheet,
                        icon: const Icon(Icons.settings_ethernet_rounded, size: 16),
                        label: const Text('Gateway Config', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          foregroundColor: isDark ? Colors.white70 : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
