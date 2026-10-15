import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/services/quiz_ai_service.dart';
import '../../../../data/models/app_settings.dart';
import '../../../../providers/app_providers.dart';
import '../../../../providers/settings_provider.dart';
import '../../../widgets/ai_brand_icons.dart';

class QuizAiSettingsScreen extends ConsumerStatefulWidget {
  const QuizAiSettingsScreen({super.key});

  @override
  ConsumerState<QuizAiSettingsScreen> createState() => _QuizAiSettingsScreenState();
}

class _QuizAiSettingsScreenState extends ConsumerState<QuizAiSettingsScreen> {
  bool _isLoadingModels = false;

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
                  child: isGemini
                      ? const GeminiIcon(size: 20, useGradient: true)
                      : const OpenAiIcon(size: 20, color: Color(0xFF10A37F)),
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
                      suffixIcon: IconButton(
                        icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setDlgState(() => obscure = !obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final uri = Uri.parse(linkUrl);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.open_in_new_rounded, size: 14, color: theme.colorScheme.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              linkText,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 11),
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
              FilledButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        final key = keyCtrl.text.trim();
                        if (key.isEmpty) {
                          ref.read(settingsProvider.notifier).updateQuizAiApiKey('');
                          ref.read(settingsProvider.notifier).updateQuizAiModel('');
                          Navigator.pop(ctx);
                          return;
                        }

                        setDlgState(() {
                          isSaving = true;
                          errorMessage = null;
                        });

                        try {
                          final quizService = ref.read(quizAiServiceProvider);
                          final result = await quizService.fetchAvailableModels(
                            provider: settings.quizAiProvider,
                            apiKey: key,
                          );

                          if (!result.isSuccess) {
                            setDlgState(() {
                              isSaving = false;
                              errorMessage = result.errorMessage ?? 'Connection failed.';
                            });
                            return;
                          }

                          final models = result.models;
                          ref.read(settingsProvider.notifier).updateQuizAiApiKey(key);

                          final currentModel = settings.quizAiModel;
                          final modelStillExists = models.any((m) => m.id == currentModel);
                          if (!modelStillExists && models.isNotEmpty) {
                            ref.read(settingsProvider.notifier).updateQuizAiModel(models.first.id);
                          }

                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('$providerName API Key connected successfully!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          setDlgState(() {
                            isSaving = false;
                            errorMessage = 'Connection failed: $e';
                          });
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save & Connect'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showModelSelectionSheet() async {
    final settings = ref.read(settingsProvider);
    final quizService = ref.read(quizAiServiceProvider);
    final provider = settings.quizAiProvider;
    final isGemini = provider == QuizAiProvider.gemini;

    setState(() => _isLoadingModels = true);

    List<AiModelInfo> models = [];
    bool isLive = false;
    try {
      final res = await quizService.fetchAvailableModels(
        provider: provider,
        apiKey: settings.quizAiApiKey,
      );
      if (res.isSuccess && res.models.isNotEmpty) {
        models = res.models;
        isLive = true;
      } else {
        models = isGemini ? QuizAiService.defaultGeminiModels : QuizAiService.defaultOpenAiModels;
        isLive = false;
      }
    } catch (_) {
      models = isGemini ? QuizAiService.defaultGeminiModels : QuizAiService.defaultOpenAiModels;
      isLive = false;
    } finally {
      if (mounted) setState(() => _isLoadingModels = false);
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final currentModel = settings.quizAiModel.isNotEmpty
            ? settings.quizAiModel
            : (isGemini ? 'gemini-1.5-flash' : 'gpt-4o-mini');

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: (isGemini ? const Color(0xFF6366F1) : const Color(0xFF10A37F))
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: isGemini
                          ? const GeminiIcon(size: 18, useGradient: true)
                          : const OpenAiIcon(size: 18, color: Color(0xFF10A37F)),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${isGemini ? "Gemini" : "OpenAI"} Models',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          isLive ? 'Live API models' : 'Recommended models',
                          style: TextStyle(
                            fontSize: 11,
                            color: isLive ? Colors.green : Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: models.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final m = models[index];
                      final isSelected = m.id == currentModel;
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        leading: Icon(
                          isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                          color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
                          size: 20,
                        ),
                        title: Text(
                          m.displayName,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          (m.description != null && m.description!.isNotEmpty)
                              ? m.description!
                              : m.id,
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
                          ref.read(settingsProvider.notifier).updateQuizAiModel(m.id);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(content: Text('Switched to ${m.displayName}')),
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
            ),
          ),
        );
      },
    );
  }

  void _testModelResponseDialog({
    required String modelId,
    required String modelDisplayName,
  }) {
    final settings = ref.read(settingsProvider);
    if (settings.quizAiApiKey.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('API Key Required'),
          content: const Text('Please enter an API Key first before testing the model.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
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

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ModelTestDialog(
        provider: settings.quizAiProvider,
        apiKey: settings.quizAiApiKey,
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz AI Assistant'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Switch Setting: good title, description, and switch
                SwitchListTile(
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.psychology_rounded, color: Color(0xFF6366F1), size: 22),
                  ),
                  title: const Text(
                    'Quiz AI Helper',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Detects Moodle questions in browser, recommends the best choice, and explains answers. Strictly never auto-submits.',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: settings.enableQuizAiHelper,
                  onChanged: (val) => settingsNotifier.updateEnableQuizAiHelper(val),
                ),

                if (settings.enableQuizAiHelper) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Non-switch setting 1: AI Provider
                        const Text(
                          'AI Provider',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<QuizAiProvider>(
                            segments: const [
                              ButtonSegment(
                                value: QuizAiProvider.gemini,
                                icon: GeminiIcon(size: 16, useGradient: true),
                                label: Text('Google Gemini'),
                              ),
                              ButtonSegment(
                                value: QuizAiProvider.openAi,
                                icon: OpenAiIcon(size: 16, color: Color(0xFF10A37F)),
                                label: Text('OpenAI (ChatGPT)'),
                              ),
                            ],
                            selected: {settings.quizAiProvider},
                            onSelectionChanged: (newSelection) {
                              settingsNotifier.updateQuizAiProvider(newSelection.first);
                            },
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Non-switch setting 2: API Key
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'API Key',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            Text(
                              settings.quizAiApiKey.isNotEmpty ? 'Configured' : 'Not Set',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: settings.quizAiApiKey.isNotEmpty ? Colors.green : Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.key_rounded, size: 18),
                            label: Text(
                              settings.quizAiApiKey.isNotEmpty ? 'Update API Key' : 'Enter API Key',
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: _showQuizApiKeyDialog,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Non-switch setting 3: AI Model
                        if (settings.quizAiApiKey.isNotEmpty) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'AI Model',
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              Text(
                                settings.quizAiModel.isNotEmpty
                                    ? settings.quizAiModel
                                    : (settings.quizAiProvider == QuizAiProvider.gemini
                                        ? 'gemini-1.5-flash'
                                        : 'gpt-4o-mini'),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF6366F1),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.tune_rounded, size: 18),
                                  label: const Text('Select Model'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: _isLoadingModels ? null : _showModelSelectionSheet,
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
                                label: const Text('Test'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
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
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
            _errorMessage = answer.errorMessage ?? 'Model returned an empty or invalid response.';
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
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (widget.provider == QuizAiProvider.gemini
                      ? const Color(0xFF6366F1)
                      : const Color(0xFF10A37F))
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: widget.provider == QuizAiProvider.gemini
                ? const GeminiIcon(size: 20, useGradient: true)
                : const OpenAiIcon(size: 20, color: Color(0xFF10A37F)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _isLoading
                  ? 'Testing Model...'
                  : (_answer != null && _answer!.isSuccess ? 'Model Ready' : 'Test Failed'),
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
            Text(
              'Model: ${widget.modelDisplayName}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            if (_isLoading) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Connecting and querying AI model...', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ] else if (_answer != null && _answer!.isSuccess) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.green, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Connection Succeeded',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _answer!.explanation.isNotEmpty
                                ? _answer!.explanation
                                : 'Test prompt returned a valid response.',
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Test Failed',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      _errorMessage ?? 'Unknown error occurred.',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white70 : Colors.black87,
                        fontFamily: 'monospace',
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
        if (!_isLoading) ...[
          if (_errorMessage != null)
            TextButton.icon(
              icon: Icon(_isCopied ? Icons.check_rounded : Icons.copy_rounded, size: 16),
              label: Text(_isCopied ? 'Copied' : 'Copy Error'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _errorMessage!));
                setState(() => _isCopied = true);
              },
            ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ],
    );
  }
}
