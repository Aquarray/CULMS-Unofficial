import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/alarm_service.dart';
import '../../core/services/cache_service.dart';
import '../../core/services/cookie_service.dart';
import '../../core/services/log_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/quiz_ai_service.dart';
import '../../core/services/zip_export_service.dart';
import '../../data/network/lms_api_client.dart';

final logServiceProvider = Provider<LogService>((ref) {
  return LogService();
});

final alarmServiceProvider = Provider<AlarmService>((ref) {
  return AlarmService();
});

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 40),
      receiveTimeout: const Duration(seconds: 40),
      sendTimeout: const Duration(seconds: 40),
    ),
  );

  final logService = ref.watch(logServiceProvider);

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        logService.http(
          'DIO_REQ',
          '${options.method} ${options.uri}',
          'Headers: ${options.headers}\nData: ${options.data}',
        );
        handler.next(options);
      },
      onResponse: (response, handler) {
        final dataStr = response.data.toString();
        final preview = dataStr.length > 500 ? '${dataStr.substring(0, 500)}... [truncated]' : dataStr;
        logService.http(
          'DIO_RESP',
          '${response.statusCode} ${response.requestOptions.uri}',
          'Headers: ${response.headers.map}\nBody: $preview',
        );
        handler.next(response);
      },
      onError: (DioException e, handler) {
        logService.error(
          'DIO_ERR',
          '${e.requestOptions.method} ${e.requestOptions.uri} - ${e.type}',
          'Message: ${e.message}\nStatus: ${e.response?.statusCode}\nResponse: ${e.response?.data}',
        );
        handler.next(e);
      },
    ),
  );

  return dio;
});

final cacheServiceProvider = Provider<CacheService>((ref) {
  return CacheService();
});

final cookieServiceProvider = Provider<CookieService>((ref) {
  return CookieService();
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final lmsApiClientProvider = Provider<LmsApiClient>((ref) {
  final dio = ref.watch(dioProvider);
  final cacheService = ref.watch(cacheServiceProvider);
  final logService = ref.watch(logServiceProvider);
  return LmsApiClient(
    dio: dio,
    cacheService: cacheService,
    logService: logService,
  );
});

final zipExportServiceProvider = Provider<ZipExportService>((ref) {
  final dio = ref.watch(dioProvider);
  final cacheService = ref.watch(cacheServiceProvider);
  return ZipExportService(dio: dio, cacheService: cacheService);
});

final quizAiServiceProvider = Provider<QuizAiService>((ref) {
  return QuizAiService();
});
