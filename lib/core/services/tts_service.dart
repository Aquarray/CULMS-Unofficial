import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../data/models/app_settings.dart';
import '../../providers/settings_provider.dart';

enum TtsPlaybackState { stopped, playing, paused }

class TtsState {
  final TtsPlaybackState state;
  final String currentText;
  final double currentProgress;
  final int currentWordStart;
  final int currentWordEnd;
  final String? errorMessage;

  const TtsState({
    this.state = TtsPlaybackState.stopped,
    this.currentText = '',
    this.currentProgress = 0.0,
    this.currentWordStart = 0,
    this.currentWordEnd = 0,
    this.errorMessage,
  });

  bool get isPlaying => state == TtsPlaybackState.playing;
  bool get isPaused => state == TtsPlaybackState.paused;
  bool get isStopped => state == TtsPlaybackState.stopped;

  TtsState copyWith({
    TtsPlaybackState? state,
    String? currentText,
    double? currentProgress,
    int? currentWordStart,
    int? currentWordEnd,
    String? errorMessage,
  }) {
    return TtsState(
      state: state ?? this.state,
      currentText: currentText ?? this.currentText,
      currentProgress: currentProgress ?? this.currentProgress,
      currentWordStart: currentWordStart ?? this.currentWordStart,
      currentWordEnd: currentWordEnd ?? this.currentWordEnd,
      errorMessage: errorMessage,
    );
  }
}

class TtsNotifier extends Notifier<TtsState> {
  late final FlutterTts _flutterTts;
  bool _isInitialized = false;

  @override
  TtsState build() {
    _initTts();
    ref.onDispose(() {
      _flutterTts.stop();
    });
    return const TtsState();
  }

  Future<void> _initTts() async {
    if (_isInitialized) return;
    _flutterTts = FlutterTts();

    _flutterTts.setStartHandler(() {
      state = state.copyWith(state: TtsPlaybackState.playing);
    });

    _flutterTts.setCompletionHandler(() {
      state = state.copyWith(state: TtsPlaybackState.stopped, currentProgress: 1.0);
    });

    _flutterTts.setCancelHandler(() {
      state = state.copyWith(state: TtsPlaybackState.stopped, currentProgress: 0.0);
    });

    _flutterTts.setPauseHandler(() {
      state = state.copyWith(state: TtsPlaybackState.paused);
    });

    _flutterTts.setContinueHandler(() {
      state = state.copyWith(state: TtsPlaybackState.playing);
    });

    _flutterTts.setErrorHandler((msg) {
      debugPrint('[TTS] Error: $msg');
      state = state.copyWith(
        state: TtsPlaybackState.stopped,
        errorMessage: msg.toString(),
      );
    });

    _flutterTts.setProgressHandler((String text, int start, int end, String word) {
      final total = text.length;
      final progress = total > 0 ? (end / total).clamp(0.0, 1.0) : 0.0;
      state = state.copyWith(
        currentProgress: progress,
        currentWordStart: start,
        currentWordEnd: end,
      );
    });

    // Apply current settings
    final settings = ref.read(settingsProvider);
    await applySettings(settings);

    _isInitialized = true;
  }

  Future<void> applySettings(AppSettings settings) async {
    try {
      await _flutterTts.setSpeechRate(settings.ttsSpeechRate);
      await _flutterTts.setPitch(settings.ttsPitch);
      await _flutterTts.setVolume(settings.ttsVolume);
      await _flutterTts.setLanguage(settings.ttsLanguage);
    } catch (e) {
      debugPrint('[TTS] Apply settings error: $e');
    }
  }

  /// Converts markdown text into clean, natural text suitable for narration.
  static String cleanMarkdown(String markdown) {
    var text = markdown;

    // Remove code blocks
    text = text.replaceAll(RegExp(r'```[\s\S]*?```'), ' [Code Block Omitted] ');

    // Remove inline code
    text = text.replaceAllMapped(RegExp(r'`([^`]+)`'), (m) => m.group(1) ?? '');

    // Remove images: ![alt](url) -> ""
    text = text.replaceAll(RegExp(r'!\[.*?\]\(.*?\)'), '');

    // Convert links: [text](url) -> text
    text = text.replaceAllMapped(RegExp(r'\[(.*?)\]\(.*?\)'), (m) => m.group(1) ?? '');

    // Remove headers (#, ##, etc.)
    text = text.replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '');

    // Remove emphasis (bold, italic)
    text = text.replaceAllMapped(RegExp(r'\*\*(.*?)\*\*'), (m) => m.group(1) ?? '');
    text = text.replaceAllMapped(RegExp(r'__(.*?)__'), (m) => m.group(1) ?? '');
    text = text.replaceAllMapped(RegExp(r'\*(.*?)\*'), (m) => m.group(1) ?? '');
    text = text.replaceAllMapped(RegExp(r'_(.*?)_'), (m) => m.group(1) ?? '');

    // Remove HTML tags
    text = text.replaceAll(RegExp(r'<[^>]*>'), ' ');

    // Remove blockquotes & list markers
    text = text.replaceAll(RegExp(r'^>\s+', multiLine: true), '');
    text = text.replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '');
    text = text.replaceAll(RegExp(r'^\s*\d+\.\s+', multiLine: true), '');

    // Collapse extra whitespaces
    text = text.replaceAll(RegExp(r'\n{2,}'), '\n\n');
    text = text.replaceAll(RegExp(r'[ \t]+'), ' ');

    return text.trim();
  }

  Future<void> speakMarkdown(String rawMarkdown) async {
    await _initTts();
    final clean = cleanMarkdown(rawMarkdown);
    if (clean.isEmpty) return;

    final settings = ref.read(settingsProvider);
    await applySettings(settings);

    state = state.copyWith(currentText: clean, currentProgress: 0.0);
    await _flutterTts.speak(clean);
  }

  Future<void> pause() async {
    await _flutterTts.pause();
    state = state.copyWith(state: TtsPlaybackState.paused);
  }

  Future<void> resume() async {
    final settings = ref.read(settingsProvider);
    await applySettings(settings);
    if (state.currentText.isNotEmpty) {
      await _flutterTts.speak(state.currentText);
    }
  }

  Future<void> stop() async {
    await _flutterTts.stop();
    state = state.copyWith(state: TtsPlaybackState.stopped, currentProgress: 0.0);
  }

  Future<void> testVoice({
    double? rate,
    double? pitch,
    double? volume,
    String? language,
  }) async {
    await _initTts();
    if (rate != null) await _flutterTts.setSpeechRate(rate);
    if (pitch != null) await _flutterTts.setPitch(pitch);
    if (volume != null) await _flutterTts.setVolume(volume);
    if (language != null) await _flutterTts.setLanguage(language);

    await _flutterTts.speak(
      "Hello! This is a test of your reading voice settings for study materials and notes.",
    );
  }

  Future<List<String>> getAvailableLanguages() async {
    await _initTts();
    try {
      final langs = await _flutterTts.getLanguages;
      if (langs is List) {
        return langs.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return ['en-US', 'en-IN', 'en-GB', 'hi-IN'];
  }
}

final ttsProvider = NotifierProvider<TtsNotifier, TtsState>(() {
  return TtsNotifier();
});
