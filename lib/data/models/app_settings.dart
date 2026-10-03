import 'dart:convert';

enum AppThemeMode { system, light, dark, amoled }

enum ReaderContrast {
  cleanLight,
  mediumSepia,
  softDark,
  oledBlack,
  forestMist,
}

enum AppFontFamily {
  inter,
  plusJakarta,
  roboto,
  systemSans,
  literata,
}

enum QuizAiProvider {
  gemini,
  openAi,
}

class AppSettings {
  final AppThemeMode themeMode;
  final ReaderContrast readerContrast;
  final AppFontFamily fontFamily;
  final double fontScale;
  final double lineHeight;
  final bool enableOfflineCache;
  final int cacheTtlHours;
  final String ssoGatewayUrl;
  final String ssoApiToken;
  final bool notificationsEnabled;
  final int deadlineReminderHours;
  final bool autoShareExportedZip;
  final double ttsSpeechRate;
  final double ttsPitch;
  final double ttsVolume;
  final String ttsLanguage;
  final bool enableDeadlineAlarms;
  final bool alarm24HoursBefore;
  final bool alarm1HourBefore;
  final bool alarmAtExactTime;
  final bool enableLearnWithAi;
  final bool enableQuizAiHelper;
  final QuizAiProvider quizAiProvider;
  final String quizAiApiKey;
  final String quizAiModel;

  const AppSettings({
    this.themeMode = AppThemeMode.system,
    this.readerContrast = AppContrastFallback.defaultReaderContrast,
    this.fontFamily = AppFontFamily.inter,
    this.fontScale = 1.0,
    this.lineHeight = 1.6,
    this.enableOfflineCache = true,
    this.cacheTtlHours = 12,
    this.ssoGatewayUrl = 'https://lmssso.vercel.app/api/sso',
    this.ssoApiToken = '',
    this.notificationsEnabled = true,
    this.deadlineReminderHours = 24,
    this.autoShareExportedZip = true,
    this.ttsSpeechRate = 0.5,
    this.ttsPitch = 1.0,
    this.ttsVolume = 1.0,
    this.ttsLanguage = 'en-US',
    this.enableDeadlineAlarms = true,
    this.alarm24HoursBefore = true,
    this.alarm1HourBefore = true,
    this.alarmAtExactTime = true,
    this.enableLearnWithAi = true,
    this.enableQuizAiHelper = true,
    this.quizAiProvider = QuizAiProvider.gemini,
    this.quizAiApiKey = '',
    this.quizAiModel = '',
  });

