import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/quiz_ai_service.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/theme/reading_theme.dart';
import '../../../data/models/app_settings.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/dashboard_provider.dart';
import '../../../providers/settings_provider.dart';
import 'debug_logs_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  double _cacheSizeMb = 0.0;
  bool _isLoadingCacheSize = false;
  bool _isLoadingModels = false;

  @override
  void initState() {
    super.initState();
    _refreshCacheSize();
  }

  Future<void> _refreshCacheSize() async {
    setState(() => _isLoadingCacheSize = true);
    final cacheService = ref.read(cacheServiceProvider);
    final size = await cacheService.getCacheSizeMb();
    if (mounted) {
      setState(() {
        _cacheSizeMb = size;
        _isLoadingCacheSize = false;
      });
    }
  }

  Future<void> _clearCache() async {
    final cacheService = ref.read(cacheServiceProvider);
    await cacheService.clearCache();
    await _refreshCacheSize();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offline cache cleared successfully')),
      );
    }
  }

  void _showGatewayEditDialog() {
    final settings = ref.read(settingsProvider);
    final urlCtrl = TextEditingController(text: settings.ssoGatewayUrl);
    final tokenCtrl = TextEditingController(text: settings.ssoApiToken.isEmpty ? 'dont_use_please' : settings.ssoApiToken);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('SSO Gateway Settings', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlCtrl,
              decoration: const InputDecoration(
                labelText: 'Gateway Endpoint URL',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: tokenCtrl,
              decoration: const InputDecoration(
                labelText: 'Bearer Authorization Token',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(settingsProvider.notifier).updateSsoGatewayUrl(urlCtrl.text.trim());
              ref.read(settingsProvider.notifier).updateSsoApiToken(tokenCtrl.text.trim());
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Gateway configuration saved')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showQuizApiKeyDialog() {
    final settings = ref.read(settingsProvider);
    final keyCtrl = TextEditingController(text: settings.quizAiApiKey);
    bool obscure = true;
    bool isSaving = false;
    String? errorMessage;
    final isGemini = settings.quizAiProvider == QuizAiProvider.gemini;
    final providerName = isGemini ? 'Google Gemini' : 'OpenAI';
    final hintText = isGemini ? 'AIzaSy...' : 'sk-...';
    final linkText = isGemini ? 'Get a free key from Google AI Studio' : 'Get a key from OpenAI Platform';
    final linkUrl = isGemini ? 'https://aistudio.google.com/app/apikey' : 'https://platform.openai.com/api-keys';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final theme = Theme.of(context);
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isGemini ? const Color(0xFF6366F1) : const Color(0xFF10A37F))
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isGemini ? Icons.auto_awesome : Icons.psychology_rounded,
                    color: isGemini ? const Color(0xFF6366F1) : const Color(0xFF10A37F),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '$providerName Key',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: keyCtrl,
                    obscureText: obscure,
                    autofocus: settings.quizAiApiKey.isEmpty,
                    decoration: InputDecoration(
                      labelText: '$providerName API Key',
                      hintText: hintText,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.key_rounded, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          size: 20,
                        ),
                        onPressed: () => setDlgState(() => obscure = !obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: theme.colorScheme.primary,
                      ),
                      icon: const Icon(Icons.open_in_new_rounded, size: 13),
                      label: Text(
                        linkText,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      onPressed: () => launchUrl(Uri.parse(linkUrl), mode: LaunchMode.externalApplication),
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 16, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              errorMessage!,
                              style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                icon: isSaving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_rounded, size: 18),
                label: Text(isSaving ? 'Verifying...' : 'Save & Connect'),
                onPressed: isSaving
                    ? null
                    : () async {
                        final key = keyCtrl.text.trim();
                        if (key.isEmpty) {
                          ref.read(settingsProvider.notifier).updateQuizAiApiKey('');
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('API Key cleared')),
                          );
                          return;
                        }

                        setDlgState(() {
                          isSaving = true;
                          errorMessage = null;
                        });

                        final result = await ref
                            .read(quizAiServiceProvider)
                            .fetchAvailableModels(
                              provider: settings.quizAiProvider,
                              apiKey: key,
                            );

                        if (!result.isSuccess) {
                          setDlgState(() {
                            isSaving = false;
                            errorMessage = result.errorMessage ?? 'Connection failed. Check API key.';
                          });
                          return;
                        }

                        ref.read(settingsProvider.notifier).updateQuizAiApiKey(key);
                        if (result.models.isNotEmpty) {
                          final currentModel = settings.quizAiModel;
                          if (currentModel.isEmpty || !result.models.any((m) => m.id == currentModel)) {
                            ref.read(settingsProvider.notifier).updateQuizAiModel(result.models.first.id);
                          }
                        }

                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Connected to $providerName! ${result.models.length} models available.',
                                    ),
                                  ),
                                ],
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showModelSelectionSheet() async {
    final settings = ref.read(settingsProvider);
    final provider = settings.quizAiProvider;
    final apiKey = settings.quizAiApiKey.trim();

    setState(() => _isLoadingModels = true);
    List<AiModelInfo> models = [];

    if (apiKey.isNotEmpty) {
      final res = await ref.read(quizAiServiceProvider).fetchAvailableModels(
            provider: provider,
            apiKey: apiKey,
          );
      if (res.isSuccess && res.models.isNotEmpty) {
        models = res.models;
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res.errorMessage ?? 'Could not fetch live models. Using defaults.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        models = provider == QuizAiProvider.gemini
            ? QuizAiService.defaultGeminiModels
            : QuizAiService.defaultOpenAiModels;
      }
    } else {
      models = provider == QuizAiProvider.gemini
          ? QuizAiService.defaultGeminiModels
          : QuizAiService.defaultOpenAiModels;
    }

    if (mounted) {
      setState(() => _isLoadingModels = false);
    }

    if (!mounted) return;

    final currentModelId = settings.quizAiModel.isNotEmpty
        ? settings.quizAiModel
        : (provider == QuizAiProvider.gemini ? 'gemini-1.5-flash' : 'gpt-4o-mini');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          expand: false,
          builder: (ctx, scrollController) {
            final isGemini = provider == QuizAiProvider.gemini;
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        isGemini ? Icons.auto_awesome : Icons.psychology_rounded,
                        color: isGemini ? const Color(0xFF6366F1) : const Color(0xFF10A37F),
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select ${isGemini ? "Google Gemini" : "OpenAI"} Model',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              apiKey.isNotEmpty
                                  ? 'Live results from ${isGemini ? "Gemini listModels" : "OpenAI models"} endpoint'
                                  : 'Default models (add API key to fetch all live models)',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: models.length,
                    itemBuilder: (ctx, i) {
                      final m = models[i];
                      final isSelected = m.id == currentModelId;
                      return ListTile(
                        leading: Icon(
                          isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                          color: isSelected ? const Color(0xFF6366F1) : Colors.grey,
                        ),
                        title: Text(
                          m.displayName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? const Color(0xFF6366F1) : null,
                          ),
                        ),
                        subtitle: m.description != null && m.description!.isNotEmpty
                            ? Text(
                                m.description!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11),
                              )
                            : Text(m.id, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        onTap: () {
                          ref.read(settingsProvider.notifier).updateQuizAiModel(m.id);
                          Navigator.pop(sheetCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Active model set to ${m.displayName}'),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          _testModelResponseDialog(
                            modelId: m.id,
                            modelDisplayName: m.displayName,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _testModelResponseDialog({
    required String modelId,
    required String modelDisplayName,
  }) async {
    final settings = ref.read(settingsProvider);
    final provider = settings.quizAiProvider;
    final apiKey = settings.quizAiApiKey.trim();

    if (apiKey.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('API Key Required'),
          content: Text(
            'Please configure your ${provider == QuizAiProvider.gemini ? "Gemini" : "OpenAI"} API Key first to test model responses.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _showQuizApiKeyDialog();
              },
              child: const Text('Enter API Key'),
            ),
          ],
        ),
      );
      return;
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => _ModelTestDialog(
        provider: provider,
        apiKey: apiKey,
        modelId: modelId,
        modelDisplayName: modelDisplayName,
        quizAiService: ref.read(quizAiServiceProvider),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final authState = ref.watch(authProvider);

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Customization'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Section: Appearance & Themes
          _SectionHeader(title: 'Theme & Appearance', icon: Icons.palette_outlined),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('App Theme Mode', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 10),
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
          const SizedBox(height: 16),

          // Section: Medium-style Typography & Reading
          _SectionHeader(title: 'Typography & Reader (Medium-Style)', icon: Icons.text_fields_outlined),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Sans-Serif Font Family', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
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
                  const Divider(height: 24),

                  // Reading Contrast Scheme
                  const Text('Reader Contrast Scheme', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
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
                        side: BorderSide(color: isSelected ? theme.primaryColor : Colors.grey.withValues(alpha: 0.3)),
                        onPressed: () => settingsNotifier.updateReaderContrast(contrast),
                      );
                    }).toList(),
                  ),
                  const Divider(height: 24),

                  // Font Scale
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Text Scale', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text('${(settings.fontScale * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
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
          const SizedBox(height: 16),

          // Section: Voice & Text-to-Audio Settings
          _SectionHeader(title: 'Voice & Text-to-Audio (Read Aloud)', icon: Icons.record_voice_over_outlined),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Speech Speed
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Reading Speed', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(
                        '${(settings.ttsSpeechRate * 2.0).toStringAsFixed(2)}x',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                      ),
                    ],
                  ),
                  Slider(
                    value: settings.ttsSpeechRate,
                    min: 0.25,
                    max: 1.0,
                    divisions: 6,
                    label: '${(settings.ttsSpeechRate * 2.0).toStringAsFixed(1)}x',
                    onChanged: (val) {
                      settingsNotifier.updateTtsSpeechRate(val);
                    },
                  ),
                  const Divider(height: 16),

                  // Voice Pitch
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Voice Pitch', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(
                        settings.ttsPitch.toStringAsFixed(1),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Slider(
                    value: settings.ttsPitch,
                    min: 0.5,
                    max: 1.5,
                    divisions: 10,
                    onChanged: (val) {
                      settingsNotifier.updateTtsPitch(val);
                    },
                  ),
                  const Divider(height: 16),

                  // Language & Accent
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Narration Language', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      DropdownButton<String>(
                        value: settings.ttsLanguage,
                        underline: const SizedBox(),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
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
                  const SizedBox(height: 8),

                  // Test Voice Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.volume_up_rounded, size: 18),
                      label: const Text('Test Voice Sample'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
          const SizedBox(height: 16),

          // Section: Content Caching & Offline
          _SectionHeader(title: 'Content Caching & Performance', icon: Icons.cached_outlined),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Offline Content Caching', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Limits repeated requests to the Moodle server by saving courses and files locally.', style: TextStyle(fontSize: 12)),
                    value: settings.enableOfflineCache,
                    onChanged: (val) => settingsNotifier.updateOfflineCache(val),
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Local Cache Storage', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(height: 2),
                          Text(
                            _isLoadingCacheSize ? 'Calculating...' : '${_cacheSizeMb.toStringAsFixed(2)} MB stored',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                      OutlinedButton.icon(
                        onPressed: _clearCache,
                        icon: const Icon(Icons.delete_outline_rounded, size: 16),
                        label: const Text('Clear Cache', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Section: SSO Gateway & API Token
          _SectionHeader(title: 'SSO Gateway & Cloud Proxy', icon: Icons.vpn_lock_outlined),
          Card(
            child: ListTile(
              title: const Text('Configure SSO Proxy', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Text(
                'Endpoint: ${settings.ssoGatewayUrl}\nToken: ${settings.ssoApiToken.isNotEmpty ? "Custom Token Set" : "Default Bearer Token"}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              trailing: const Icon(Icons.edit_outlined),
              onTap: _showGatewayEditDialog,
            ),
          ),
          const SizedBox(height: 16),

          // Section: Diagnostics & Debug Logs
          _SectionHeader(title: 'Diagnostics & System Logs', icon: Icons.terminal_outlined),
          Card(
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.bug_report_outlined, color: Colors.blue, size: 20),
              ),
              title: const Text('Debug Logs & API Console', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: const Text(
                'Live HTTP traces, Moodle cookie/sesskey inspector, and manual endpoint testing.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DebugLogsScreen()),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Section: Notifications & Alarms
          _SectionHeader(title: 'Quiz & Assignment Alarms', icon: Icons.alarm_outlined),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.alarm_on_rounded, color: Colors.amber),
                  title: const Text('Deadline & Quiz Alarms', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('Schedule high-priority alarms for academic events.', style: TextStyle(fontSize: 12)),
                  value: settings.enableDeadlineAlarms,
                  onChanged: (val) {
                    settingsNotifier.updateEnableDeadlineAlarms(val);
                    final events = ref.read(dashboardProvider).events;
                    ref.read(alarmServiceProvider).refreshAlarms(
                      events: events,
                      settings: settings.copyWith(enableDeadlineAlarms: val),
                    );
                  },
                ),
                if (settings.enableDeadlineAlarms) ...[
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  SwitchListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.only(left: 32, right: 16),
                    title: const Text('24 Hours Before (Quiz Alert)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    subtitle: const Text('Notify 1 day ahead for quizzes and tests.', style: TextStyle(fontSize: 11)),
                    value: settings.alarm24HoursBefore,
                    onChanged: (val) {
                      settingsNotifier.updateAlarm24HoursBefore(val);
                      final events = ref.read(dashboardProvider).events;
                      ref.read(alarmServiceProvider).refreshAlarms(
                        events: events,
                        settings: settings.copyWith(alarm24HoursBefore: val),
                      );
                    },
                  ),
                  SwitchListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.only(left: 32, right: 16),
                    title: const Text('1 Hour Before (Urgent Reminder)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    subtitle: const Text('Alert 60 minutes before assignment deadlines & quiz start.', style: TextStyle(fontSize: 11)),
                    value: settings.alarm1HourBefore,
                    onChanged: (val) {
                      settingsNotifier.updateAlarm1HourBefore(val);
                      final events = ref.read(dashboardProvider).events;
                      ref.read(alarmServiceProvider).refreshAlarms(
                        events: events,
                        settings: settings.copyWith(alarm1HourBefore: val),
                      );
                    },
                  ),
                  SwitchListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.only(left: 32, right: 16),
                    title: const Text('On the Time (Exact Deadline / Start)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    subtitle: const Text('Ring alarm at the exact moment event starts/ends.', style: TextStyle(fontSize: 11)),
                    value: settings.alarmAtExactTime,
                    onChanged: (val) {
                      settingsNotifier.updateAlarmAtExactTime(val);
                      final events = ref.read(dashboardProvider).events;
                      ref.read(alarmServiceProvider).refreshAlarms(
                        events: events,
                        settings: settings.copyWith(alarmAtExactTime: val),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 14, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Alarms refresh automatically upon pulling down to refresh the homepage.',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.volume_up_outlined, size: 20),
                  title: const Text('Test Loud Alarm Notification', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  subtitle: const Text('Test alarm sound & vibration on this device', style: TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.play_arrow_rounded, color: Colors.amber),
                  onTap: () async {
                    await ref.read(alarmServiceProvider).showTestAlarm();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Test alarm triggered with sound and vibration!')),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.security_outlined, size: 20),
                  title: const Text('Request System Permission', style: TextStyle(fontSize: 13)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final granted = await ref.read(notificationServiceProvider).requestNotificationPermission();
                    if (context.mounted) {
                      messenger.showSnackBar(
                        SnackBar(content: Text(granted ? 'Notification permission active' : 'Permission declined')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Section: AI Study & Export Settings
          _SectionHeader(title: 'AI & Unit Utilities', icon: Icons.auto_awesome_outlined),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF8B5CF6), size: 22),
                  title: const Text('Learn with AI Option', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('Show the "Learn with AI" shortcut icon on course units to generate study guides with Gemini / ChatGPT.', style: TextStyle(fontSize: 12)),
                  value: settings.enableLearnWithAi,
                  onChanged: (val) => settingsNotifier.updateEnableLearnWithAi(val),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.archive_outlined, size: 22),
                  title: const Text('Auto-Share Exported ZIP', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('Instantly open device share sheet when a unit ZIP file is generated.', style: TextStyle(fontSize: 12)),
                  value: settings.autoShareExportedZip,
                  onChanged: (val) => settingsNotifier.updateAutoShareExportedZip(val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Section: AI Quiz Assistant (In-App Browser)
          _SectionHeader(title: 'AI Quiz Assistant (In-App Browser)', icon: Icons.psychology_outlined),
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.psychology_rounded, color: Color(0xFF6366F1), size: 22),
                  ),
                  title: const Text('Quiz AI Helper', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text(
                    'Detects Moodle questions in browser, marks the recommended choice and provides concise explanation. Strictly never auto-submits.',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: settings.enableQuizAiHelper,
                  onChanged: (val) => settingsNotifier.updateEnableQuizAiHelper(val),
                ),
                if (settings.enableQuizAiHelper) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                    child: Text(
                      'AI Provider',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<QuizAiProvider>(
                        segments: const [
                          ButtonSegment(
                            value: QuizAiProvider.gemini,
                            icon: Icon(Icons.auto_awesome, size: 16),
                            label: Text('Google Gemini'),
                          ),
                          ButtonSegment(
                            value: QuizAiProvider.openAi,
                            icon: Icon(Icons.bolt_rounded, size: 16),
                            label: Text('OpenAI (ChatGPT)'),
                          ),
                        ],
                        selected: {settings.quizAiProvider},
                        onSelectionChanged: (newSelection) {
                          settingsNotifier.updateQuizAiProvider(newSelection.first);
                        },
                      ),
                    ),
                  ),
                  const Divider(height: 16),
                  ListTile(
                    leading: const Icon(Icons.key_rounded, size: 20),
                    title: Text(
                      '${settings.quizAiProvider == QuizAiProvider.gemini ? "Gemini" : "OpenAI"} API Key',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      settings.quizAiApiKey.isNotEmpty
                          ? (settings.quizAiApiKey.length > 8
                              ? '${settings.quizAiApiKey.substring(0, 4)}••••${settings.quizAiApiKey.substring(settings.quizAiApiKey.length - 4)}'
                              : '••••••••')
                          : 'Not configured (Tap to enter API Key)',
                      style: TextStyle(
                        fontSize: 11,
                        color: settings.quizAiApiKey.isNotEmpty ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    onTap: _showQuizApiKeyDialog,
                  ),
                  if (settings.quizAiApiKey.isNotEmpty) ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.tune_rounded, size: 20),
                      title: const Text(
                        'AI Model Selection',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        settings.quizAiModel.isNotEmpty
                            ? settings.quizAiModel
                            : (settings.quizAiProvider == QuizAiProvider.gemini
                                ? 'gemini-1.5-flash (Default)'
                                : 'gpt-4o-mini (Default)'),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6366F1),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.play_circle_outline_rounded, size: 20),
                            tooltip: 'Test model response',
                            onPressed: () {
                              final currentModelId = settings.quizAiModel.isNotEmpty
                                  ? settings.quizAiModel
                                  : (settings.quizAiProvider == QuizAiProvider.gemini
                                      ? 'gemini-1.5-flash'
                                      : 'gpt-4o-mini');
                              _testModelResponseDialog(
                                modelId: currentModelId,
                                modelDisplayName: currentModelId,
                              );
                            },
                          ),
                          IconButton(
                            icon: _isLoadingModels
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.sync_rounded, size: 18),
                            tooltip: 'Fetch models from API endpoint',
                            onPressed: _isLoadingModels ? null : _showModelSelectionSheet,
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                        ],
                      ),
                      onTap: _showModelSelectionSheet,
                    ),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Session Information & Logout
          if (authState.isAuthenticated) ...[
            Center(
              child: Text(
                'Signed in as ${authState.session?.studentName ?? authState.session?.uid.toUpperCase()} (${authState.session?.uid.toUpperCase()})',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () => ref.read(authProvider.notifier).logout(),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Sign Out'),
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.errorContainer,
                foregroundColor: theme.colorScheme.onErrorContainer,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Minimal dialog that tests the selected AI model and reports Passed / Failed with Copy Error action.
class _ModelTestDialog extends StatefulWidget {
  final QuizAiProvider provider;
  final String apiKey;
  final String modelId;
  final String modelDisplayName;
  final QuizAiService quizAiService;

  const _ModelTestDialog({
    required this.provider,
    required this.apiKey,
    required this.modelId,
    required this.modelDisplayName,
    required this.quizAiService,
  });

  @override
  State<_ModelTestDialog> createState() => _ModelTestDialogState();
}

class _ModelTestDialogState extends State<_ModelTestDialog> {
  bool _isLoading = true;
  QuizAiAnswer? _answer;
  String? _errorMessage;
  bool _isCopied = false;

  @override
  void initState() {
    super.initState();
    _runTest();
  }

  Future<void> _runTest() async {
    setState(() {
      _isLoading = true;
      _answer = null;
      _errorMessage = null;
      _isCopied = false;
    });

    try {
      final answer = await widget.quizAiService.testModelWithPredefinedQuestion(
        provider: widget.provider,
        apiKey: widget.apiKey,
        model: widget.modelId,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _answer = answer;
          if (!answer.isSuccess) {
            _errorMessage = answer.errorMessage ?? 'Failed to receive a valid response.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPassed = _answer != null && _answer!.isSuccess;
    final isFailed = !_isLoading && (!isPassed || _errorMessage != null);
    final errorText = _errorMessage ?? _answer?.errorMessage ?? 'Unknown error occurred.';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isLoading) ...[
                const SizedBox(height: 8),
                const SizedBox(
                  width: 38,
                  height: 38,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Testing...',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.modelDisplayName,
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
              ] else if (isPassed) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.green,
                    size: 38,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Passed',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${widget.modelDisplayName} is ready to use.',
                  style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done'),
                  ),
                ),
              ] else if (isFailed) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cancel_rounded,
                    color: Colors.redAccent,
                    size: 38,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Test Failed',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.modelDisplayName,
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 14),
                Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      errorText,
                      style: const TextStyle(fontSize: 11, color: Colors.redAccent),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: Icon(
                          _isCopied ? Icons.check_rounded : Icons.copy_rounded,
                          size: 16,
                        ),
                        label: Text(_isCopied ? 'Copied' : 'Copy Error'),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: errorText));
                          setState(() => _isCopied = true);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Error copied to clipboard'),
                              duration: Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                TextButton.icon(
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Retry'),
                  onPressed: _runTest,
                ),
              ],
            ],
          ),
        ),
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
          padding: const EdgeInsets.symmetric(vertical: 10),
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
              const SizedBox(height: 4),
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

