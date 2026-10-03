class AppConstants {
  static const String appName = 'CUIMS Mobile';
  static const String appVersion = '1.0.0';
  
  // Storage Keys
  static const String keySettings = 'app_settings_v1';
  static const String keyAuthSession = 'auth_session_v1';
  static const String keyCachedCourses = 'cached_courses_v1';
  static const String keyCachedEvents = 'cached_events_v1';
  static const String keyCourseContentPrefix = 'cached_content_';
  static const String keyNotificationPromptShown = 'notif_permission_prompted';

  // Default values
  static const String defaultSsoUrl = 'https://lmssso.vercel.app/api/sso';
  static const String defaultLmsBaseUrl = 'https://lms.cuchd.in';
  static const Duration defaultCacheTtl = Duration(hours: 12);
  static const int defaultHttpTimeoutSeconds = 30;
  static const int ssoWaitDelaySeconds = 5;
}
