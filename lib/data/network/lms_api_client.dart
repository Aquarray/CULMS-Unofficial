import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import '../../core/config/app_constants.dart';
import '../../core/services/cache_service.dart';
import '../../core/services/log_service.dart';
import '../models/assignment.dart';
import '../models/auth_state.dart';
import '../models/calendar_event.dart';
import '../models/course.dart';
import '../models/course_content.dart';

class LmsApiClient {
  final Dio dio;
  final CacheService cacheService;
  final LogService? logService;
  void Function()? onSessionExpired;

  LmsApiClient({
    required this.dio,
    required this.cacheService,
    this.logService,
    this.onSessionExpired,
  });

  /// Step 2.1 & 2.2: Initial Login Payload and Delay Handling
  Future<SsoResponse> loginSso({
    required String uid,
    required String password,
    String? apiToken,
    String? gatewayUrl,
    void Function(String message)? onStatusUpdate,
  }) async {
    final endpoint = (gatewayUrl != null && gatewayUrl.isNotEmpty)
        ? gatewayUrl
        : AppConstants.defaultSsoUrl;
    final token = (apiToken != null && apiToken.isNotEmpty)
        ? apiToken
        : 'dont_use_please';

    onStatusUpdate?.call('Connecting to Cloud SSO Gateway...');

    try {
      final response = await dio.post(
        endpoint,
        data: {
          'uid': uid.trim(),
          'password': password.trim(),
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          // Generous timeout to accommodate Vercel gateway 5-second processing constraint
          sendTimeout: const Duration(seconds: 40),
          receiveTimeout: const Duration(seconds: 40),
        ),
      );

      final data = response.data is String
          ? json.decode(response.data as String) as Map<String, dynamic>
          : response.data as Map<String, dynamic>;

      return SsoResponse.fromJson(data);
    } on DioException catch (e) {
      if (e.response?.data != null) {
        try {
          final data = e.response!.data is String
              ? json.decode(e.response!.data as String) as Map<String, dynamic>
              : e.response!.data as Map<String, dynamic>;
          return SsoResponse.fromJson(data);
        } catch (_) {}
      }
      return SsoResponse(
        success: false,
        error: e.message ?? 'Network error connecting to SSO gateway',
      );
    } catch (e) {
      return SsoResponse(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Step 2.2 State 3: Captcha Submission
  Future<SsoResponse> submitCaptcha({
    required String uid,
    required String password,
    required String captcha,
    required String sessionToken,
    String? apiToken,
    String? gatewayUrl,
    void Function(String message)? onStatusUpdate,
  }) async {
    final endpoint = (gatewayUrl != null && gatewayUrl.isNotEmpty)
        ? gatewayUrl
        : AppConstants.defaultSsoUrl;
    final token = (apiToken != null && apiToken.isNotEmpty)
        ? apiToken
        : 'dont_use_please';

    onStatusUpdate?.call('Verifying captcha with SSO Gateway...');

    try {
      final response = await dio.post(
        endpoint,
        data: {
          'uid': uid.trim(),
          'password': password.trim(),
          'captcha': captcha.trim(),
          'sessionToken': sessionToken,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          sendTimeout: const Duration(seconds: 40),
          receiveTimeout: const Duration(seconds: 40),
        ),
      );

      final data = response.data is String
          ? json.decode(response.data as String) as Map<String, dynamic>
          : response.data as Map<String, dynamic>;

      return SsoResponse.fromJson(data);
    } on DioException catch (e) {
      if (e.response?.data != null) {
        try {
          final data = e.response!.data is String
              ? json.decode(e.response!.data as String) as Map<String, dynamic>
              : e.response!.data as Map<String, dynamic>;
          return SsoResponse.fromJson(data);
        } catch (_) {}
      }
      return SsoResponse(
        success: false,
        error: e.message ?? 'Network error during captcha submission',
      );
    } catch (e) {
      return SsoResponse(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Step 2.2 State 1: Follow Moodle autologin URL, extract MoodleSession cookie and sesskey
  Future<AuthSession> completeMoodleLogin({
    required String uid,
    String? password,
    required String lmsLoginUrl,
    void Function(String message)? onStatusUpdate,
  }) async {
    onStatusUpdate?.call('LMS SSO Authorization Successful! Initializing Moodle Session...');
    logService?.info('AUTH', 'Starting Moodle session initialization from: $lmsLoginUrl');

    String? moodleSession;
    String? sesskey;

    // 1. Hit autologin URL with followRedirects: false to capture Set-Cookie from 302/303 redirect
    final loginResp = await dio.get<String>(
      lmsLoginUrl,
      options: Options(
        followRedirects: false,
        validateStatus: (status) => status != null && status < 500,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36',
        },
      ),
    );

    logService?.http(
      'AUTH',
      'Autologin response status: ${loginResp.statusCode}',
      'Headers: ${loginResp.headers.map}',
    );

    // Extract cookies from response headers
    final setCookieHeaders = loginResp.headers['set-cookie'] ?? [];
    for (final header in setCookieHeaders) {
      if (header.contains('MoodleSession=')) {
        final match = RegExp(r'MoodleSession=([^;]+)').firstMatch(header);
        if (match != null) {
          moodleSession = match.group(1);
          logService?.info('AUTH', 'Found MoodleSession cookie: $moodleSession');
          break;
        }
      }
    }

    // Determine redirect destination
    String targetUrl = loginResp.headers.value('location') ?? 'https://lms.cuchd.in/my/';
    if (!targetUrl.startsWith('http')) {
      targetUrl = 'https://lms.cuchd.in$targetUrl';
    }

    logService?.info('AUTH', 'Visiting target page for sesskey: $targetUrl');

    // 2. Fetch destination page with the established MoodleSession cookie
    final homeResp = await dio.get<String>(
      targetUrl,
      options: Options(
        followRedirects: true,
        maxRedirects: 5,
        headers: {
          if (moodleSession != null) 'Cookie': 'MoodleSession=$moodleSession',
          'User-Agent': 'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36',
        },
      ),
    );

    // Check if redirect response set any additional cookies
    if (moodleSession == null) {
      final redirCookies = homeResp.headers['set-cookie'] ?? [];
      for (final header in redirCookies) {
        if (header.contains('MoodleSession=')) {
          final match = RegExp(r'MoodleSession=([^;]+)').firstMatch(header);
          if (match != null) {
            moodleSession = match.group(1);
            break;
          }
        }
      }
    }

    final html = homeResp.data ?? '';

    // Extract sesskey from HTML
    // 1. JSON pattern: "sesskey":"7F45XfTTeR"
    var sesskeyMatch = RegExp(r'"sesskey":"([a-zA-Z0-9]+)"').firstMatch(html);
    if (sesskeyMatch != null) {
      sesskey = sesskeyMatch.group(1);
    }

    // 2. Input pattern: <input type="hidden" name="sesskey" value="..." />
    if (sesskey == null) {
      sesskeyMatch = RegExp(r'''name=["']sesskey["']\s+value=["']([a-zA-Z0-9]+)["']''').firstMatch(html);
      if (sesskeyMatch != null) {
        sesskey = sesskeyMatch.group(1);
      }
    }

    // 3. Fallback: Query /my/ explicitly if first target was root /
    if (sesskey == null && moodleSession != null) {
      try {
        logService?.info('AUTH', 'Fallback: Querying /my/ explicitly for sesskey');
        final myPageResponse = await dio.get<String>(
          'https://lms.cuchd.in/my/',
          options: Options(
            headers: {
              'Cookie': 'MoodleSession=$moodleSession',
              'User-Agent': 'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36',
            },
          ),
        );
        final myHtml = myPageResponse.data ?? '';
        sesskeyMatch = RegExp(r'"sesskey":"([a-zA-Z0-9]+)"').firstMatch(myHtml);
        if (sesskeyMatch != null) {
          sesskey = sesskeyMatch.group(1);
        }
      } catch (e) {
        logService?.error('AUTH', 'Error querying /my/ for sesskey', e.toString());
      }
    }

    logService?.info(
      'AUTH',
      'Moodle session resolved',
      'MoodleSession: $moodleSession\nSesskey: $sesskey',
    );

    if (moodleSession == null || sesskey == null) {
      final err = 'Failed to establish Moodle session or retrieve sesskey. (Session: $moodleSession, Sesskey: $sesskey)';
      logService?.error('AUTH', err);
      throw Exception(err);
    }

    // Try extracting student display name & moodleUserId
    String? studentName;
    String? moodleUserId;
    try {
      final uidMatch = RegExp(r'"userId":\s*(\d+)').firstMatch(html) ??
          RegExp(r'data-userid=["''](\d+)["'']').firstMatch(html) ??
          RegExp(r'user/profile\.php\?id=(\d+)').firstMatch(html);
      if (uidMatch != null) {
        moodleUserId = uidMatch.group(1);
      }

      // Check logininfo: "You are logged in as <a href=...>NAME</a>"
      final loginInfoMatch = RegExp(r'user/profile\.php\?id=\d+["'']>([^<]+)</a>').firstMatch(html);
      if (loginInfoMatch != null && loginInfoMatch.group(1)!.trim().isNotEmpty) {
        studentName = loginInfoMatch.group(1)!.trim();
      }
    } catch (_) {}

    // If studentName is missing or invalid, fetch directly from user profile
    if (studentName == null || studentName.isEmpty || studentName == 'MOOCs') {
      try {
        final profile = await fetchUserProfile(
          AuthSession(
            uid: uid,
            password: password,
            sesskey: sesskey,
            moodleSession: moodleSession,
            authenticatedAt: DateTime.now(),
          ),
          userId: moodleUserId,
        );
        if (profile.name != null && profile.name!.isNotEmpty) {
          studentName = profile.name;
        }
        if (profile.userId != null && profile.userId!.isNotEmpty) {
          moodleUserId = profile.userId;
        }
      } catch (e) {
        logService?.error('AUTH', 'Failed to fetch profile during login: $e');
      }
    }

    return AuthSession(
      uid: uid,
      password: password,
      sesskey: sesskey,
      moodleSession: moodleSession,
      studentName: studentName,
      moodleUserId: moodleUserId,
      authenticatedAt: DateTime.now(),
    );
  }

  /// Checks if current Moodle session cookie is still valid on the server.
  Future<bool> validateSession(AuthSession session) async {
    try {
      final response = await dio.get<String>(
        '${AppConstants.defaultLmsBaseUrl}/my/',
        options: Options(
          followRedirects: false,
          validateStatus: (status) => status != null && status < 500,
          headers: {
            'Cookie': 'MoodleSession=${session.moodleSession}',
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36',
          },
        ),
      );

      // A redirect (302/303) to login/index.php means session expired
      if (response.statusCode == 302 || response.statusCode == 303) {
        final location = response.headers.value('location') ?? '';
        if (location.contains('login')) {
          logService?.warning('AUTH', 'Session expired: redirected to $location');
          return false;
        }
      }

      if (response.statusCode == 200) {
        final data = response.data ?? '';
        if (data.contains('login/index.php') && !data.contains('login/logout.php')) {
          logService?.warning('AUTH', 'Session expired: page contains login form');
          return false;
        }
        return true;
      }
      return false;
    } catch (e) {
      logService?.error('AUTH', 'Error validating session: $e');
      // In case of offline/network failure, keep local session
      return true;
    }
  }

  void _checkSessionExpiry(dynamic responseData) {
    if (responseData == null) return;
    try {
      final str = responseData is String ? responseData : json.encode(responseData);
      if (str.contains('servicerequireslogin') ||
          str.contains('"errorcode":"servicerequireslogin"') ||
          str.contains('"errorcode":"sessionerror"') ||
          (str.contains('login/index.php') && !str.contains('login/logout.php') && str.contains('id="login"'))) {
        logService?.warning('API', 'Session expiry pattern detected in LMS response');
        onSessionExpired?.call();
      }
    } catch (_) {}
  }

  /// Fetches the user profile (user ID and student display name) from Moodle.
  /// 1. Finds the user ID from / if not already known.
  /// 2. Queries https://lms.cuchd.in/user/profile.php?id=<id> (or /user/profile.php).
  /// 3. Extracts the student name from the profile heading / page title.
  Future<({String? name, String? userId})> fetchUserProfile(
    AuthSession session, {
    String? userId,
  }) async {
    String? resolvedUserId = userId ?? session.moodleUserId;

    // Step 1: If userId is unknown, fetch / to extract it
    if (resolvedUserId == null || resolvedUserId.isEmpty) {
      try {
        logService?.info('AUTH', 'Fetching / to resolve Moodle userId');
        final rootResp = await dio.get<String>(
          '${AppConstants.defaultLmsBaseUrl}/',
          options: Options(
            validateStatus: (status) => status != null && status < 500,
            headers: {
              'Cookie': 'MoodleSession=${session.moodleSession}',
              'User-Agent':
                  'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36',
            },
          ),
        );
        if (rootResp.data != null) {
          final rHtml = rootResp.data!;
          final uidMatch = RegExp(r'"userId":\s*(\d+)').firstMatch(rHtml) ??
              RegExp(r'data-userid=["''](\d+)["'']').firstMatch(rHtml) ??
              RegExp(r'user/profile\.php\?id=(\d+)').firstMatch(rHtml);
          if (uidMatch != null) {
            resolvedUserId = uidMatch.group(1);
          }
        }
      } catch (e) {
        logService?.error('AUTH', 'Failed to fetch / for userId: $e');
      }
    }

    // Step 2: Fetch profile page using id or default profile.php
    String? studentName;
    try {
      final profileUrl = resolvedUserId != null && resolvedUserId.isNotEmpty
          ? '${AppConstants.defaultLmsBaseUrl}/user/profile.php?id=$resolvedUserId'
          : '${AppConstants.defaultLmsBaseUrl}/user/profile.php';

      logService?.info('AUTH', 'Fetching user profile from: $profileUrl');
      final profResp = await dio.get<String>(
        profileUrl,
        options: Options(
          validateStatus: (status) => status != null && status < 500,
          headers: {
            'Cookie': 'MoodleSession=${session.moodleSession}',
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36',
          },
        ),
      );

      if (profResp.data != null) {
        final doc = html_parser.parse(profResp.data!);
        final h1 = doc.querySelector(
          '.page-header-headings h1, .userprofile .page-context-header h1, #page-header h1, h1',
        );
        if (h1 != null && h1.text.trim().isNotEmpty) {
          studentName = h1.text.trim();
        } else {
          final title = doc.querySelector('title')?.text.trim() ?? '';
          final tMatch = RegExp(r'^([^:]+):').firstMatch(title);
          if (tMatch != null) {
            studentName = tMatch.group(1)?.trim();
          }
        }

        // Also extract userId from profile page if not yet resolved
        if (resolvedUserId == null || resolvedUserId.isEmpty) {
          final uidMatch = RegExp(r'"userId":\s*(\d+)').firstMatch(profResp.data!) ??
              RegExp(r'data-userid=["''](\d+)["'']').firstMatch(profResp.data!);
          if (uidMatch != null) {
            resolvedUserId = uidMatch.group(1);
          }
        }

        logService?.info(
          'AUTH',
          'Profile resolved: name="$studentName", userId="$resolvedUserId"',
        );
      }
    } catch (e) {
      logService?.error('AUTH', 'Failed to fetch user profile: $e');
    }

    return (name: studentName, userId: resolvedUserId);
  }

  /// 5.1 Fetching Enrolled Courses (with caching to limit requests)
  Future<List<Course>> getEnrolledCourses(
    AuthSession session, {
    bool forceRefresh = false,
  }) async {
    const cacheKey = AppConstants.keyCachedCourses;

    // Check offline cache first
    if (!forceRefresh) {
      final cachedJson = await cacheService.getJson<String>(cacheKey);
      if (cachedJson != null) {
        final courses = Course.fromJsonList(cachedJson);
        if (courses.isNotEmpty) {
          return courses;
        }
      }
    }

    final url =
        '${AppConstants.defaultLmsBaseUrl}/lib/ajax/service.php?sesskey=${session.sesskey}&info=core_course_get_enrolled_courses_by_timeline_classification';

    final payload = [
      {
        "index": 0,
        "methodname": "core_course_get_enrolled_courses_by_timeline_classification",
        "args": {
          "offset": 0,
          "limit": 30,
          "classification": "all",
          "sort": "fullname",
          "customfieldname": "",
          "customfieldvalue": "",
          "requiredfields": [
            "id",
            "fullname",
            "shortname",
            "showcoursecategory",
            "visible",
            "enddate",
            "courseimage",
            "progress"
          ]
        }
      }
    ];

    final response = await dio.post<dynamic>(
      url,
      data: payload,
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Cookie': 'MoodleSession=${session.moodleSession}',
          'User-Agent': 'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36',
        },
      ),
    );

    _checkSessionExpiry(response.data);

    final rawString = response.data is String
        ? response.data as String
        : json.encode(response.data);

    // Save to cache
    await cacheService.putJson(cacheKey, rawString);

    return Course.fromJsonList(rawString);
  }

  /// 5.2 Fetching Notifications / Calendar Events (with dynamic timestamps and caching)
  Future<List<LmsCalendarEvent>> getTimelineEvents(
    AuthSession session, {
    bool forceRefresh = false,
  }) async {
    const cacheKey = AppConstants.keyCachedEvents;

    if (!forceRefresh) {
      final cachedJson = await cacheService.getJson<String>(cacheKey);
      if (cachedJson != null) {
        final events = LmsCalendarEvent.fromJsonList(cachedJson);
        if (events.isNotEmpty) {
          return events;
        }
      }
    }

    final now = DateTime.now();
    // Dynamic timestamps: 2 days back to 45 days forward
    final timesortFrom = now.subtract(const Duration(days: 2)).millisecondsSinceEpoch ~/ 1000;
    final timesortTo = now.add(const Duration(days: 45)).millisecondsSinceEpoch ~/ 1000;

    final url =
        '${AppConstants.defaultLmsBaseUrl}/lib/ajax/service.php?sesskey=${session.sesskey}&info=core_calendar_get_action_events_by_timesort';

    final payload = [
      {
        "index": 0,
        "methodname": "core_calendar_get_action_events_by_timesort",
        "args": {
          "limitnum": 15,
          "timesortfrom": timesortFrom,
          "timesortto": timesortTo,
          "limittononsuspendedevents": true
        }
      }
    ];

    final response = await dio.post<dynamic>(
      url,
      data: payload,
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Cookie': 'MoodleSession=${session.moodleSession}',
          'User-Agent': 'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36',
        },
      ),
    );

    _checkSessionExpiry(response.data);

    final rawString = response.data is String
        ? response.data as String
        : json.encode(response.data);

    // Save to cache
    await cacheService.putJson(cacheKey, rawString);

    return LmsCalendarEvent.fromJsonList(rawString);
  }

  /// Fetch and parse course units & activities from Moodle course page
  Future<List<CourseUnit>> getCourseUnits(
    int courseId,
    AuthSession session, {
    bool forceRefresh = false,
  }) async {
    final cacheKey = '${AppConstants.keyCourseContentPrefix}$courseId';

    if (!forceRefresh) {
      final cached = await cacheService.getJson<List<dynamic>>(cacheKey);
      if (cached != null) {
        return cached.map((e) => CourseUnit.fromJson(e as Map<String, dynamic>)).toList();
      }
    }

    // 1. Try modern Moodle Course Format State API (core_courseformat_get_state)
    try {
      final stateUrl = '${AppConstants.defaultLmsBaseUrl}/lib/ajax/service.php'
          '?sesskey=${session.sesskey}&info=core_courseformat_get_state';

      final response = await dio.post<dynamic>(
        stateUrl,
        data: [
          {
            "index": 0,
            "methodname": "core_courseformat_get_state",
            "args": {"courseid": courseId}
          }
        ],
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Cookie': 'MoodleSession=${session.moodleSession}',
            'X-Requested-With': 'XMLHttpRequest',
            'User-Agent': 'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36',
          },
        ),
      );

      final raw = response.data;
      final List<dynamic> list = raw is String ? json.decode(raw) as List : raw as List;

      if (list.isNotEmpty && list[0]['error'] == false && list[0]['data'] != null) {
        final state = json.decode(list[0]['data'] as String) as Map<String, dynamic>;
        final sections = (state['section'] as List? ?? []);
        final cms = (state['cm'] as List? ?? []);

        final cmMap = <String, Map<String, dynamic>>{};
        for (final item in cms) {
          final map = item as Map<String, dynamic>;
          cmMap[map['id'].toString()] = map;
        }

        final units = <CourseUnit>[];
        for (final sec in sections) {
          final secMap = sec as Map<String, dynamic>;
          final cmList = (secMap['cmlist'] as List? ?? []).map((e) => e.toString()).toList();

          final activities = <CourseActivity>[];
          for (final cmId in cmList) {
            final cm = cmMap[cmId];
            if (cm != null && cm['visible'] == true) {
              final module = (cm['module'] as String? ?? 'resource').toLowerCase();
              String iconType = 'file';
              String typeName = cm['modname'] as String? ?? 'Resource';

              if (module == 'page') {
                iconType = 'page';
                typeName = 'Reading Page';
              } else if (module == 'folder') {
                iconType = 'folder';
                typeName = 'Folder';
              } else if (module == 'quiz') {
                iconType = 'quiz';
                typeName = 'Quiz / Test';
              } else if (module == 'forum') {
                iconType = 'forum';
                typeName = 'Announcements';
              } else if (module == 'assign') {
                iconType = 'assign';
                typeName = 'Assignment';
              } else if (module == 'url') {
                iconType = 'url';
                typeName = 'Live Session Link';
              }

              var actUrl = cm['url'] as String? ?? '';
              if (actUrl.isEmpty && cm['id'] != null) {
                actUrl = '${AppConstants.defaultLmsBaseUrl}/mod/$module/view.php?id=${cm['id']}';
              }

              activities.add(CourseActivity(
                id: cm['id'].toString(),
                name: cm['name'] as String? ?? 'Activity',
                typeName: typeName,
                url: actUrl,
                iconType: iconType,
              ));
            }
          }

          final secNum = (secMap['number'] as num?)?.toInt() ?? 0;
          final title = (secMap['title'] as String?)?.trim() ?? 'Section $secNum';
          final sectionUrl = (secMap['sectionurl'] as String?)?.isNotEmpty == true
              ? secMap['sectionurl'] as String
              : '${AppConstants.defaultLmsBaseUrl}/course/view.php?id=$courseId&section=$secNum';

          units.add(CourseUnit(
            id: secMap['id'].toString(),
            title: title,
            summary: secMap['summary'] as String?,
            sectionUrl: sectionUrl,
            sectionNumber: secNum,
            category: CourseUnit.resolveCategory(title, secNum),
            parentUnit: CourseUnit.resolveParentUnit(title, secNum),
            activities: activities,
          ));
        }

        if (units.isNotEmpty) {
          await cacheService.putJson(cacheKey, units.map((u) => u.toJson()).toList());
          return units;
        }
      }
    } catch (e) {
      logService?.warning('COURSES', 'core_courseformat_get_state fallback to HTML: $e');
    }

