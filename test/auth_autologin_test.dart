import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cuims_unofficial2/core/services/cookie_service.dart';
import 'package:cuims_unofficial2/data/models/auth_state.dart';
import 'package:cuims_unofficial2/ui/screens/auth/login_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CookieService Credentials & Auto-Login Persistence Tests', () {
    test('saveCredentials and getSavedCredentials works properly', () async {
      final cookieService = CookieService();
      expect(await cookieService.getSavedCredentials(), isNull);

      await cookieService.saveCredentials('test_uid_01', 'mock_password_01');
      final creds = await cookieService.getSavedCredentials();

      expect(creds, isNotNull);
      expect(creds!.uid, 'test_uid_01');
      expect(creds.password, 'mock_password_01');
    });

    test('saveSession automatically saves password when present in session', () async {
      final cookieService = CookieService();
      final session = AuthSession(
        uid: 'test_uid_02',
        password: 'mock_password_02',
        sesskey: 'test_sesskey',
        moodleSession: 'test_moodle_session',
        studentName: 'Test Student',
        moodleUserId: '12345',
        authenticatedAt: DateTime.now(),
      );

      await cookieService.saveSession(session);

      final creds = await cookieService.getSavedCredentials();
      expect(creds, isNotNull);
      expect(creds!.uid, 'test_uid_02');
      expect(creds.password, 'mock_password_02');

      final loadedSession = await cookieService.loadSession();
      expect(loadedSession, isNotNull);
      expect(loadedSession!.uid, 'test_uid_02');
      expect(loadedSession.password, 'mock_password_02');
      expect(loadedSession.studentName, 'Test Student');
      expect(loadedSession.moodleUserId, '12345');
    });

    test('When session expires (>24h), session is cleared but saved credentials remain for auto-login', () async {
      final cookieService = CookieService();
      final oldSession = AuthSession(
        uid: 'test_uid_02',
        password: 'mock_password_02',
        sesskey: 'old_sesskey',
        moodleSession: 'old_moodle_session',
        authenticatedAt: DateTime.now().subtract(const Duration(hours: 25)),
      );

      await cookieService.saveSession(oldSession);

      // Loading expired session should return null (session expired)
      final session = await cookieService.loadSession();
      expect(session, isNull);

      // BUT saved credentials must still be present so auto-login can trigger!
      final creds = await cookieService.getSavedCredentials();
      expect(creds, isNotNull);
      expect(creds!.uid, 'test_uid_02');
      expect(creds.password, 'mock_password_02');
    });

    test('clearSession with clearCredentials=true removes both session and saved credentials', () async {
      final cookieService = CookieService();
      await cookieService.saveCredentials('user1', 'pass1');
      await cookieService.saveSession(AuthSession(
        uid: 'user1',
        sesskey: 'sk',
        moodleSession: 'ms',
        authenticatedAt: DateTime.now(),
      ));

      await cookieService.clearSession(clearCredentials: true);

      expect(await cookieService.loadSession(), isNull);
      expect(await cookieService.getSavedCredentials(), isNull);
    });
  });

  group('AuthState Re-authenticating Tests', () {
    test('isAuthenticated is true during reauthenticating if valid session exists', () {
      final session = AuthSession(
        uid: 'test_uid_02',
        sesskey: 'sk',
        moodleSession: 'ms',
        authenticatedAt: DateTime.now(),
      );

      final state = AuthState(
        status: AuthStatus.reauthenticating,
        session: session,
      );

      expect(state.isAuthenticated, true);
    });

    test('isAuthenticated is false when session is null', () {
      const state = AuthState(
        status: AuthStatus.reauthenticating,
        session: null,
      );

      expect(state.isAuthenticated, false);
    });
  });

  group('LoginScreen UI Tests', () {
    testWidgets('LoginScreen does not render sample credentials and uses Enter your UID placeholder', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Sample Creds should NOT be found
      expect(find.text('Sample Creds'), findsNothing);
      expect(find.text('Sample credentials inserted'), findsNothing);

      // University UID label and generic placeholder should exist
      expect(find.text('University UID'), findsOneWidget);
      expect(find.text('Enter your UID'), findsOneWidget);

      // Gateway Config utility should exist
      expect(find.text('Gateway Config'), findsOneWidget);
    });
  });
}
