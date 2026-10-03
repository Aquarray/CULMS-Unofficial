import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/services/quiz_ai_service.dart';
import '../../../data/models/app_settings.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/settings_provider.dart';
import '../settings/settings_screen.dart';

/// Full-featured in-app browser with native Moodle cookie synchronization.
/// - Opens any LMS link (quizzes, forums, announcements, external links) without re-login.
/// - Automatically formats quizzes and tests with a distraction-free clean interface.
/// - Includes navigation controls: Back, Forward, Reload, and Open in External Browser.
/// - Protects live quiz attempts from accidental closure.
class AppBrowserScreen extends ConsumerStatefulWidget {
  final String initialUrl;
  final String? initialTitle;
  final String? courseName;
  final bool? forceQuizMode;

  const AppBrowserScreen({
    super.key,
    required this.initialUrl,
    this.initialTitle,
    this.courseName,
    this.forceQuizMode,
  });

  /// Convenient static helper to launch in-app browser from anywhere in the app.
  static Future<void> open(
    BuildContext context, {
    required String url,
    String? title,
    String? courseName,
    bool? isQuiz,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AppBrowserScreen(
          initialUrl: url,
          initialTitle: title,
          courseName: courseName,
          forceQuizMode: isQuiz,
        ),
      ),
    );
  }

  @override
  ConsumerState<AppBrowserScreen> createState() => _AppBrowserScreenState();
}

class _AppBrowserScreenState extends ConsumerState<AppBrowserScreen> {
  WebViewController? _controller;
  bool _isLoading = true;
  double _loadingProgress = 0.0;
  bool _isCleanModeEnabled = true;
  String? _currentTitle;
  String? _currentUrl;
  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _isAiSolving = false;

  bool get _isQuiz =>
      widget.forceQuizMode ??
      (_currentUrl?.contains('mod/quiz') ?? widget.initialUrl.contains('mod/quiz'));

  @override
  void initState() {
    super.initState();
    _currentTitle = widget.initialTitle;
    _currentUrl = widget.initialUrl;
    _initializeWebView();
  }

