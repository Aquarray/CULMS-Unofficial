import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/app_constants.dart';
import '../../data/models/app_settings.dart';

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    _loadSettings();
    return const AppSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString(AppConstants.keySettings);
      if (savedJson != null) {
        state = AppSettings.fromJson(savedJson);
      }
    } catch (_) {}
  }

  Future<void> _saveSettings(AppSettings newSettings) async {
    state = newSettings;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.keySettings, newSettings.toJson());
    } catch (_) {}
  }

  void updateThemeMode(AppThemeMode mode) {
    _saveSettings(state.copyWith(themeMode: mode));
  }

  void updateAccentColor(AppAccentColor color) {
    _saveSettings(state.copyWith(accentColor: color));
  }

  void updateFontFamily(AppFontFamily family) {
    _saveSettings(state.copyWith(fontFamily: family));
  }

  void updateFontScale(double scale) {
    _saveSettings(state.copyWith(fontScale: scale));
  }

  void updateLineHeight(double height) {
    _saveSettings(state.copyWith(lineHeight: height));
  }

  void updateReaderContrast(ReaderContrast contrast) {
    _saveSettings(state.copyWith(readerContrast: contrast));
  }

  void updateOfflineCache(bool enable) {
    _saveSettings(state.copyWith(enableOfflineCache: enable));
  }

  void updateCacheTtlHours(int hours) {
    _saveSettings(state.copyWith(cacheTtlHours: hours));
  }

  void updateSsoGatewayUrl(String url) {
    _saveSettings(state.copyWith(ssoGatewayUrl: url));
  }

  void updateSsoApiToken(String token) {
    _saveSettings(state.copyWith(ssoApiToken: token));
  }

  void updateNotificationsEnabled(bool enable) {
    _saveSettings(state.copyWith(notificationsEnabled: enable));
  }

  void updateAutoShareExportedZip(bool autoShare) {
    _saveSettings(state.copyWith(autoShareExportedZip: autoShare));
  }

  void updateTtsSpeechRate(double rate) {
    _saveSettings(state.copyWith(ttsSpeechRate: rate));
  }

  void updateTtsPitch(double pitch) {
    _saveSettings(state.copyWith(ttsPitch: pitch));
  }

  void updateTtsVolume(double volume) {
    _saveSettings(state.copyWith(ttsVolume: volume));
  }

  void updateTtsLanguage(String lang) {
    _saveSettings(state.copyWith(ttsLanguage: lang));
  }

  void updateEnableDeadlineAlarms(bool enable) {
    _saveSettings(state.copyWith(enableDeadlineAlarms: enable));
  }

  void updateAlarm24HoursBefore(bool enable) {
    _saveSettings(state.copyWith(alarm24HoursBefore: enable));
  }

  void updateAlarm1HourBefore(bool enable) {
    _saveSettings(state.copyWith(alarm1HourBefore: enable));
  }

  void updateAlarmAtExactTime(bool enable) {
    _saveSettings(state.copyWith(alarmAtExactTime: enable));
  }

  void updateEnableLearnWithAi(bool enable) {
    _saveSettings(state.copyWith(enableLearnWithAi: enable));
  }

  void updateEnableQuizAiHelper(bool enable) {
    _saveSettings(state.copyWith(enableQuizAiHelper: enable));
  }

  void updateQuizAiProvider(QuizAiProvider provider) {
    final defaultModel =
        provider == QuizAiProvider.gemini ? 'gemini-1.5-flash' : 'gpt-4o-mini';
    _saveSettings(state.copyWith(
      quizAiProvider: provider,
      quizAiModel: defaultModel,
    ));
  }

  void updateQuizAiApiKey(String key) {
    _saveSettings(state.copyWith(quizAiApiKey: key));
  }

  void updateQuizAiModel(String model) {
    _saveSettings(state.copyWith(quizAiModel: model));
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
