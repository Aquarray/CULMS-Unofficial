import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/tts_service.dart';
import '../../../../providers/settings_provider.dart';

class VoiceSettingsScreen extends ConsumerWidget {
  const VoiceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice & Audio'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Reading Speed
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Reading Speed',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      Text(
                        '${(settings.ttsSpeechRate * 2.0).toStringAsFixed(2)}x',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Slider(
                    value: settings.ttsSpeechRate,
                    min: 0.25,
                    max: 1.0,
                    divisions: 6,
                    label: '${(settings.ttsSpeechRate * 2.0).toStringAsFixed(1)}x',
                    onChanged: (val) => settingsNotifier.updateTtsSpeechRate(val),
                  ),
                  const Divider(height: 24),

                  // Voice Pitch
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Voice Pitch',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      Text(
                        settings.ttsPitch.toStringAsFixed(1),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Slider(
                    value: settings.ttsPitch,
                    min: 0.5,
                    max: 1.5,
                    divisions: 10,
                    onChanged: (val) => settingsNotifier.updateTtsPitch(val),
                  ),
                  const Divider(height: 24),

                  // Language
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Voice Language',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      DropdownButton<String>(
                        value: settings.ttsLanguage,
                        underline: const SizedBox(),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'en-US', child: Text('English (US)')),
                          DropdownMenuItem(value: 'en-IN', child: Text('English (India)')),
                          DropdownMenuItem(value: 'en-GB', child: Text('English (UK)')),
                          DropdownMenuItem(value: 'hi-IN', child: Text('Hindi (India)')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            settingsNotifier.updateTtsLanguage(val);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Test Sample Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.volume_up_rounded, size: 18),
                      label: const Text('Test Voice Sample'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        ref.read(ttsProvider.notifier).testVoice(
                          rate: settings.ttsSpeechRate,
                          pitch: settings.ttsPitch,
                          volume: settings.ttsVolume,
                          language: settings.ttsLanguage,
                        );
                      },
                    ),
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
