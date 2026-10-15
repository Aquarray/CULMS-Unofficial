import 'dart:convert';
import 'sso_progress.dart';

enum AuthStatus {
  initial,
  connectingGateway,
  captchaRequired,
  loggingInMoodle,
  authenticated,
  reauthenticating,
  error,
}

class SsoResponse {
  final bool success;
  final String? uid;
  final String? token;
  final String? appAccessToken;
  final String? lmsLoginUrl;
  final int? expiresAt;
  final bool autoSolved;
  final bool requireManualCaptcha;
  final String? sessionToken;
  final String? captchaImage;
  final String? error;

  const SsoResponse({
    required this.success,
    this.uid,
    this.token,
    this.appAccessToken,
    this.lmsLoginUrl,
    this.expiresAt,
    this.autoSolved = false,
    this.requireManualCaptcha = false,
    this.sessionToken,
    this.captchaImage,
    this.error,
  });

  factory SsoResponse.fromJson(Map<String, dynamic> json) {
    // Support terminal SSE result format: {"status": 200, "data": {...}}
    // as well as direct JSON response format: {"success": true, ...}
    final Map<String, dynamic> payload;
    final int status;
    if (json.containsKey('data') && json['data'] is Map<String, dynamic>) {
      payload = json['data'] as Map<String, dynamic>;
      status = (json['status'] as num?)?.toInt() ?? 200;
    } else {
      payload = json;
      status = (json['status'] as num?)?.toInt() ?? 200;
    }

    final rawSuccess = payload['success'] as bool? ?? (status < 400 && payload.containsKey('token'));
    final captchaImg = payload['captchaImage'] as String?;
    final sessToken = payload['sessionToken'] as String?;
    final lmsUrl = payload['lmsLoginUrl'] as String?;
    final token = payload['token'] as String?;

    // Check if manual captcha is required or if this is a captcha initialization challenge
    final bool requireManual = (payload['requireManualCaptcha'] as bool? ?? false) ||
        (captchaImg != null && sessToken != null && token == null && lmsUrl == null);

    // If manual captcha is required, treat as challenge rather than authenticated success
    final bool finalSuccess = requireManual ? false : rawSuccess;

    // Error message fallback
    final String? err = payload['error'] as String? ??
        (status >= 400 || (!finalSuccess && !requireManual)
            ? (payload['message'] as String? ?? payload['lastError'] as String?)
            : null);

    return SsoResponse(
      success: finalSuccess,
      uid: payload['uid'] as String?,
      token: token,
      appAccessToken: payload['appAccessToken'] as String?,
      lmsLoginUrl: lmsUrl,
      expiresAt: (payload['expiresAt'] as num?)?.toInt(),
      autoSolved: payload['autoSolved'] as bool? ?? false,
      requireManualCaptcha: requireManual,
      sessionToken: sessToken,
      captchaImage: captchaImg,
      error: err,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'uid': uid,
      'token': token,
      'appAccessToken': appAccessToken,
      'lmsLoginUrl': lmsLoginUrl,
      'expiresAt': expiresAt,
      'autoSolved': autoSolved,
      'requireManualCaptcha': requireManualCaptcha,
      'sessionToken': sessionToken,
      'captchaImage': captchaImage,
      'error': error,
    };
  }
}

class AuthSession {
  final String uid;
  final String? password;
  final String sesskey;
  final String moodleSession;
  final String? studentName;
  final String? moodleUserId;
  final DateTime authenticatedAt;

  const AuthSession({
    required this.uid,
    this.password,
    required this.sesskey,
    required this.moodleSession,
    this.studentName,
    this.moodleUserId,
    required this.authenticatedAt,
  });

  bool get isValid => sesskey.isNotEmpty && moodleSession.isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'password': password,
      'sesskey': sesskey,
      'moodleSession': moodleSession,
      'studentName': studentName,
      'moodleUserId': moodleUserId,
      'authenticatedAt': authenticatedAt.toIso8601String(),
    };
  }

  factory AuthSession.fromMap(Map<String, dynamic> map) {
    return AuthSession(
      uid: map['uid'] as String? ?? '',
      password: map['password'] as String?,
      sesskey: map['sesskey'] as String? ?? '',
      moodleSession: map['moodleSession'] as String? ?? '',
      studentName: map['studentName'] as String?,
      moodleUserId: map['moodleUserId'] as String?,
      authenticatedAt: map['authenticatedAt'] != null
          ? DateTime.tryParse(map['authenticatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory AuthSession.fromJson(String source) =>
      AuthSession.fromMap(json.decode(source) as Map<String, dynamic>);

  AuthSession copyWith({
    String? uid,
    String? password,
    String? sesskey,
    String? moodleSession,
    String? studentName,
    String? moodleUserId,
    DateTime? authenticatedAt,
  }) {
    return AuthSession(
      uid: uid ?? this.uid,
      password: password ?? this.password,
      sesskey: sesskey ?? this.sesskey,
      moodleSession: moodleSession ?? this.moodleSession,
      studentName: studentName ?? this.studentName,
      moodleUserId: moodleUserId ?? this.moodleUserId,
      authenticatedAt: authenticatedAt ?? this.authenticatedAt,
    );
  }
}

class AuthState {
  final AuthStatus status;
  final AuthSession? session;
  final String? errorMessage;
  final SsoResponse? pendingCaptcha;
  final String? statusMessage;
  final SsoProgress? progress;
  final List<SsoProgress> progressHistory;

  const AuthState({
    this.status = AuthStatus.initial,
    this.session,
    this.errorMessage,
    this.pendingCaptcha,
    this.statusMessage,
    this.progress,
    this.progressHistory = const [],
  });

  bool get isAuthenticated =>
      (status == AuthStatus.authenticated || status == AuthStatus.reauthenticating) &&
      session != null &&
      session!.isValid;

  bool get isProcessing =>
      status == AuthStatus.connectingGateway || status == AuthStatus.loggingInMoodle;

  AuthState copyWith({
    AuthStatus? status,
    AuthSession? session,
    String? errorMessage,
    SsoResponse? pendingCaptcha,
    String? statusMessage,
    SsoProgress? progress,
    List<SsoProgress>? progressHistory,
    bool clearError = false,
    bool clearProgress = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      session: session ?? this.session,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      pendingCaptcha: pendingCaptcha ?? this.pendingCaptcha,
      statusMessage: statusMessage ?? this.statusMessage,
      progress: clearProgress ? null : (progress ?? this.progress),
      progressHistory: clearProgress ? const [] : (progressHistory ?? this.progressHistory),
    );
  }
}
