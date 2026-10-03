import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/auth_state.dart';

class CookieService {
  static const String _keySession = 'saved_moodle_session';
  static const String _keySesskey = 'saved_moodle_sesskey';
  static const String _keyUid = 'saved_moodle_uid';
  static const String _keyAuthTime = 'saved_moodle_time';
  static const String _keyStudentName = 'saved_student_name';
  static const String _keyMoodleUserId = 'saved_moodle_user_id';
  static const String _keySavedUid = 'saved_user_uid';
  static const String _keySavedPassword = 'saved_user_password';

  Future<void> saveCredentials(String uid, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySavedUid, uid.trim());
    await prefs.setString(_keySavedPassword, password.trim());
  }

  Future<({String uid, String password})?> getSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString(_keySavedUid);
    final password = prefs.getString(_keySavedPassword);
    if (uid != null && uid.isNotEmpty && password != null && password.isNotEmpty) {
      return (uid: uid, password: password);
    }
    return null;
  }

  Future<void> clearSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySavedUid);
    await prefs.remove(_keySavedPassword);
  }

  Future<void> saveSession(AuthSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUid, session.uid);
    await prefs.setString(_keySesskey, session.sesskey);
    await prefs.setString(_keySession, session.moodleSession);
    await prefs.setString(_keyAuthTime, session.authenticatedAt.toIso8601String());
    if (session.studentName != null && session.studentName!.isNotEmpty) {
      await prefs.setString(_keyStudentName, session.studentName!);
    }
    if (session.moodleUserId != null && session.moodleUserId!.isNotEmpty) {
      await prefs.setString(_keyMoodleUserId, session.moodleUserId!);
    }
    if (session.password != null && session.password!.isNotEmpty) {
      await saveCredentials(session.uid, session.password!);
    }
  }

  Future<AuthSession?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString(_keyUid);
    final sesskey = prefs.getString(_keySesskey);
    final moodleSession = prefs.getString(_keySession);
    final authTimeStr = prefs.getString(_keyAuthTime);
    final studentName = prefs.getString(_keyStudentName);
    final moodleUserId = prefs.getString(_keyMoodleUserId);

    if (uid != null && sesskey != null && moodleSession != null) {
      final authTime = authTimeStr != null
          ? DateTime.tryParse(authTimeStr) ?? DateTime.now()
          : DateTime.now();

      // Check if session is older than 24 hours
      if (DateTime.now().difference(authTime).inHours > 24) {
        await clearSession();
        return null;
      }

      final creds = await getSavedCredentials();

      return AuthSession(
        uid: uid,
        password: creds?.password,
        sesskey: sesskey,
        moodleSession: moodleSession,
        studentName: studentName,
        moodleUserId: moodleUserId,
        authenticatedAt: authTime,
      );
    }
    return null;
  }

  Future<void> clearSession({bool clearCredentials = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUid);
    await prefs.remove(_keySesskey);
    await prefs.remove(_keySession);
    await prefs.remove(_keyAuthTime);
    await prefs.remove(_keyStudentName);
    await prefs.remove(_keyMoodleUserId);

    if (clearCredentials) {
      await clearSavedCredentials();
    }
  }
}
