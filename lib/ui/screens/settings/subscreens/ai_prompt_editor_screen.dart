import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/models/app_settings.dart';
import '../../../../providers/settings_provider.dart';

/// Screen to edit the System Prompt template used for "Learn with AI".
/// Includes autofocus on the text field and a dynamic variable suggestion bar
/// positioned directly above the soft keyboard.
class AiPromptEditorScreen extends ConsumerStatefulWidget {
  const AiPromptEditorScreen({super.key});

  @override
  ConsumerState<AiPromptEditorScreen> createState() => _AiPromptEditorScreenState();
}

class _AiPromptEditorScreenState extends ConsumerState<AiPromptEditorScreen> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _hasChanges = false;

  final List<_VariableSuggestion> _suggestions = const [
    _VariableSuggestion(
      label: 'Subject Name',
      variable: '{%subject_name%}',
      icon: Icons.school_outlined,
      description: 'Replaced with the course or subject title',
    ),
    _VariableSuggestion(
      label: 'Unit Number',
      variable: '{%unit_number%}',
      icon: Icons.tag_rounded,
      description: 'Replaced with the unit number (e.g. 1, 2)',
    ),
    _VariableSuggestion(
      label: 'Chapter Number',
      variable: '{%chapter_number%}',
      icon: Icons.menu_book_outlined,
      description: 'Replaced with chapter number (if chapter is exported)',
    ),
    _VariableSuggestion(
      label: 'Number of Items',
      variable: '{%items_count%}',
      icon: Icons.format_list_numbered_rounded,
      description: 'Replaced with total count of materials/files',
    ),
  ];

  @override
  void initState() {
    super.initState();
    final initialTemplate = ref.read(settingsProvider).aiStudyPromptTemplate;
    _controller = TextEditingController(text: initialTemplate);
    _focusNode = FocusNode();

    _controller.addListener(() {
      final currentSetting = ref.read(settingsProvider).aiStudyPromptTemplate;
      final changed = _controller.text != currentSetting;
      if (changed != _hasChanges) {
        setState(() {
          _hasChanges = changed;
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _insertVariable(String variable) {
    final text = _controller.text;
    final selection = _controller.selection;

    int start = selection.start;
    int end = selection.end;

    if (start < 0 || end < 0) {
      start = text.length;
      end = text.length;
    }

    final newText = text.replaceRange(start, end, variable);
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + variable.length),
    );

    HapticFeedback.lightImpact();
    _focusNode.requestFocus();
  }

  void _savePrompt() {
    ref.read(settingsProvider.notifier).updateAiStudyPromptTemplate(_controller.text);
    setState(() {
      _hasChanges = false;
    });
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Text('System prompt template saved!'),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _resetToDefault() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset System Prompt?'),
        content: const Text(
          'This will revert the AI study prompt template back to the default factory format.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true && mounted) {
        _controller.text = defaultAiStudyPromptTemplate;
        _savePrompt();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text(
          'AI System Prompt',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt_rounded),
            tooltip: 'Reset to Default',
            onPressed: _resetToDefault,
          ),
          TextButton.icon(
            onPressed: _hasChanges ? _savePrompt : null,
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Save'),
            style: TextButton.styleFrom(
              foregroundColor: _hasChanges ? theme.colorScheme.primary : theme.disabledColor,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Prompt Editor
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: true,
                  maxLines: null,
                  expands: true,
                  keyboardType: TextInputType.multiline,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    fontFamily: 'monospace',
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'Enter your AI study prompt template here...',
                    hintStyle: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
            ),

            // Dynamic Suggestion Bar (stays directly above the keyboard)
            Container(
              decoration: BoxDecoration(
                // color: isDark
                //     ? const Color(0xFF1E222A)
                //     : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                border: Border(
                  top: BorderSide(
                    color: theme.dividerColor.withValues(alpha: isDark ? 0.2 : 0.1),
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: _suggestions.map((suggestion) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ActionChip(
                            avatar: Icon(
                              suggestion.icon,
                              size: 14,
                              color: theme.colorScheme.primary,
                            ),
                            label: Text(
                              suggestion.label,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            tooltip: '${suggestion.variable}\n${suggestion.description}',
                            backgroundColor: isDark
                                ? const Color(0xFF282E39)
                                : theme.colorScheme.surface,
                            side: BorderSide(
                              color: theme.colorScheme.primary.withValues(alpha: 0.25),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            onPressed: () => _insertVariable(suggestion.variable),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _VariableSuggestion {
  final String label;
  final String variable;
  final IconData icon;
  final String description;

  const _VariableSuggestion({
    required this.label,
    required this.variable,
    required this.icon,
    required this.description,
  });
}
