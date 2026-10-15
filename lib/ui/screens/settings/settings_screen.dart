import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_provider.dart';
import 'debug_logs_screen.dart';
import 'subscreens/alarm_settings_screen.dart';
import 'subscreens/cache_settings_screen.dart';
import 'subscreens/export_settings_screen.dart';
import 'subscreens/gateway_settings_screen.dart';
import 'subscreens/quiz_ai_settings_screen.dart';
import 'subscreens/theme_settings_screen.dart';
import 'subscreens/typography_settings_screen.dart';
import 'subscreens/voice_settings_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _navigate(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _SettingsCategoryTile(
                  icon: Icons.palette_outlined,
                  iconColor: const Color(0xFF6366F1),
                  title: 'Theme & Appearance',
                  subtitle: 'Theme mode and accent color',
                  onTap: () => _navigate(context, const ThemeSettingsScreen()),
                ),
                const Divider(height: 1, indent: 56),
                _SettingsCategoryTile(
                  icon: Icons.text_fields_outlined,
                  iconColor: const Color(0xFF0EA5E9),
                  title: 'Typography & Reading',
                  subtitle: 'Fonts, reading themes, and text size',
                  onTap: () => _navigate(context, const TypographySettingsScreen()),
                ),
                const Divider(height: 1, indent: 56),
                _SettingsCategoryTile(
                  icon: Icons.record_voice_over_outlined,
                  iconColor: const Color(0xFF10B981),
                  title: 'Voice & Audio',
                  subtitle: 'Read-aloud speed, pitch, and voice',
                  onTap: () => _navigate(context, const VoiceSettingsScreen()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _SettingsCategoryTile(
                  icon: Icons.cached_outlined,
                  iconColor: const Color(0xFFF59E0B),
                  title: 'Offline Cache & Storage',
                  subtitle: 'Offline content caching and local storage',
                  onTap: () => _navigate(context, const CacheSettingsScreen()),
                ),
                const Divider(height: 1, indent: 56),
                _SettingsCategoryTile(
                  icon: Icons.vpn_lock_outlined,
                  iconColor: const Color(0xFF8B5CF6),
                  title: 'Gateway & Proxy',
                  subtitle: 'SSO portal server endpoint and token',
                  onTap: () => _navigate(context, const GatewaySettingsScreen()),
                ),
                const Divider(height: 1, indent: 56),
                _SettingsCategoryTile(
                  icon: Icons.alarm_outlined,
                  iconColor: const Color(0xFFEC4899),
                  title: 'Reminders & Alarms',
                  subtitle: 'Quiz and assignment deadline notifications',
                  onTap: () => _navigate(context, const AlarmSettingsScreen()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _SettingsCategoryTile(
                  icon: Icons.auto_awesome_outlined,
                  iconColor: const Color(0xFF8B5CF6),
                  title: 'Export & AI Tools',
                  subtitle: 'Default export format and study guides',
                  onTap: () => _navigate(context, const ExportSettingsScreen()),
                ),
                const Divider(height: 1, indent: 56),
                _SettingsCategoryTile(
                  icon: Icons.psychology_outlined,
                  iconColor: const Color(0xFF3B82F6),
                  title: 'Quiz AI Assistant',
                  subtitle: 'In-browser assistance, API keys, and models',
                  onTap: () => _navigate(context, const QuizAiSettingsScreen()),
                ),
                const Divider(height: 1, indent: 56),
                _SettingsCategoryTile(
                  icon: Icons.terminal_outlined,
                  iconColor: const Color(0xFF64748B),
                  title: 'Diagnostics & Logs',
                  subtitle: 'Live network traces and debug console',
                  onTap: () => _navigate(context, const DebugLogsScreen()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // User Account Information & Logout
          if (authState.isAuthenticated) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person_outline_rounded,
                        color: theme.colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            authState.session?.studentName ?? 'Student User',
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            authState.session?.uid.toUpperCase() ?? '',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.logout_rounded, size: 18, color: Colors.red),
                      label: const Text(
                        'Sign Out',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Sign Out'),
                            content: const Text('Are you sure you want to sign out from CUIMS?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  ref.read(authProvider.notifier).logout();
                                },
                                child: const Text('Sign Out'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }
}

class _SettingsCategoryTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsCategoryTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: isDark ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.white60 : Colors.black54,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        size: 20,
        color: Colors.grey,
      ),
      onTap: onTap,
    );
  }
}
