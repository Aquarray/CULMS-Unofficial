import 'dart:convert';

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
    return SsoResponse(
      success: json['success'] as bool? ?? false,
      uid: json['uid'] as String?,
      token: json['token'] as String?,
      appAccessToken: json['appAccessToken'] as String?,
      lmsLoginUrl: json['lmsLoginUrl'] as String?,
      expiresAt: (json['expiresAt'] as num?)?.toInt(),
      autoSolved: json['autoSolved'] as bool? ?? false,
      requireManualCaptcha: json['requireManualCaptcha'] as bool? ?? false,
      sessionToken: json['sessionToken'] as String?,
      captchaImage: json['captchaImage'] as String?,
      error: json['error'] as String?,
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

  const AuthState({
    this.status = AuthStatus.initial,
    this.session,
    this.errorMessage,
    this.pendingCaptcha,
    this.statusMessage,
  });

  bool get isAuthenticated =>
      (status == AuthStatus.authenticated || status == AuthStatus.reauthenticating) &&
      session != null &&
      session!.isValid;

  AuthState copyWith({
    AuthStatus? status,
    AuthSession? session,
    String? errorMessage,
    SsoResponse? pendingCaptcha,
    String? statusMessage,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      session: session ?? this.session,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      pendingCaptcha: pendingCaptcha ?? this.pendingCaptcha,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }
}