    // 2. Fallback: Parse HTML of course page directly
    final url = '${AppConstants.defaultLmsBaseUrl}/course/view.php?id=$courseId';
    final response = await dio.get<String>(
      url,
      options: Options(
        headers: {
          'Cookie': 'MoodleSession=${session.moodleSession}',
          'User-Agent': 'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36',
        },
      ),
    );

    final html = response.data ?? '';
    final doc = html_parser.parse(html);
    final units = <CourseUnit>[];

    // Find all sections
    final sectionElements = doc.querySelectorAll('li.section, .course-section, .sectionname');

    if (sectionElements.isNotEmpty) {
      for (int i = 0; i < sectionElements.length; i++) {
        final sec = sectionElements[i];
        final title = sec.querySelector('.sectionname, h3, h4')?.text.trim() ?? 'Unit ${i + 1}';
        final summary = sec.querySelector('.summary, .content-summary')?.text.trim();

        final activities = <CourseActivity>[];
        final activityCards = sec.querySelectorAll('.activity-item, li.activity');
        for (final act in activityCards) {
          final link = act.querySelector('a.aalink, a.stretched-link, a');
          final name = act.querySelector('.instancename')?.text.replaceAll(RegExp(r'\s+'), ' ').trim() ??
              link?.text.trim() ??
              'Activity';
          final href = link?.attributes['href'] ?? '';
          var typeName = act.querySelector('.accesshide')?.text.trim() ?? 'Resource';

          String iconType = 'file';
          if (href.contains('mod/resource')) iconType = 'file';
          if (href.contains('mod/folder')) {
            iconType = 'folder';
            typeName = 'Folder';
          }
          if (href.contains('mod/page')) {
            iconType = 'page';
            typeName = 'Reading Page';
          }
          if (href.contains('mod/quiz')) {
            iconType = 'quiz';
            typeName = 'Quiz / Test';
          }
          if (href.contains('mod/forum')) {
            iconType = 'forum';
            typeName = 'Announcements';
          }
          if (href.contains('mod/assign')) {
            iconType = 'assign';
            typeName = 'Assignment';
          }
          if (href.contains('mod/url')) {
            iconType = 'url';
            typeName = 'Live Session Link';
          }

          if (href.isNotEmpty) {
            activities.add(CourseActivity(
              id: '${courseId}_${activities.length}',
              name: name,
              typeName: typeName,
              url: href,
              iconType: iconType,
            ));
          }
        }

        if (activities.isNotEmpty || title.isNotEmpty) {
          units.add(CourseUnit(
            id: 'sec_$i',
            title: title.isEmpty ? 'General Information' : title,
            summary: summary,
            sectionUrl: '$url&section=$i',
            sectionNumber: i,
            category: CourseUnit.resolveCategory(title, i),
            parentUnit: CourseUnit.resolveParentUnit(title, i),
            activities: activities,
          ));
        }
      }
    }

