import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/cookie_service.dart';
import '../../data/models/auth_state.dart';
import '../../data/network/lms_api_client.dart';
import 'app_providers.dart';
import 'settings_provider.dart';

class AuthNotifier extends Notifier<AuthState> {
  LmsApiClient get _apiClient => ref.read(lmsApiClientProvider);
  CookieService get _cookieService => ref.read(cookieServiceProvider);
  bool _isAutoLoggingIn = false;
  CancelToken? _loginCancelToken;

  @override
  AuthState build() {
    _apiClient.onSessionExpired = handleSessionExpired;
    _tryRestoreSession();
    return const AuthState();
  }

  Future<void> _tryRestoreSession() async {
    try {
      final session = await _cookieService.loadSession();
      if (session != null && session.isValid) {
        state = AuthState(
          status: AuthStatus.authenticated,
          session: session,
        );

        // Refresh profile if studentName is missing, empty, or placeholder 'MOOCs'
        if (session.studentName == null ||
            session.studentName!.isEmpty ||
            session.studentName == 'MOOCs' ||
            session.moodleUserId == null) {
          _refreshUserProfile(session);
        }

        // Validate session with Moodle server in background
        final isValid = await _apiClient.validateSession(session);
        if (!isValid) {
          ref.read(logServiceProvider).warning('AUTH', 'Saved session expired on server. Auto-logging in...');
          await handleSessionExpired();
        }
      } else {
        // No active session: attempt auto-login using saved credentials
        final creds = await _cookieService.getSavedCredentials();
        if (creds != null) {
          ref.read(logServiceProvider).info('AUTH', 'No session found. Auto-logging in with saved credentials...');
          await autoLogin();
        }
      }
    } catch (e) {
      ref.read(logServiceProvider).error('AUTH', 'Error restoring session: $e');
    }
  }

  Future<void> _refreshUserProfile(AuthSession session) async {
    try {
      final profile = await _apiClient.fetchUserProfile(session);
      if (profile.name != null || profile.userId != null) {
        final updated = session.copyWith(
          studentName: profile.name ?? session.studentName,
          moodleUserId: profile.userId ?? session.moodleUserId,
        );
        await _cookieService.saveSession(updated);
        state = state.copyWith(session: updated);
      }
    } catch (_) {}
  }

  Future<void> refreshUserProfile() async {
    if (state.session != null && state.session!.isValid) {
      await _refreshUserProfile(state.session!);
    }
  }

  Future<bool> autoLogin({bool isBackground = false}) async {
    final creds = await _cookieService.getSavedCredentials();
    if (creds == null) return false;

    return login(
      uid: creds.uid,
      password: creds.password,
      isAutoLogin: true,
      isBackground: isBackground,
    );
  }

  Future<void> handleSessionExpired() async {
    if (_isAutoLoggingIn) return;
    if (state.status == AuthStatus.connectingGateway ||
        state.status == AuthStatus.loggingInMoodle) {
      return;
    }

    _isAutoLoggingIn = true;
    try {
      ref.read(logServiceProvider).info('AUTH', 'Session expired. Triggering auto-login...');
      final success = await autoLogin(isBackground: state.isAuthenticated);
      if (!success && state.status != AuthStatus.captchaRequired) {
        // Auto-login failed and no captcha pending: return to login screen
        await _cookieService.clearSession();
        state = const AuthState(status: AuthStatus.initial);
      }
    } finally {
      _isAutoLoggingIn = false;
    }
  }

  void cancelLogin() {
    _loginCancelToken?.cancel('User cancelled login');
    _loginCancelToken = null;
    state = state.copyWith(
      status: AuthStatus.initial,
      clearError: true,
      clearProgress: true,
      statusMessage: null,
    );
  }