  Future<void> _initializeWebView() async {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      )
      ..addJavaScriptChannel(
        'QuizAiBridge',
        onMessageReceived: (JavaScriptMessage msg) {
          _handleQuizAiMessage(msg.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) {
              setState(() => _loadingProgress = progress / 100.0);
            }
          },
          onPageStarted: (url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _currentUrl = url;
              });
            }
          },
          onPageFinished: (url) async {
            if (!mounted) return;
            setState(() {
              _isLoading = false;
              _currentUrl = url;
            });

            // Update page title
            try {
              final title = await _controller?.getTitle();
              if (title != null && title.isNotEmpty && mounted) {
                final clean = title.split('|').first.trim();
                if (clean.isNotEmpty) {
                  setState(() => _currentTitle = clean);
                }
              }
            } catch (_) {}

            // Update canGoBack / canGoForward
            try {
              final back = await _controller?.canGoBack() ?? false;
              final forward = await _controller?.canGoForward() ?? false;
              if (mounted) {
                setState(() {
                  _canGoBack = back;
                  _canGoForward = forward;
                });
              }
            } catch (_) {}

            // Inject clean mode styles for quiz or when clean mode enabled
            if (_isCleanModeEnabled && _isQuiz && mounted) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              await _injectQuizStyles(isDark);
            }
          },
          onWebResourceError: (error) {
            debugPrint('[APP_BROWSER] Error: ${error.description}');
          },
        ),
      );

    _controller = controller;
    if (mounted) setState(() {});

    // Sync active session cookies before loading the request
    final authState = ref.read(authProvider);
    final session = authState.session;
    if (session != null && session.moodleSession.isNotEmpty) {
      try {
        final cookieManager = WebViewCookieManager();
        await cookieManager.setCookie(
          WebViewCookie(
            name: 'MoodleSession',
            value: session.moodleSession,
            domain: 'lms.cuchd.in',
            path: '/',
          ),
        );
      } catch (e) {
        debugPrint('[APP_BROWSER] Cookie sync warning: $e');
      }
    }

    final uri = Uri.tryParse(widget.initialUrl);
    if (uri != null) {
      await controller.loadRequest(uri);
    }
  }

  Future<void> _injectQuizStyles(bool isDark) async {
    if (_controller == null) return;
    final bg = isDark ? '#0f172a' : '#f8fafc';
    final cardBg = isDark ? '#1e293b' : '#ffffff';
    final textCol = isDark ? '#f8fafc' : '#0f172a';
    final textMuted = isDark ? '#94a3b8' : '#64748b';
    final borderCol = isDark ? '#334155' : '#e2e8f0';
    final timerBg = isDark ? '#450a0a' : '#fef2f2';
    final timerText = isDark ? '#f87171' : '#dc2626';
    final optionBg = isDark ? '#1e293b' : '#f1f5f9';
    final optionBgActive = isDark ? '#334155' : '#e0e7ff';

    final css = '''
      nav.navbar, #page-footer, .drawer, .drawer-toggles, #ai-lib-fab, #ai-lib-panel, 
      .breadcrumb, .activity-navigation, .toast-wrapper, #nav-notification-popover-container,
      .secondary-navigation, #theme_switch_link, .drawer-toggler, #courseindexdrawercontrols {
        display: none !important;
      }
      html, body {
        background: $bg !important;
        color: $textCol !important;
        margin: 0 !important;
        padding: 0 !important;
        overflow-x: hidden !important;
        -webkit-tap-highlight-color: transparent !important;
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif !important;
      }
      #page, #page-content, #region-main-box, #region-main, .main-inner, #topofscroll {
        margin: 0 !important;
        padding: 10px !important;
        width: 100% !important;
        max-width: 100% !important;
        background: $bg !important;
      }
      .que {
        background: $cardBg !important;
        color: $textCol !important;
        border: 1px solid $borderCol !important;
        border-radius: 16px !important;
        padding: 16px !important;
        margin-bottom: 20px !important;
        box-shadow: 0 4px 14px rgba(0, 0, 0, 0.05) !important;
      }
      .que .info {
        background: transparent !important;
        border: none !important;
        padding: 0 0 10px 0 !important;
        margin-bottom: 12px !important;
        border-bottom: 1px solid $borderCol !important;
        float: none !important;
        width: 100% !important;
        display: flex !important;
        justify-content: space-between !important;
        align-items: center !important;
      }
      .que .info .no {
        font-size: 15px !important;
        font-weight: 700 !important;
        color: #6366f1 !important;
      }
      .que .info .grade {
        font-size: 12px !important;
        color: $textMuted !important;
      }
      .que .content {
        margin: 0 !important;
      }
      .que .qtext {
        font-size: 15px !important;
        line-height: 1.6 !important;
        font-weight: 600 !important;
        color: $textCol !important;
        margin-bottom: 14px !important;
      }
      .que .answer div.r0, .que .answer div.r1 {
        padding: 12px 14px !important;
        margin-bottom: 8px !important;
        border-radius: 12px !important;
        border: 1px solid $borderCol !important;
        background: $optionBg !important;
        display: flex !important;
        align-items: center !important;
        transition: background 0.15s ease, border-color 0.15s ease !important;
      }
      .que .answer div.r0:active, .que .answer div.r1:active {
        background: $optionBgActive !important;
        border-color: #6366f1 !important;
      }
      .que .answer input[type="radio"], .que .answer input[type="checkbox"] {
        width: 20px !important;
        height: 20px !important;
        margin-right: 12px !important;
        accent-color: #6366f1 !important;
        flex-shrink: 0 !important;
      }
      .que .answer label {
        font-size: 14px !important;
        line-height: 1.4 !important;
        color: $textCol !important;
        cursor: pointer !important;
        margin: 0 !important;
      }
      #quiz-timer-wrapper, #quiz-timer, .quiztimer {
        position: sticky !important;
        top: 0 !important;
        z-index: 9999 !important;
        background: $timerBg !important;
        color: $timerText !important;
        border: 1px solid $timerText !important;
        border-radius: 12px !important;
        padding: 8px 16px !important;
        margin: 4px 0 12px 0 !important;
        text-align: center !important;
        font-size: 15px !important;
        font-weight: 700 !important;
        box-shadow: 0 4px 12px rgba(220, 38, 38, 0.15) !important;
      }
      .submitbtns, .mod_quiz-next-nav {
        margin-top: 16px !important;
        display: flex !important;
        justify-content: flex-end !important;
      }
      .submitbtns input[type="submit"], input.mod_quiz-next-nav, .btn-primary {
        background: #6366f1 !important;
        color: #ffffff !important;
        border: none !important;
        border-radius: 12px !important;
        padding: 12px 28px !important;
        font-size: 15px !important;
        font-weight: 600 !important;
        box-shadow: 0 4px 12px rgba(99, 102, 241, 0.3) !important;
        cursor: pointer !important;
      }
      .ai-recommended-option {
        border: 2px solid #10b981 !important;
        background: ${isDark ? 'rgba(16, 185, 129, 0.15)' : '#ecfdf5'} !important;
        box-shadow: 0 0 14px rgba(16, 185, 129, 0.28) !important;
      }
      .ai-explanation-box {
        margin-top: 14px !important;
        padding: 14px 16px !important;
        border-radius: 14px !important;
        background: ${isDark ? '#1e1b4b' : '#eef2ff'} !important;
        border: 1px solid ${isDark ? '#4338ca' : '#c7d2fe'} !important;
        font-family: inherit !important;
        box-shadow: 0 4px 14px rgba(99, 102, 241, 0.12) !important;
      }
      .ai-exp-header {
        display: flex !important;
        justify-content: space-between !important;
        align-items: center !important;
        margin-bottom: 8px !important;
      }
      .ai-badge {
        font-size: 12px !important;
        font-weight: 700 !important;
        color: #6366f1 !important;
        letter-spacing: 0.3px !important;
      }
      .ai-provider {
        font-size: 11px !important;
        font-weight: 600 !important;
        color: ${isDark ? '#a5b4fc' : '#4f46e5'} !important;
        background: ${isDark ? '#312e81' : '#e0e7ff'} !important;
        padding: 2px 10px !important;
        border-radius: 20px !important;
      }
      .ai-exp-text {
        font-size: 13.5px !important;
        line-height: 1.55 !important;
        color: $textCol !important;
        margin-bottom: 8px !important;
      }
      .ai-exp-disclaimer {
        font-size: 10.5px !important;
        color: $textMuted !important;
        font-style: italic !important;
      }
    ''';

    final script = """
      (function() {
        var existing = document.getElementById('cuims-quiz-clean-style');
        if (!existing) {
          var style = document.createElement('style');
          style.id = 'cuims-quiz-clean-style';
          style.innerHTML = `${css.replaceAll('\n', ' ').replaceAll('"', '\\"')}`;
          document.head.appendChild(style);
        }
      })();
    """;

    try {
      await _controller?.runJavaScript(script);
    } catch (_) {}
  }

  Future<void> _toggleCleanMode() async {
    setState(() {
      _isCleanModeEnabled = !_isCleanModeEnabled;
    });

    if (_isCleanModeEnabled && _isQuiz) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      await _injectQuizStyles(isDark);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Clean Quiz Mode enabled'),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      const removeScript = """
        (function() {
          var el = document.getElementById('cuims-quiz-clean-style');
          if (el) el.remove();
        })();
      """;
      try {
        await _controller?.runJavaScript(removeScript);
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Showing original web page view'),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _triggerAiQuizSolve() async {
    if (_controller == null) return;
    final settings = ref.read(settingsProvider);

    if (!settings.enableQuizAiHelper) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI Quiz Assistant is disabled in Settings.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (settings.quizAiApiKey.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${settings.quizAiProvider == QuizAiProvider.gemini ? "Gemini" : "OpenAI"} API Key is required.',
            ),
            action: SnackBarAction(
              label: 'Configure',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    setState(() => _isAiSolving = true);

    const extractScript = """
      (function() {
        try {
          var questions = [];
          var queElements = document.querySelectorAll('.que');
          for (var i = 0; i < queElements.length; i++) {
            var qEl = queElements[i];
            var qId = qEl.id || ('question_' + i);
            var qTextEl = qEl.querySelector('.qtext');
            if (!qTextEl) continue;
            var qText = (qTextEl.innerText || qTextEl.textContent || '').trim();
            
            var optContainers = qEl.querySelectorAll('.answer div.r0, .answer div.r1');
            var options = [];
            for (var j = 0; j < optContainers.length; j++) {
              var optEl = optContainers[j];
              var input = optEl.querySelector('input[type="radio"], input[type="checkbox"]');
              if (!input) continue;
              var inputId = input.id || '';
              var inputVal = input.value || '';
              var inputType = input.type || 'radio';
              var numEl = optEl.querySelector('.answernumber');
              var labelPrefix = numEl ? (numEl.innerText || numEl.textContent || '').trim() : '';
              var textRegion = optEl.querySelector('[data-region="answer-label"]') || optEl.querySelector('label') || optEl;
              var fullText = (textRegion.innerText || textRegion.textContent || '').trim();
              if (labelPrefix && fullText.indexOf(labelPrefix) === 0) {
                fullText = fullText.substring(labelPrefix.length).trim();
              }
              options.push({
                index: j,
                id: inputId,
                label: labelPrefix || (String.fromCharCode(97 + j) + '.'),
                text: fullText,
                value: inputVal,
                inputType: inputType
              });
            }
            if (options.length > 0) {
              questions.push({
                id: qId,
                text: qText,
                options: options
              });
            }
          }
          if (window.QuizAiBridge) {
            window.QuizAiBridge.postMessage(JSON.stringify({
              type: 'QUESTIONS_EXTRACTED',
              questions: questions
            }));
          }
        } catch (err) {
          if (window.QuizAiBridge) {
            window.QuizAiBridge.postMessage(JSON.stringify({
              type: 'ERROR',
              error: err.toString()
            }));
          }
        }
      })();
    """;

    try {
      await _controller?.runJavaScript(extractScript);
    } catch (e) {
      if (mounted) {
        setState(() => _isAiSolving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to read questions from page: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleQuizAiMessage(String messageStr) async {
    try {
      final data = json.decode(messageStr) as Map<String, dynamic>;
      final type = data['type'];

      if (type == 'QUESTIONS_EXTRACTED') {
        final rawList = data['questions'] as List? ?? [];
        if (rawList.isEmpty) {
          if (mounted) {
            setState(() => _isAiSolving = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No quiz questions found on this page.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }

        final questions = rawList
            .map((e) => QuizQuestion.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();

        final settings = ref.read(settingsProvider);
        final aiService = ref.read(quizAiServiceProvider);

        int solvedCount = 0;
        String? lastError;

        for (final q in questions) {
          final ans = await aiService.solveQuestion(
            question: q,
            provider: settings.quizAiProvider,
            apiKey: settings.quizAiApiKey,
            customModel: settings.quizAiModel,
          );

          if (ans.isSuccess) {
            solvedCount++;
            await _applyAiAnswerToWebview(ans, settings.quizAiProvider);
          } else {
            lastError = ans.errorMessage;
          }
        }

        if (mounted) {
          setState(() => _isAiSolving = false);
          if (solvedCount > 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'AI marked $solvedCount question${solvedCount > 1 ? "s" : ""} with explanation. (Not submitted)',
                      ),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFF1E1B4B),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 3),
              ),
            );
          } else if (lastError != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(lastError),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      } else if (type == 'ERROR') {
        if (mounted) {
          setState(() => _isAiSolving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Page error: ${data['error']}'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAiSolving = false);
      }
      debugPrint('[QuizAI] Message handler error: $e');
    }
  }

  Future<void> _applyAiAnswerToWebview(QuizAiAnswer answer, QuizAiProvider provider) async {
    final providerName = provider == QuizAiProvider.gemini ? 'Google Gemini' : 'OpenAI';
    final safeQuestionId = json.encode(answer.questionId);
    final safeSelectedId = json.encode(answer.selectedOptionId);
    final safeExplanation = json.encode(answer.explanation);
    final selectedIndex = answer.selectedOptionIndex;

    final script = """
      (function() {
        try {
          var qId = $safeQuestionId;
          var selId = $safeSelectedId;
          var explanation = $safeExplanation;
          var provider = '$providerName';
          
          var qCard = document.getElementById(qId) || document.querySelector('.que');
          var inp = selId ? document.getElementById(selId) : null;
          
          if (!inp && qCard) {
            var inputs = qCard.querySelectorAll('.answer input[type="radio"], .answer input[type="checkbox"]');
            if (inputs && inputs[$selectedIndex]) {
              inp = inputs[$selectedIndex];
            }
          }
          
          if (inp) {
            inp.checked = true;
            inp.click();
            inp.dispatchEvent(new Event('change', { bubbles: true }));
            
            var parent = inp.closest('.r0, .r1');
            if (parent) {
              var container = parent.parentElement;
              if (container) {
                var siblings = container.querySelectorAll('.r0, .r1');
                for (var s = 0; s < siblings.length; s++) {
                  siblings[s].classList.remove('ai-recommended-option');
                }
              }
              parent.classList.add('ai-recommended-option');
            }
          }
          
          if (qCard) {
            var existing = qCard.querySelector('.ai-explanation-box');
            if (existing) existing.remove();
            
            var expBox = document.createElement('div');
            expBox.className = 'ai-explanation-box';
            
            var header = document.createElement('div');
            header.className = 'ai-exp-header';
            header.innerHTML = '<span class="ai-badge">✨ AI Recommended</span><span class="ai-provider">' + provider + '</span>';
            expBox.appendChild(header);
            
            var body = document.createElement('div');
            body.className = 'ai-exp-text';
            body.textContent = explanation;
            expBox.appendChild(body);
            
            var disc = document.createElement('div');
            disc.className = 'ai-exp-disclaimer';
            disc.textContent = '💡 Educational AI Helper. Does NOT submit automatically.';
            expBox.appendChild(disc);
            
            var content = qCard.querySelector('.content') || qCard;
            content.appendChild(expBox);
          }
        } catch (e) {
          console.error('[QuizAI] Apply error:', e);
        }
      })();
    """;

    try {
      await _controller?.runJavaScript(script);
    } catch (e) {
      debugPrint('[QuizAI] Script error: $e');
    }
  }

  Future<bool> _onWillPop() async {
    // If in quiz mode, guard against accidental exits
    if (_isQuiz) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 8),
              Text('Leave Quiz?'),
            ],
          ),
          content: const Text(
            'If you are currently taking an active quiz or test, leaving this screen may affect your progress.\n\nMake sure your answers are saved before closing.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Stay on Quiz'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Leave'),
            ),
          ],
        ),
      );
      return confirm ?? false;
    }

    // For regular browsing, check if webview can navigate back
    if (_canGoBack && _controller != null) {
      await _controller!.goBack();
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          elevation: 0.5,
          titleSpacing: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Close',
            onPressed: () async {
              final shouldPop = await _onWillPop();
              if (shouldPop && context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _currentTitle ?? 'In-App Browser',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                widget.courseName ?? Uri.tryParse(_currentUrl ?? widget.initialUrl)?.host ?? 'lms.cuchd.in',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          actions: [
            if (_isQuiz && ref.watch(settingsProvider).enableQuizAiHelper)
              IconButton(
                icon: _isAiSolving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6366F1)),
                      )
                    : const Icon(Icons.psychology_rounded, color: Color(0xFF6366F1)),
                tooltip: 'AI Quiz Assistant',
                onPressed: _isAiSolving ? null : _triggerAiQuizSolve,
              ),
            if (_isQuiz)
              IconButton(
                icon: Icon(
                  _isCleanModeEnabled ? Icons.auto_awesome : Icons.auto_awesome_outlined,
                  color: _isCleanModeEnabled ? const Color(0xFF6366F1) : null,
                ),
                tooltip: _isCleanModeEnabled ? 'Clean Mode: Active' : 'Clean Mode: Off',
                onPressed: _toggleCleanMode,
              ),
            if (!_isQuiz && _canGoBack)
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
                tooltip: 'Back',
                onPressed: () => _controller?.goBack(),
              ),
            if (!_isQuiz && _canGoForward)
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                tooltip: 'Forward',
                onPressed: () => _controller?.goForward(),
              ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (val) async {
                final targetUrl = _currentUrl ?? widget.initialUrl;
                switch (val) {
                  case 'refresh':
                    _controller?.reload();
                    break;
                  case 'copy':
                    await Clipboard.setData(ClipboardData(text: targetUrl));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Link copied to clipboard'),
                          duration: Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                    break;
                  case 'external':
                    final uri = Uri.tryParse(targetUrl);
                    if (uri != null) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                    break;
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'refresh',
                  child: Row(
                    children: [
                      Icon(Icons.refresh_rounded, size: 20),
                      SizedBox(width: 10),
                      Text('Reload Page'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'copy',
                  child: Row(
                    children: [
                      Icon(Icons.copy_rounded, size: 20),
                      SizedBox(width: 10),
                      Text('Copy Link'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'external',
                  child: Row(
                    children: [
                      Icon(Icons.open_in_browser_rounded, size: 20),
                      SizedBox(width: 10),
                      Text('Open in System Browser'),
                    ],
                  ),
                ),
              ],
            ),
          ],
          bottom: _isLoading
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(3.0),
                  child: LinearProgressIndicator(
                    value: _loadingProgress > 0 ? _loadingProgress : null,
                    minHeight: 3.0,
                    backgroundColor: Colors.transparent,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                  ),
                )
              : null,
        ),
        body: _controller != null
            ? WebViewWidget(controller: _controller!)
            : const Center(child: CircularProgressIndicator()),
        floatingActionButton: (_isQuiz && ref.watch(settingsProvider).enableQuizAiHelper)
            ? FloatingActionButton.extended(
                elevation: 4,
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                icon: _isAiSolving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.auto_awesome, size: 20),
                label: Text(
                  _isAiSolving ? 'AI Thinking...' : '✨ Solve with AI',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: _isAiSolving ? null : _triggerAiQuizSolve,
              )
            : null,
      ),
    );
  }
}
