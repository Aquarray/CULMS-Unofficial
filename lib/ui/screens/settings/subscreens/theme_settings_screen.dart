import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/models/app_settings.dart';
import '../../../../providers/settings_provider.dart';

class ThemeSettingsScreen extends ConsumerWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Theme & Appearance'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // Theme Mode
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Theme',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _ThemeOptionTile(
                        icon: settings.themeMode == AppThemeMode.system
                            ? Icons.brightness_auto_rounded
                            : Icons.brightness_auto_outlined,
                        label: 'System',
                        isSelected: settings.themeMode == AppThemeMode.system,
                        onTap: () => settingsNotifier.updateThemeMode(AppThemeMode.system),
                      ),
                      const SizedBox(width: 8),
                      _ThemeOptionTile(
                        icon: settings.themeMode == AppThemeMode.light
                            ? Icons.light_mode_rounded
                            : Icons.light_mode_outlined,
                        label: 'Light',
                        isSelected: settings.themeMode == AppThemeMode.light,
                        onTap: () => settingsNotifier.updateThemeMode(AppThemeMode.light),
                      ),
                      const SizedBox(width: 8),
                      _ThemeOptionTile(
                        icon: settings.themeMode == AppThemeMode.dark
                            ? Icons.dark_mode_rounded
                            : Icons.dark_mode_outlined,
                        label: 'Dark',
                        isSelected: settings.themeMode == AppThemeMode.dark,
                        onTap: () => settingsNotifier.updateThemeMode(AppThemeMode.dark),
                      ),
                      const SizedBox(width: 8),
                      _ThemeOptionTile(
                        icon: settings.themeMode == AppThemeMode.amoled
                            ? Icons.contrast_rounded
                            : Icons.contrast_outlined,
                        label: 'AMOLED',
                        isSelected: settings.themeMode == AppThemeMode.amoled,
                        onTap: () => settingsNotifier.updateThemeMode(AppThemeMode.amoled),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Accent Color
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Accent Color',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: settings.accentColor.resolve(isDark).withValues(alpha: isDark ? 0.22 : 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: settings.accentColor.resolve(isDark).withValues(alpha: 0.4),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          settings.accentColor.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : settings.accentColor.resolve(isDark),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: AppAccentColor.values.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 2.3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemBuilder: (context, index) {
                      final item = AppAccentColor.values[index];
                      return _AccentColorTile(
                        accent: item,
                        isSelected: settings.accentColor == item,
                        onTap: () => settingsNotifier.updateAccentColor(item),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeOptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOptionTile({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.22 : 0.12)
                : (isDark ? const Color(0xFF14171A) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : (isDark ? const Color(0xFF2A2E35) : const Color(0xFFE2E8F0)),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? theme.colorScheme.primary
                    : (isDark ? Colors.white70 : const Color(0xFF64748B)),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : (isDark ? Colors.white70 : const Color(0xFF475569)),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccentColorTile extends StatelessWidget {
  final AppAccentColor accent;
  final bool isSelected;
  final VoidCallback onTap;

  const _AccentColorTile({
    required this.accent,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveColor = accent.resolve(isDark);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? effectiveColor.withValues(alpha: isDark ? 0.22 : 0.09)
                : (isDark ? const Color(0xFF161615) : const Color(0xFFF7F6F2)),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: isSelected
                  ? effectiveColor
                  : (isDark ? const Color(0xFF2C2C28) : const Color(0xFFE5E3DC)),
              width: isSelected ? 1.6 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: effectiveColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: effectiveColor.withValues(alpha: 0.35),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  accent.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
