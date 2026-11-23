import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/models/app_settings.dart';
import '../../../../providers/app_providers.dart';
import '../../../../providers/settings_provider.dart';
import 'ai_prompt_editor_screen.dart';

class ExportSettingsScreen extends ConsumerWidget {
  const ExportSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Export & AI Tools'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // Switch Settings: Title, description, switch
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF8B5CF6), size: 22),
                  title: const Text(
                    'Study with AI Option',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Show the "Study with AI" shortcut icon on course units to generate study prompts for Gemini / ChatGPT.',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: settings.enableLearnWithAi,
                  onChanged: (val) => settingsNotifier.updateEnableLearnWithAi(val),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.archive_outlined, size: 22),
                  title: const Text(
                    'Auto-Share Exported Materials',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Instantly open the system share sheet when materials finish exporting.',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: settings.autoShareExportedZip,
                  onChanged: (val) => settingsNotifier.updateAutoShareExportedZip(val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: const Icon(Icons.psychology_alt_rounded, color: Color(0xFF8B5CF6), size: 24),
              title: const Text(
                'AI Study System Prompt',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              subtitle: const Text(
                'Customize prompt template and dynamic variables for Learn with AI',
                style: TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AiPromptEditorScreen()),
                );
              },
            ),
          ),
          const SizedBox(height: 14),

          // Non-switch setting: simplified title, no verbose description, segmented button at bottom of title
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Default Export Format',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<MaterialExportFormat>(
                      segments: const [
                        ButtonSegment(
                          value: MaterialExportFormat.zip,
                          icon: Icon(Icons.folder_zip_rounded, size: 16),
                          label: Text('ZIP (.zip)', style: TextStyle(fontSize: 12)),
                        ),
                        ButtonSegment(
                          value: MaterialExportFormat.folder,
                          icon: Icon(Icons.folder_open_rounded, size: 16),
                          label: Text('Folder', style: TextStyle(fontSize: 12)),
                        ),
                        ButtonSegment(
                          value: MaterialExportFormat.pdf24,
                          icon: Icon(Icons.picture_as_pdf_rounded, size: 16),
                          label: Text('Merged PDF', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                      selected: {settings.exportFormat},
                      onSelectionChanged: (newSelection) {
                        settingsNotifier.updateExportFormat(newSelection.first);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // PDF24 Service Quota & Rate Limit Information Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: FutureBuilder<List<dynamic>>(
                future: Future.wait([
                  ref.read(pdf24ServiceProvider).getRemainingQuota(),
                  ref.read(pdf24ServiceProvider).getRecentUploadCount(),
                  ref.read(pdf24ServiceProvider).getTimeUntilReset(),
                ]),
                builder: (context, snapshot) {
                  final quota = snapshot.data != null ? (snapshot.data![0] as int) : 10;
                  final used = snapshot.data != null ? (snapshot.data![1] as int) : 0;
                  final resetDuration = snapshot.data != null ? (snapshot.data![2] as Duration?) : null;
                  final isDark = Theme.of(context).brightness == Brightness.dark;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.speed_rounded,
                            size: 20,
                            color: quota <= 2 ? Colors.orange : const Color(0xFFE53935),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'PDF24 Quota & Rate Limit',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: (quota <= 2 ? Colors.orange : Colors.green).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: (quota <= 2 ? Colors.orange : Colors.green).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              '$quota/10 files remaining',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: quota <= 2 ? Colors.orange : Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Uploads for merged PDFs are rate-limited to 10 files per rolling 2-hour window to prevent abusing the external service ($used/10 used).',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      if (resetDuration != null && resetDuration > Duration.zero) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Next quota slot unlocks in ~${resetDuration.inMinutes + 1} minutes.',
                          style: TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