    // Fallback: If section parser returned empty, extract all activity items across the page
    if (units.isEmpty) {
      final allActivities = <CourseActivity>[];
      final activityCards = doc.querySelectorAll('.activity-item, li.activity');
      for (final act in activityCards) {
        final link = act.querySelector('a.aalink, a.stretched-link, a');
        final name = act.querySelector('.instancename')?.text.replaceAll(RegExp(r'\s+'), ' ').trim() ??
            link?.text.trim() ??
            '';
        final href = link?.attributes['href'] ?? '';
        final typeName = act.querySelector('.accesshide')?.text.trim() ?? 'Resource';

        if (href.isNotEmpty && name.isNotEmpty) {
          String iconType = 'file';
          if (href.contains('mod/resource')) iconType = 'file';
          if (href.contains('mod/folder')) iconType = 'folder';
          if (href.contains('mod/page')) iconType = 'page';
          if (href.contains('mod/quiz')) iconType = 'quiz';

          allActivities.add(CourseActivity(
            id: '${courseId}_${allActivities.length}',
            name: name,
            typeName: typeName,
            url: href,
            iconType: iconType,
          ));
        }
      }

      units.add(CourseUnit(
        id: 'sec_all',
        title: 'Course Materials',
        activities: allActivities,
      ));
    }

