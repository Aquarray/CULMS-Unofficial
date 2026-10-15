import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/models/app_settings.dart';
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
                          icon: Icon(Icons.folder_zip_rounded, size: 18),
                          label: Text('ZIP Archive (.zip)'),
                        ),
                        ButtonSegment(
                          value: MaterialExportFormat.folder,
                          icon: Icon(Icons.folder_open_rounded, size: 18),
                          label: Text('Direct Folder'),
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
        ],
      ),
    );
  }
}