  AppSettings copyWith({
    AppThemeMode? themeMode,
    ReaderContrast? readerContrast,
    AppFontFamily? fontFamily,
    double? fontScale,
    double? lineHeight,
    bool? enableOfflineCache,
    int? cacheTtlHours,
    String? ssoGatewayUrl,
    String? ssoApiToken,
    bool? notificationsEnabled,
    int? deadlineReminderHours,
    bool? autoShareExportedZip,
    double? ttsSpeechRate,
    double? ttsPitch,
    double? ttsVolume,
    String? ttsLanguage,
    bool? enableDeadlineAlarms,
    bool? alarm24HoursBefore,
    bool? alarm1HourBefore,
    bool? alarmAtExactTime,
    bool? enableLearnWithAi,
    bool? enableQuizAiHelper,
    QuizAiProvider? quizAiProvider,
    String? quizAiApiKey,
    String? quizAiModel,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      readerContrast: readerContrast ?? this.readerContrast,
      fontFamily: fontFamily ?? this.fontFamily,
      fontScale: fontScale ?? this.fontScale,
      lineHeight: lineHeight ?? this.lineHeight,
      enableOfflineCache: enableOfflineCache ?? this.enableOfflineCache,
      cacheTtlHours: cacheTtlHours ?? this.cacheTtlHours,
      ssoGatewayUrl: ssoGatewayUrl ?? this.ssoGatewayUrl,
      ssoApiToken: ssoApiToken ?? this.ssoApiToken,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      deadlineReminderHours: deadlineReminderHours ?? this.deadlineReminderHours,
      autoShareExportedZip: autoShareExportedZip ?? this.autoShareExportedZip,
      ttsSpeechRate: ttsSpeechRate ?? this.ttsSpeechRate,
      ttsPitch: ttsPitch ?? this.ttsPitch,
      ttsVolume: ttsVolume ?? this.ttsVolume,
      ttsLanguage: ttsLanguage ?? this.ttsLanguage,
      enableDeadlineAlarms: enableDeadlineAlarms ?? this.enableDeadlineAlarms,
      alarm24HoursBefore: alarm24HoursBefore ?? this.alarm24HoursBefore,
      alarm1HourBefore: alarm1HourBefore ?? this.alarm1HourBefore,
      alarmAtExactTime: alarmAtExactTime ?? this.alarmAtExactTime,
      enableLearnWithAi: enableLearnWithAi ?? this.enableLearnWithAi,
      enableQuizAiHelper: enableQuizAiHelper ?? this.enableQuizAiHelper,
      quizAiProvider: quizAiProvider ?? this.quizAiProvider,
      quizAiApiKey: quizAiApiKey ?? this.quizAiApiKey,
      quizAiModel: quizAiModel ?? this.quizAiModel,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'themeMode': themeMode.name,
      'readerContrast': readerContrast.name,
      'fontFamily': fontFamily.name,
      'fontScale': fontScale,
      'lineHeight': lineHeight,
      'enableOfflineCache': enableOfflineCache,
      'cacheTtlHours': cacheTtlHours,
      'ssoGatewayUrl': ssoGatewayUrl,
      'ssoApiToken': ssoApiToken,
      'notificationsEnabled': notificationsEnabled,
      'deadlineReminderHours': deadlineReminderHours,
      'autoShareExportedZip': autoShareExportedZip,
      'ttsSpeechRate': ttsSpeechRate,
      'ttsPitch': ttsPitch,
      'ttsVolume': ttsVolume,
      'ttsLanguage': ttsLanguage,
      'enableDeadlineAlarms': enableDeadlineAlarms,
      'alarm24HoursBefore': alarm24HoursBefore,
      'alarm1HourBefore': alarm1HourBefore,
      'alarmAtExactTime': alarmAtExactTime,
      'enableLearnWithAi': enableLearnWithAi,
      'enableQuizAiHelper': enableQuizAiHelper,
      'quizAiProvider': quizAiProvider.name,
      'quizAiApiKey': quizAiApiKey,
      'quizAiModel': quizAiModel,
    };
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      themeMode: AppThemeMode.values.firstWhere(
        (e) => e.name == map['themeMode'],
        orElse: () => AppThemeMode.system,
      ),
      readerContrast: ReaderContrast.values.firstWhere(
        (e) => e.name == map['readerContrast'],
        orElse: () => ReaderContrast.mediumSepia,
      ),
      fontFamily: AppFontFamily.values.firstWhere(
        (e) => e.name == map['fontFamily'],
        orElse: () => AppFontFamily.inter,
      ),
      fontScale: (map['fontScale'] as num?)?.toDouble() ?? 1.0,
      lineHeight: (map['lineHeight'] as num?)?.toDouble() ?? 1.6,
      enableOfflineCache: map['enableOfflineCache'] as bool? ?? true,
      cacheTtlHours: map['cacheTtlHours'] as int? ?? 12,
      ssoGatewayUrl: map['ssoGatewayUrl'] as String? ?? 'https://lmssso.vercel.app/api/sso',
      ssoApiToken: map['ssoApiToken'] as String? ?? '',
      notificationsEnabled: map['notificationsEnabled'] as bool? ?? true,
      deadlineReminderHours: map['deadlineReminderHours'] as int? ?? 24,
      autoShareExportedZip: map['autoShareExportedZip'] as bool? ?? true,
      ttsSpeechRate: (map['ttsSpeechRate'] as num?)?.toDouble() ?? 0.5,
      ttsPitch: (map['ttsPitch'] as num?)?.toDouble() ?? 1.0,
      ttsVolume: (map['ttsVolume'] as num?)?.toDouble() ?? 1.0,
      ttsLanguage: map['ttsLanguage'] as String? ?? 'en-US',
      enableDeadlineAlarms: map['enableDeadlineAlarms'] as bool? ?? true,
      alarm24HoursBefore: map['alarm24HoursBefore'] as bool? ?? true,
      alarm1HourBefore: map['alarm1HourBefore'] as bool? ?? true,
      alarmAtExactTime: map['alarmAtExactTime'] as bool? ?? true,
      enableLearnWithAi: map['enableLearnWithAi'] as bool? ?? true,
      enableQuizAiHelper: map['enableQuizAiHelper'] as bool? ?? true,
      quizAiProvider: QuizAiProvider.values.firstWhere(
        (e) => e.name == map['quizAiProvider'],
        orElse: () => QuizAiProvider.gemini,
      ),
      quizAiApiKey: map['quizAiApiKey'] as String? ?? '',
      quizAiModel: map['quizAiModel'] as String? ?? '',
    );
  }

  String toJson() => json.encode(toMap());

  factory AppSettings.fromJson(String source) =>
      AppSettings.fromMap(json.decode(source) as Map<String, dynamic>);
}

class AppContrastFallback {
  static const ReaderContrast defaultReaderContrast = ReaderContrast.mediumSepia;
}