  Future<bool> login({
    required String uid,
    required String password,
    bool isAutoLogin = false,
    bool isBackground = false,
  }) async {
    // Prevent duplicate submission while a request is already active
    if (state.isProcessing && _loginCancelToken != null && !_loginCancelToken!.isCancelled) {
      return false;
    }

    _loginCancelToken?.cancel('New login initiated');
    final cancelToken = CancelToken();
    _loginCancelToken = cancelToken;

    final settings = ref.read(settingsProvider);
    final apiToken = settings.ssoApiToken.isNotEmpty ? settings.ssoApiToken : 'dont_use_please';

    state = state.copyWith(
      status: isBackground ? AuthStatus.reauthenticating : AuthStatus.connectingGateway,
      statusMessage: isAutoLogin
          ? 'Session expired. Automatically signing in...'
          : 'Connecting to Cloud SSO Gateway...',
      clearError: true,
      clearProgress: true,
    );

    try {
      final ssoResp = await _apiClient.loginSso(
        uid: uid,
        password: password,
        apiToken: apiToken,
        gatewayUrl: settings.ssoGatewayUrl,
        cancelToken: cancelToken,
        onProgress: (progress) {
          if (cancelToken.isCancelled) return;
          state = state.copyWith(
            progress: progress,
            progressHistory: [...state.progressHistory, progress],
            statusMessage: progress.message,
          );
        },
        onStatusUpdate: (msg) {
          if (cancelToken.isCancelled) return;
          state = state.copyWith(statusMessage: msg);
        },
      );

      if (cancelToken.isCancelled) {
        return false;
      }

      // State 1: Direct Success
      if (ssoResp.success && ssoResp.lmsLoginUrl != null) {
        state = state.copyWith(
          status: isBackground ? AuthStatus.reauthenticating : AuthStatus.loggingInMoodle,
          statusMessage: 'LMS SSO Authorization Successful! Redirecting...',
        );

        final session = await _apiClient.completeMoodleLogin(
          uid: uid,
          password: password,
          lmsLoginUrl: ssoResp.lmsLoginUrl!,
          onStatusUpdate: (msg) {
            state = state.copyWith(statusMessage: msg);
          },
        );

        await _cookieService.saveCredentials(uid, password);
        await _cookieService.saveSession(session);

        state = AuthState(
          status: AuthStatus.authenticated,
          session: session,
        );
        return true;
      }

      // State 2: Manual Captcha Required
      if (ssoResp.requireManualCaptcha) {
        // If no usable image or session exists (e.g. CUIMS was unavailable), show retry option
        if (ssoResp.captchaImage == null || ssoResp.sessionToken == null) {
          state = state.copyWith(
            status: AuthStatus.error,
            errorMessage: ssoResp.error ?? 'CAPTCHA verification needed, but portal image is unavailable. Please retry.',
            clearProgress: true,
          );
          return false;
        }

        state = state.copyWith(
          status: AuthStatus.captchaRequired,
          pendingCaptcha: ssoResp,
          statusMessage: 'Manual Captcha Verification Required',
        );
        return false;
      }

      // State 4: Explicit Failure
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: ssoResp.error ?? 'Authentication failed. Please verify credentials.',
        clearProgress: true,
      );
      return false;
    } catch (e) {
      if (cancelToken.isCancelled) {
        return false;
      }
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
        clearProgress: true,
      );
      return false;
    } finally {
      if (_loginCancelToken == cancelToken) {
        _loginCancelToken = null;
      }
    }
  }

  Future<bool> submitCaptcha({
    required String uid,
    required String password,
    required String captcha,
  }) async {
    final sessionToken = state.pendingCaptcha?.sessionToken;
    if (sessionToken == null) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Captcha session expired. Please log in again.',
        clearProgress: true,
      );
      return false;
    }

    _loginCancelToken?.cancel('New captcha submission initiated');
    final cancelToken = CancelToken();
    _loginCancelToken = cancelToken;

    final settings = ref.read(settingsProvider);
    final apiToken = settings.ssoApiToken.isNotEmpty ? settings.ssoApiToken : 'dont_use_please';

    state = state.copyWith(
      status: AuthStatus.connectingGateway,
      statusMessage: 'Verifying Captcha with Gateway...',
      clearError: true,
      clearProgress: true,
    );

    try {
      final ssoResp = await _apiClient.submitCaptcha(
        uid: uid,
        password: password,
        captcha: captcha,
        sessionToken: sessionToken,
        apiToken: apiToken,
        gatewayUrl: settings.ssoGatewayUrl,
        cancelToken: cancelToken,
        onProgress: (progress) {
          if (cancelToken.isCancelled) return;
          state = state.copyWith(
            progress: progress,
            progressHistory: [...state.progressHistory, progress],
            statusMessage: progress.message,
          );
        },
        onStatusUpdate: (msg) {
          if (cancelToken.isCancelled) return;
          state = state.copyWith(statusMessage: msg);
        },
      );

      if (cancelToken.isCancelled) {
        return false;
      }

      if (ssoResp.success && ssoResp.lmsLoginUrl != null) {
        state = state.copyWith(
          status: AuthStatus.loggingInMoodle,
          statusMessage: 'Captcha Verified! Establishing Moodle Session...',
        );

        final session = await _apiClient.completeMoodleLogin(
          uid: uid,
          password: password,
          lmsLoginUrl: ssoResp.lmsLoginUrl!,
        );

        await _cookieService.saveCredentials(uid, password);
        await _cookieService.saveSession(session);

        state = AuthState(
          status: AuthStatus.authenticated,
          session: session,
        );
        return true;
      }

      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: ssoResp.error ?? 'Incorrect captcha. Please try again.',
        clearProgress: true,
      );
      return false;
    } catch (e) {
      if (cancelToken.isCancelled) {
        return false;
      }
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
        clearProgress: true,
      );
      return false;
    } finally {
      if (_loginCancelToken == cancelToken) {
        _loginCancelToken = null;
      }
    }
  }

  void cancelCaptcha() {
    _loginCancelToken?.cancel('User cancelled captcha');
    _loginCancelToken = null;
    state = state.copyWith(
      status: AuthStatus.initial,
      pendingCaptcha: null,
      clearError: true,
      clearProgress: true,
    );
  }

  Future<void> logout() async {
    _loginCancelToken?.cancel('User logged out');
    _loginCancelToken = null;
    await _cookieService.clearSession(clearCredentials: true);
    state = const AuthState(status: AuthStatus.initial);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