    // Cache parsed units
    await cacheService.putJson(cacheKey, units.map((u) => u.toJson()).toList());
    return units;
  }

  /// Invalidate cached units for a specific course
  Future<void> clearCourseUnitsCache(int courseId) async {
    final cacheKey = '${AppConstants.keyCourseContentPrefix}$courseId';
    await cacheService.remove(cacheKey);
  }

  /// Dynamic Extraction Logic from Section 6 of README.md:
  /// Handles both Single Document Viewer (Resource View) and Folder/Directory Explorer (Folder View)
  Future<LmsExtractedContent> extractContent({
    required String url,
    required AuthSession session,
  }) async {
    final cacheKey = 'extracted_${url.hashCode}';
    final cached = await cacheService.getJson<Map<String, dynamic>>(cacheKey);
    if (cached != null) {
      return LmsExtractedContent.fromJson(cached);
    }

    final response = await dio.get<String>(
      url,
      options: Options(
        headers: {
          'Cookie': 'MoodleSession=${session.moodleSession}',
          'User-Agent': 'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36',
        },
      ),
    );

    final html = response.data ?? '';
    final doc = html_parser.parse(html);

    final pageTitle = doc.querySelector('.page-header-headings h1')?.text.trim() ??
        doc.querySelector('h1, h2')?.text.trim() ??
        'Course Content';

    // 1. Check for Single Document Viewer (PPT/PDF/Office Viewer)
    final viewerIframe = doc.querySelector('iframe#resourceobject');
    if (viewerIframe != null) {
      final viewerUrl = viewerIframe.attributes['src'];
      final downloadUrl = doc.querySelector('a.btn-primary[download], a.btn[download]')?.attributes['href'];
      final fileName = doc.querySelector('.local-officeviewer-filename')?.text.trim() ?? pageTitle;

      String fileType = 'pdf';
      if (fileName.toLowerCase().endsWith('.pptx') || fileName.toLowerCase().endsWith('.ppt')) {
        fileType = 'pptx';
      } else if (fileName.toLowerCase().endsWith('.docx') || fileName.toLowerCase().endsWith('.doc')) {
        fileType = 'docx';
      } else if (fileName.toLowerCase().endsWith('.pdf')) {
        fileType = 'pdf';
      }

      final content = LmsExtractedContent(
        pageTitle: pageTitle,
        type: LmsItemType.singleDocument,
        originalUrl: url,
        items: [
          LmsContentItem(
            name: fileName,
            viewerUrl: viewerUrl,
            downloadUrl: downloadUrl,
            fileType: fileType,
          ),
        ],
      );

      await cacheService.putJson(cacheKey, content.toJson());
      return content;
    }

    // 2. Check for Folder View (#folder_tree0)
    final folderTree = doc.querySelector('#folder_tree0, .filemanager, .box.generalbox');
    if (folderTree != null) {
      final fileNodes = folderTree.querySelectorAll('.fp-filename a, a.aalink');
      final items = <LmsContentItem>[];

      for (final node in fileNodes) {
        final href = node.attributes['href'] ?? '';
        final text = node.text.trim();
        if (href.isNotEmpty && text.isNotEmpty) {
          final iconNode = node.parent?.parent?.querySelector('.fp-icon img, img');
          final iconSrc = iconNode?.attributes['src'] ?? '';

          String fileType = 'unknown';
          if (iconSrc.contains('/f/document') || text.endsWith('.docx') || text.endsWith('.doc')) {
            fileType = 'docx';
          } else if (iconSrc.contains('/f/powerpoint') || text.endsWith('.pptx') || text.endsWith('.ppt')) {
            fileType = 'pptx';
          } else if (iconSrc.contains('/f/pdf') || text.endsWith('.pdf')) {
            fileType = 'pdf';
          }

          items.add(LmsContentItem(
            name: text,
            downloadUrl: href,
            fileType: fileType,
          ));
        }
      }

      if (items.isNotEmpty) {
        final content = LmsExtractedContent(
          pageTitle: pageTitle,
          type: LmsItemType.folderDirectory,
          items: items,
          originalUrl: url,
        );
        await cacheService.putJson(cacheKey, content.toJson());
        return content;
      }
    }

    // 3. Page content / Markdown or HTML view
    final pageBody = doc.querySelector('.generalbox, #region-main .content, role=main');
    final content = LmsExtractedContent(
      pageTitle: pageTitle,
      type: LmsItemType.pageContent,
      items: [],
      pageBodyHtml: pageBody?.innerHtml,
      originalUrl: url,
    );

    await cacheService.putJson(cacheKey, content.toJson());
    return content;
  }

  // =========================================================================
  // ASSIGNMENTS API & SCRAPING
  // =========================================================================

  /// Fetches assignment overview, teacher prompt/files, and submission status.
  Future<AssignmentDetail> getAssignmentDetail(
    int assignId,
    AuthSession session, {
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'assign_detail_$assignId';
    if (!forceRefresh) {
      final cached = await cacheService.getJson(cacheKey);
      if (cached != null) {
        return AssignmentDetail.fromJson(cached);
      }
    }

    final url = 'https://lms.cuchd.in/mod/assign/view.php?id=$assignId';
    final response = await dio.get<String>(
      url,
      options: Options(
        headers: {
          'Cookie': 'MoodleSession=${session.moodleSession}',
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36',
        },
      ),
    );

    final html = response.data ?? '';
    final doc = html_parser.parse(html);

    // Title extraction
    var pageTitle = doc
            .querySelector(
                'h1, h2, .page-header-headings h1, .breadcrumb-item:last-child')
            ?.text
            .trim() ??
        '';
    if (pageTitle.isEmpty || pageTitle.toLowerCase() == 'assignment') {
      final lastBreadcrumb =
          doc.querySelector('.breadcrumb-item:last-child')?.text.trim();
      if (lastBreadcrumb != null && lastBreadcrumb.isNotEmpty) {
        pageTitle = lastBreadcrumb;
      }
    }

    // Course Name from breadcrumbs
    String? courseName;
    final breadcrumbs = doc.querySelectorAll('.breadcrumb-item');
    if (breadcrumbs.length >= 2) {
      courseName = breadcrumbs[1].text.trim();
    }

    // Activity Open and Due Dates
    String? openDate;
    String? dueDate;
    final dateNodes = doc.querySelectorAll(
        '[data-region="activity-dates"] div, .activity-dates div');
    for (final node in dateNodes) {
      final text = node.text.trim();
      final lower = text.toLowerCase();
      if (lower.startsWith('opened:') || lower.startsWith('opens:')) {
        openDate = text;
      } else if (lower.startsWith('due:')) {
        dueDate = text;
      }
    }

    // Instructions / Description
    // IMPORTANT: querySelector with a comma-separated list returns the FIRST element
    // in document order that matches ANY selector. Since [data-region="activity-information"]
    // (the dates div) appears BEFORE .activity-description in the Moodle DOM, combining
    // them in one selector was returning the dates container. Query separately instead.
    final introEl = doc.querySelector('.activity-description') ??
        doc.querySelector('#intro:not([data-region])');

    final instructionsHtml = introEl?.innerHtml;

    // Convert HTML to readable text:
    // For tables: convert each row to "col1 | col2 | col3" lines (readable Q&A format)
    // For regular text: normalize whitespace
    String instructionsText = '';
    if (introEl != null) {
      final tables = introEl.querySelectorAll('table');
      if (tables.isNotEmpty) {
        final tableLines = <String>[];
        for (final table in tables) {
          for (final row in table.querySelectorAll('tr')) {
            final cells = row
                .querySelectorAll('th, td')
                .map((c) => c.text.trim())
                .where((t) => t.isNotEmpty)
                .toList();
            if (cells.isNotEmpty) tableLines.add(cells.join(' | '));
          }
          tableLines.add('');
        }
        instructionsText = tableLines.join('\n').trim();
      } else {
        instructionsText = introEl.text
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .join('\n')
            .trim();
      }
    }


    // Teacher attachments (links to problem sheets, rubric, etc.)
    final teacherFiles = <AssignmentTeacherFile>[];
    final teacherLinks = introEl?.querySelectorAll('a') ?? [];
    for (final a in teacherLinks) {
      final href = a.attributes['href'] ?? '';
      final text = a.text.trim();
      if (href.isNotEmpty &&
          (href.contains('/pluginfile.php/') ||
              href.contains('forcedownload=1') ||
              href.contains('/mod/assign/'))) {
        if (!teacherFiles.any((f) => f.downloadUrl == href)) {
          String fileType = 'unknown';
          final lower = href.toLowerCase();
          if (lower.endsWith('.pdf') || text.toLowerCase().endsWith('.pdf')) {
            fileType = 'pdf';
          } else if (lower.endsWith('.docx') || lower.endsWith('.doc')) {
            fileType = 'docx';
          } else if (lower.endsWith('.pptx') || lower.endsWith('.ppt')) {
            fileType = 'pptx';
          }

          teacherFiles.add(
            AssignmentTeacherFile(
              name: text.isNotEmpty ? text : 'Attachment File',
              downloadUrl: href,
              fileType: fileType,
            ),
          );
        }
      }
    }

    // Submission Status Table
    String? submissionStatus;
    String? gradingStatus;
    String? timeRemaining;
    String? lastModified;
    final submittedFiles = <AssignmentSubmissionFile>[];
    final extraStatusFields = <String, String>{};

    final statusTable =
        doc.querySelector('.submissionstatustable, .generaltable');
    if (statusTable != null) {
      for (final row in statusTable.querySelectorAll('tr')) {
        final headerCell =
            row.querySelector('th, td.cell.c0, td:first-child');
        final valCell = row.querySelector('td.cell.c1, td:last-child');
        if (headerCell == null || valCell == null) continue;

        final rawHeader = headerCell.text.trim();
        final keyLower = rawHeader.toLowerCase();
        final rawVal = valCell.text.trim();

        if (keyLower.contains('submission status')) {
          submissionStatus = rawVal;
        } else if (keyLower.contains('grading status')) {
          gradingStatus = rawVal;
        } else if (keyLower.contains('time remaining')) {
          timeRemaining = rawVal;
        } else if (keyLower.contains('last modified')) {
          lastModified = rawVal;
        } else if (keyLower.contains('file submissions') ||
            keyLower.contains('files')) {
          final fileLinks = valCell.querySelectorAll('a[href*="pluginfile.php"]');
          for (final link in fileLinks) {
            final fileHref = link.attributes['href'] ?? '';
            final fileName = link.text.trim();
            if (fileHref.isNotEmpty) {
              submittedFiles.add(
                AssignmentSubmissionFile(
                  name: fileName.isNotEmpty ? fileName : 'Submitted File',
                  downloadUrl: fileHref,
                  timeModified: lastModified,
                ),
              );
            }
          }
        } else if (rawVal.isNotEmpty && rawHeader.isNotEmpty) {
          // Skip rows that are HTML-heavy (e.g. submission comments editor)
          final hasHtmlTags = RegExp(r'<[a-zA-Z]').hasMatch(rawVal);
          final hasEditor = valCell.querySelector(
                  'textarea, [contenteditable], .editor_atto_content, .atto_content') !=
              null;
          if (!hasHtmlTags && !hasEditor && rawVal.length <= 400) {
            extraStatusFields[rawHeader] = rawVal;
          }
        }
      }
    }

    // Action button detection ("Add submission" or "Edit submission", "Remove submission")
    bool canEditSubmission = false;
    String? editButtonLabel;
    final buttons = doc.querySelectorAll(
      '.submissionaction button, form[action*="editsubmission"] button, form[action*="editsubmission"] input[type="submit"], a[href*="editsubmission"]',
    );
    for (final btn in buttons) {
      final label = btn.text.trim().isNotEmpty
          ? btn.text.trim()
          : (btn.attributes['value'] ?? '');
      if (label.toLowerCase().contains('submission')) {
        canEditSubmission = true;
        editButtonLabel = label;
        break;
      }
    }

    bool canRemoveSubmission = false;
    final removeElements = doc.querySelectorAll(
      'form[action*="removesubmissionconfirm"], input[value="removesubmissionconfirm"], a[href*="removesubmission"]',
    );
    if (removeElements.isNotEmpty) {
      canRemoveSubmission = true;
    }

    // Submission comments count
    int submissionCommentsCount = 0;
    final commentMatch = RegExp(r'Comments\s*\(\s*(\d+)\s*\)', caseSensitive: false)
        .firstMatch(html);
    if (commentMatch != null) {
      submissionCommentsCount = int.tryParse(commentMatch.group(1)!) ?? 0;
    }

    // Feedback / Grading parsing
    String? feedbackGrade;
    String? feedbackGradedOn;
    String? feedbackGradedBy;
    String? feedbackComments;

    final feedbackRows = doc.querySelectorAll('.generaltable tr, .feedback tr');
    for (final row in feedbackRows) {
      final hCell = row.querySelector('th, td.cell.c0, td:first-child');
      final vCell = row.querySelector('td.cell.c1, td:last-child');
      if (hCell == null || vCell == null) continue;
      final h = hCell.text.trim().toLowerCase();
      final v = vCell.text.trim();
      if (h == 'grade' || h == 'current grade in gradebook') {
        feedbackGrade = v;
      } else if (h.contains('graded on')) {
        feedbackGradedOn = v;
      } else if (h.contains('graded by')) {
        feedbackGradedBy = v;
      } else if (h.contains('feedback comments')) {
        feedbackComments = v;
      }
    }

    String? moodleUserId;
    final userIdMatch = RegExp(r'"userId":\s*(\d+)').firstMatch(html) ??
        RegExp(r'data-userid="(\d+)"').firstMatch(html) ??
        RegExp(r'/user/profile\.php\?id=(\d+)').firstMatch(html) ??
        RegExp(r'name="userid"\s+value="(\d+)"').firstMatch(html);
    if (userIdMatch != null) {
      moodleUserId = userIdMatch.group(1);
    }

    final detail = AssignmentDetail(
      id: assignId,
      name: pageTitle.isNotEmpty ? pageTitle : 'ASSIGNMENT',
      courseName: courseName,
      openDate: openDate,
      dueDate: dueDate,
      instructionsHtml: instructionsHtml,
      instructionsText: instructionsText,
      teacherFiles: teacherFiles,
      submissionStatus: submissionStatus,
      gradingStatus: gradingStatus,
      timeRemaining: timeRemaining,
      lastModified: lastModified,
      submittedFiles: submittedFiles,
      canEditSubmission: canEditSubmission,
      canRemoveSubmission: canRemoveSubmission,
      editButtonLabel: editButtonLabel,
      submissionCommentsCount: submissionCommentsCount,
      feedbackGrade: feedbackGrade,
      feedbackGradedOn: feedbackGradedOn,
      feedbackGradedBy: feedbackGradedBy,
      feedbackComments: feedbackComments,
      extraStatusFields: extraStatusFields,
      moodleUserId: moodleUserId,
      fetchedAt: DateTime.now(),
    );

    await cacheService.putJson(cacheKey, detail.toJson());
    return detail;
  }

  /// Fetches the edit submission configuration (itemid, maxbytes, limits)
  /// and current staged draft files from Moodle.
  Future<AssignmentSubmissionConfig> getSubmissionConfig(
    int assignId,
    AuthSession session, {
    bool forceRefresh = false,
  }) async {
    final url =
        'https://lms.cuchd.in/mod/assign/view.php?id=$assignId&action=editsubmission';
    final response = await dio.get<String>(
      url,
      options: Options(
        headers: {
          'Cookie': 'MoodleSession=${session.moodleSession}',
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36',
        },
      ),
    );

    final html = response.data ?? '';
    final m = RegExp(r'M\.form_filemanager\.init\(Y,\s*({.*?})\);', dotAll: true)
        .firstMatch(html);

    if (m == null) {
      throw Exception('Could not parse Moodle submission filemanager options');
    }

    final fm = json.decode(m.group(1)!) as Map<String, dynamic>;
    final itemId = int.tryParse(fm['itemid']?.toString() ?? '0') ?? 0;
    final clientId = fm['client_id']?.toString() ?? '';
    final maxBytes = int.tryParse(fm['maxbytes']?.toString() ?? '5242880') ?? 5242880;
    final maxFiles = int.tryParse(fm['maxfiles']?.toString() ?? '1') ?? 1;
    final contextId = fm['context']?['id']?.toString();
    final author = fm['author']?.toString() ?? 'Student';

    final acceptedList = <String>[];
    if (fm['filetypeslist'] is List) {
      for (final t in fm['filetypeslist'] as List) {
        acceptedList.add(t.toString());
      }
    } else {
      acceptedList.addAll([
        '.pdf',
        '.docx',
        '.doc',
        '.pptx',
        '.ppt',
        '.jpg',
        '.png',
        '.xlsx',
        '.csv',
      ]);
    }

    // Extract form action & hidden inputs
    final doc = html_parser.parse(html);
    final form = doc.querySelector('form[action*="mod/assign/view.php"]') ??
        doc.querySelector('form[id^="mform1"]');
    final hiddenFields = <String, String>{};
    var formAction = 'https://lms.cuchd.in/mod/assign/view.php';
    if (form != null) {
      final actionAttr = form.attributes['action'];
      if (actionAttr != null && actionAttr.isNotEmpty) {
        formAction = actionAttr.startsWith('http')
            ? actionAttr
            : 'https://lms.cuchd.in$actionAttr';
      }
      for (final input in form.querySelectorAll('input[type="hidden"]')) {
        final name = input.attributes['name'];
        final value = input.attributes['value'] ?? '';
        if (name != null && name.isNotEmpty && name.toLowerCase() != 'cancel') {
          hiddenFields[name] = value;
        }
      }
    }

    // Format human readable max bytes text
    final maxBytesMb = (maxBytes / (1024 * 1024)).toStringAsFixed(1);
    final maxBytesText = '$maxBytesMb MB';

    // Fetch live draft files currently staged in this Moodle draft area
    List<DraftFileInfo> draftFiles = [];
    try {
      draftFiles = await getDraftFiles(
        itemId: itemId,
        clientId: clientId,
        session: session,
      );
    } catch (_) {}

    return AssignmentSubmissionConfig(
      assignId: assignId,
      itemId: itemId,
      clientId: clientId,
      maxBytes: maxBytes,
      maxBytesText: maxBytesText,
      maxFiles: maxFiles,
      acceptedTypes: acceptedList,
      contextId: contextId,
      author: author,
      draftFiles: draftFiles,
      formAction: formAction,
      hiddenFields: hiddenFields,
      hasExistingSubmission: draftFiles.isNotEmpty,
    );
  }

  /// Lists draft files staged in Moodle's draft file area.
  Future<List<DraftFileInfo>> getDraftFiles({
    required int itemId,
    required String clientId,
    required AuthSession session,
  }) async {
    final response = await dio.post<dynamic>(
      'https://lms.cuchd.in/repository/draftfiles_ajax.php?action=list',
      data:
          'sesskey=${session.sesskey}&client_id=$clientId&filepath=%2F&itemid=$itemId',
      options: Options(
        headers: {
          'Cookie': 'MoodleSession=${session.moodleSession}',
          'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
          'X-Requested-With': 'XMLHttpRequest',
        },
      ),
    );

    final result = <DraftFileInfo>[];
    if (response.data is Map<String, dynamic>) {
      final map = response.data as Map<String, dynamic>;
      final list = map['list'] as List<dynamic>? ?? [];
      for (final item in list) {
        if (item is Map<String, dynamic>) {
          result.add(DraftFileInfo.fromJson(item));
        }
      }
    }
    return result;
  }

  /// Uploads a file to Moodle's draft staging repository area.
  Future<DraftFileInfo?> uploadDraftFile({
    required AssignmentSubmissionConfig config,
    required AuthSession session,
    required String filename,
    required List<int> fileBytes,
  }) async {
    final formData = FormData.fromMap({
      'title': filename,
      'author': config.author ?? 'Student',
      'license': 'unknown',
      'itemid': config.itemId,
      'repo_id': '5',
      'p': '',
      'page': '',
      'env': 'filemanager',
      'sesskey': session.sesskey,
      'client_id': config.clientId,
      'maxbytes': config.maxBytes.toString(),
      'areamaxbytes': '-1',
      'ctx_id': config.contextId ?? '',
      'repo_upload_file': MultipartFile.fromBytes(
        fileBytes,
        filename: filename,
      ),
    });

    final response = await dio.post<dynamic>(
      'https://lms.cuchd.in/repository/repository_ajax.php?action=upload',
      data: formData,
      options: Options(
        headers: {
          'Cookie': 'MoodleSession=${session.moodleSession}',
          'X-Requested-With': 'XMLHttpRequest',
        },
      ),
    );

    if (response.data is Map<String, dynamic>) {
      final map = response.data as Map<String, dynamic>;
      return DraftFileInfo.fromJson(map);
    }
    return null;
  }

  /// Deletes a file staged in Moodle's draft area.
  Future<bool> deleteDraftFile({
    required AssignmentSubmissionConfig config,
    required AuthSession session,
    required String filename,
  }) async {
    final response = await dio.post<dynamic>(
      'https://lms.cuchd.in/repository/draftfiles_ajax.php?action=delete',
      data:
          'sesskey=${session.sesskey}&client_id=${config.clientId}&filepath=%2F&itemid=${config.itemId}&filename=${Uri.encodeComponent(filename)}',
      options: Options(
        headers: {
          'Cookie': 'MoodleSession=${session.moodleSession}',
          'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
          'X-Requested-With': 'XMLHttpRequest',
        },
      ),
    );

    return response.statusCode == 200;
  }

  /// Submits and saves the assignment permanently in Moodle.
  /// Posts the form data with action=savesubmission and files_filemanager=<itemid>.
  Future<bool> saveFinalSubmission({
    required AssignmentSubmissionConfig config,
    required AuthSession session,
  }) async {
    logService?.info(
      'ASSIGNMENT',
      'Committing final submission: assignId=${config.assignId}, itemId=${config.itemId}',
    );

    final payload = Map<String, String>.from(config.hiddenFields);
    // Explicitly exclude cancel button as Moodle formslib interprets any 'cancel'
    // in $_POST as a user command to abort and discard changes
    payload.remove('cancel');
    payload.remove('cancelbutton');

    payload['id'] = config.assignId.toString();
    payload['action'] = 'savesubmission';
    payload['sesskey'] = session.sesskey;
    payload['files_filemanager'] = config.itemId.toString();
    payload['submitbutton'] = 'Save changes';
    payload['_qf__mod_assign_submission_form'] = '1';
    payload['mform_isexpanded_id_submissionheader'] = '1';

    final url = config.formAction.isNotEmpty
        ? config.formAction
        : 'https://lms.cuchd.in/mod/assign/view.php';

    final response = await dio.post<String>(
      url,
      data: payload,
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        followRedirects: true,
        maxRedirects: 5,
        validateStatus: (status) => status != null && status < 500,
        headers: {
          'Cookie': 'MoodleSession=${session.moodleSession}',
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36',
          'Referer':
              'https://lms.cuchd.in/mod/assign/view.php?id=${config.assignId}&action=editsubmission',
        },
      ),
    );

    // Evict cached assignment detail so the next view reflects current submission status
    await cacheService.remove('assign_detail_${config.assignId}');

    final body = response.data ?? '';
    if (body.contains('notifyproblem') || body.contains('errormessage') || body.contains('errorbox')) {
      final doc = html_parser.parse(body);
      final alert = doc.querySelector('.errormessage, .alert-danger, .notifyproblem, .felement.error')?.text.trim();
      if (alert != null && alert.isNotEmpty) {
        throw Exception(alert);
      }
    }

    return response.statusCode == 200 || response.statusCode == 303;
  }

  /// Removes an existing submission from Moodle.
  Future<bool> removeSubmission({
    required int assignId,
    required AuthSession session,
    String? userId,
  }) async {
    logService?.info('ASSIGNMENT', 'Removing submission for assignId=$assignId');

    String? resolvedUserId = (userId != null && userId.isNotEmpty)
        ? userId
        : session.moodleUserId;

    // If userId is still missing, retrieve it from the confirmation page form
    if (resolvedUserId == null || resolvedUserId.isEmpty) {
      try {
        logService?.info('ASSIGNMENT', 'Resolving userid from confirmation page for assignId=$assignId');
        final confirmResp = await dio.get<String>(
          'https://lms.cuchd.in/mod/assign/view.php?id=$assignId&action=removesubmissionconfirm',
          options: Options(
            validateStatus: (status) => status != null && status < 500,
            headers: {
              'Cookie': 'MoodleSession=${session.moodleSession}',
              'User-Agent':
                  'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36',
              'Referer': 'https://lms.cuchd.in/mod/assign/view.php?id=$assignId',
            },
          ),
        );
        if (confirmResp.data != null) {
          final cHtml = confirmResp.data!;
          final uidMatch = RegExp(r'name=["'']userid["'']\s+value=["''](\d+)["'']').firstMatch(cHtml) ??
              RegExp(r'"userId":\s*(\d+)').firstMatch(cHtml) ??
              RegExp(r'data-userid=["''](\d+)["'']').firstMatch(cHtml);
          if (uidMatch != null) {
            resolvedUserId = uidMatch.group(1);
          }
        }
      } catch (e) {
        logService?.error('ASSIGNMENT', 'Failed to auto-resolve userid: $e');
      }
    }

    final url = 'https://lms.cuchd.in/mod/assign/view.php';
    final payload = <String, String>{
      'id': assignId.toString(),
      'action': 'removesubmission',
      'sesskey': session.sesskey,
    };
    if (resolvedUserId != null && resolvedUserId.isNotEmpty) {
      payload['userid'] = resolvedUserId;
    }

    final response = await dio.post<String>(
      url,
      data: payload,
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        followRedirects: true,
        maxRedirects: 5,
        validateStatus: (status) => status != null && status < 500,
        headers: {
          'Cookie': 'MoodleSession=${session.moodleSession}',
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36',
          'Referer':
              'https://lms.cuchd.in/mod/assign/view.php?id=$assignId&action=removesubmissionconfirm',
        },
      ),
    );

    await cacheService.remove('assign_detail_$assignId');

    final body = response.data ?? '';
    if (body.contains('errormessage') || body.contains('errorbox') || body.contains('notifyproblem')) {
      final doc = html_parser.parse(body);
      final alert = doc.querySelector('.errormessage, .alert-danger, .notifyproblem')?.text.trim();
      if (alert != null && alert.isNotEmpty) {
        logService?.error('ASSIGNMENT', 'Submission removal failed with error: $alert');
        throw Exception(alert);
      }
    }

    return response.statusCode == 200 || response.statusCode == 303;
  }
}

