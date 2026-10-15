import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/reading_theme.dart';
import '../../../../data/models/app_settings.dart';
import '../../../../providers/settings_provider.dart';

class TypographySettingsScreen extends ConsumerWidget {
  const TypographySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Typography & Reading'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // Font Family
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Font',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Inter'),
                        selected: settings.fontFamily == AppFontFamily.inter,
                        onSelected: (_) => settingsNotifier.updateFontFamily(AppFontFamily.inter),
                      ),
                      ChoiceChip(
                        label: const Text('Plus Jakarta'),
                        selected: settings.fontFamily == AppFontFamily.plusJakarta,
                        onSelected: (_) => settingsNotifier.updateFontFamily(AppFontFamily.plusJakarta),
                      ),
                      ChoiceChip(
                        label: const Text('Roboto'),
                        selected: settings.fontFamily == AppFontFamily.roboto,
                        onSelected: (_) => settingsNotifier.updateFontFamily(AppFontFamily.roboto),
                      ),
                      ChoiceChip(
                        label: const Text('Literata'),
                        selected: settings.fontFamily == AppFontFamily.literata,
                        onSelected: (_) => settingsNotifier.updateFontFamily(AppFontFamily.literata),
                      ),
                      ChoiceChip(
                        label: const Text('System Sans'),
                        selected: settings.fontFamily == AppFontFamily.systemSans,
                        onSelected: (_) => settingsNotifier.updateFontFamily(AppFontFamily.systemSans),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Reading Theme / Contrast Palette
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reading Theme',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ReaderContrast.values.map((contrast) {
                      final isSelected = settings.readerContrast == contrast;
                      final config = ReadingThemeConfig.getTheme(contrast);
                      String label = '';
                      switch (contrast) {
                        case ReaderContrast.cleanLight:
                          label = 'Clean Light';
                          break;
                        case ReaderContrast.mediumSepia:
                          label = 'Medium Sepia';
                          break;
                        case ReaderContrast.softDark:
                          label = 'Soft Dark';
                          break;
                        case ReaderContrast.oledBlack:
                          label = 'OLED Black';
                          break;
                        case ReaderContrast.forestMist:
                          label = 'Forest';
                          break;
                      }

                      return ActionChip(
                        avatar: CircleAvatar(radius: 6, backgroundColor: config.textColor),
                        label: Text(label),
                        backgroundColor: isSelected ? theme.primaryColor.withValues(alpha: 0.15) : null,
                        side: BorderSide(
                          color: isSelected ? theme.primaryColor : Colors.grey.withValues(alpha: 0.3),
                        ),
                        onPressed: () => settingsNotifier.updateReaderContrast(contrast),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Text Size
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
                        'Text Size',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      Text(
                        '${(settings.fontScale * 100).toInt()}%',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    value: settings.fontScale,
                    min: 0.85,
                    max: 1.35,
                    divisions: 5,
                    onChanged: (val) => settingsNotifier.updateFontScale(val),
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
