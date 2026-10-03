import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';

void main(List<String> args) async {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 45),
      receiveTimeout: const Duration(seconds: 45),
      headers: {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36',
      },
    ),
  );

  String? moodleSession;
  String? sesskey;

  // Check if session & sesskey passed via CLI args
  for (int i = 0; i < args.length; i++) {
    if (args[i] == '--session' && i + 1 < args.length) {
      moodleSession = args[i + 1];
    }
    if (args[i] == '--sesskey' && i + 1 < args.length) {
      sesskey = args[i + 1];
    }
  }

  // Check if saved .session_cache.json exists
  if (moodleSession == null || sesskey == null) {
    try {
      final cacheFile = File('.session_cache.json');
      if (await cacheFile.exists()) {
        final cache = json.decode(await cacheFile.readAsString()) as Map<String, dynamic>;
        final cachedSession = cache['moodleSession'] as String?;
        final cachedSesskey = cache['sesskey'] as String?;
        if (cachedSession != null && cachedSesskey != null) {
          // Verify if session is still alive
          final checkResp = await dio.get<String>(
            'https://lms.cuchd.in/my/',
            options: Options(
              headers: {'Cookie': 'MoodleSession=$cachedSession'},
              followRedirects: false,
              validateStatus: (s) => s != null && s < 500,
            ),
          );
          if (checkResp.statusCode == 200 && (checkResp.data?.contains(cachedSesskey) ?? false)) {
            moodleSession = cachedSession;
            sesskey = cachedSesskey;
            print('⚡ Using cached valid MoodleSession from .session_cache.json');
          }
        }
      }
    } catch (_) {}
  }

  String uid = Platform.environment['LMS_UID'] ?? '';
  String password = Platform.environment['LMS_PASSWORD'] ?? '';
  String token = Platform.environment['LMS_TOKEN'] ?? 'dont_use_please';

  for (int i = 0; i < args.length; i++) {
    if (args[i] == '--uid' && i + 1 < args.length) uid = args[i + 1];
    if (args[i] == '--pwd' && i + 1 < args.length) password = args[i + 1];
    if (args[i] == '--token' && i + 1 < args.length) token = args[i + 1];
  }

  if (moodleSession == null || sesskey == null) {
    if (uid.isEmpty || password.isEmpty) {
      print('❌ Error: Missing credentials for authentication.');
      print('Please provide credentials using CLI arguments:');
      print('  dart run bin/test_fetch.dart --uid <UID> --pwd <PASSWORD> [--token <TOKEN>]');
      print('Or set environment variables LMS_UID and LMS_PASSWORD.');
      return;
    }
    print('==================================================');
    print('1. Authenticating via SSO Gateway (https://lmssso.vercel.app/api/sso)');
    print('==================================================');

    Map<String, dynamic>? ssoData;
    int attempts = 0;
    const maxAttempts = 3;

    while (attempts < maxAttempts) {
      attempts++;
      print('Attempt $attempts of $maxAttempts to authenticate...');
      try {
        final ssoResponse = await dio.post<dynamic>(
          'https://lmssso.vercel.app/api/sso',
          data: {'uid': uid, 'password': password},
          options: Options(
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          ),
        );

        ssoData = ssoResponse.data is String
            ? json.decode(ssoResponse.data as String) as Map<String, dynamic>
            : ssoResponse.data as Map<String, dynamic>;

        if (ssoData['success'] == true && ssoData['lmsLoginUrl'] != null) {
          print('✅ SSO Authentication Successful on attempt $attempts!');
          break;
        }

        if (ssoData['requireManualCaptcha'] == true) {
          print('⚠️ Manual CAPTCHA triggered by Vercel gateway.');
          final sessionToken = ssoData['sessionToken'] as String;
          final rawCaptchaImg = ssoData['captchaImage'] as String? ?? '';

          // Save captcha image to disk for inspection
          final cleanB64 = rawCaptchaImg.contains(',')
              ? rawCaptchaImg.split(',')[1].replaceAll(RegExp(r'\s+'), '')
              : rawCaptchaImg.replaceAll(RegExp(r'\s+'), '');

          if (cleanB64.isNotEmpty) {
            try {
              final rawBytes = base64Decode(cleanB64);
              int start = -1;
              for (int j = 0; j < rawBytes.length - 1; j++) {
                if (rawBytes[j] == 0xFF && rawBytes[j + 1] == 0xD8) {
                  start = j;
                  break;
                }
              }
              int end = -1;
              for (int j = rawBytes.length - 1; j > 0; j--) {
                if (rawBytes[j - 1] == 0xFF && rawBytes[j] == 0xD9) {
                  end = j + 1;
                  break;
                }
              }

              final imgBytes = (start != -1 && end != -1 && end > start)
                  ? rawBytes.sublist(start, end)
                  : rawBytes;

              final captchaFile = File('captcha_preview.jpg');
              await captchaFile.writeAsBytes(imgBytes);
              print('📸 Captcha image saved to: ${captchaFile.absolute.path}');
            } catch (e) {
              print('Could not save captcha preview: $e');
            }
          }

          // If stdin has terminal, prompt user
          if (stdin.hasTerminal) {
            stdout.write('👉 Please open captcha_preview.jpg and enter CAPTCHA: ');
            final code = stdin.readLineSync()?.trim() ?? '';
            if (code.isNotEmpty) {
              print('Submitting manual CAPTCHA "$code"...');
              final captchaSubmitResp = await dio.post<dynamic>(
                'https://lmssso.vercel.app/api/sso',
                data: {'sessionToken': sessionToken, 'captcha': code},
                options: Options(
                  headers: {
                    'Content-Type': 'application/json',
                    'Authorization': 'Bearer $token',
                  },
                ),
              );

              final resData = captchaSubmitResp.data is String
                  ? json.decode(captchaSubmitResp.data as String) as Map<String, dynamic>
                  : captchaSubmitResp.data as Map<String, dynamic>;

              if (resData['success'] == true) {
                ssoData = resData;
                print('✅ Manual CAPTCHA verified successfully!');
                break;
              } else {
                print('❌ CAPTCHA verification failed: ${resData['message']}');
              }
            }
          } else {
            print('Non-interactive terminal detected. Waiting 3s before retry...');
            await Future.delayed(const Duration(seconds: 3));
          }
        }
      } catch (e) {
        print('SSO Request error on attempt $attempts: $e');
        await Future.delayed(const Duration(seconds: 3));
      }
    }

    if (ssoData == null || ssoData['lmsLoginUrl'] == null) {
      print('❌ Could not complete SSO after $attempts attempts.');
      return;
    }

    final lmsLoginUrl = ssoData['lmsLoginUrl'] as String;
    print('\n==================================================');
    print('2. Resolving Moodle Autologin URL');
    print('==================================================');
    print('URL: $lmsLoginUrl');

    try {
      final autologinResp = await dio.get<String>(
        lmsLoginUrl,
        options: Options(
          followRedirects: false,
          validateStatus: (s) => s != null && s < 500,
        ),
      );

      final setCookies = autologinResp.headers['set-cookie'] ?? [];
      for (final c in setCookies) {
        if (c.contains('MoodleSession=')) {
          final match = RegExp(r'MoodleSession=([^;]+)').firstMatch(c);
          if (match != null) {
            moodleSession = match.group(1);
            print('✅ Captured MoodleSession: $moodleSession');
            break;
          }
        }
      }

      // Fetch /my/ to extract sesskey
      final myResp = await dio.get<String>(
        'https://lms.cuchd.in/my/',
        options: Options(
          headers: {
            if (moodleSession != null) 'Cookie': 'MoodleSession=$moodleSession',
          },
        ),
      );

      final html = myResp.data ?? '';
      final sesskeyMatch = RegExp(r'"sesskey":"([a-zA-Z0-9]+)"').firstMatch(html);
      if (sesskeyMatch != null) {
        sesskey = sesskeyMatch.group(1);
        print('✅ Captured Sesskey: $sesskey');
      }
      final userIdMatch = RegExp(r'''"userId":\s*(\d+)|"userid":\s*(\d+)''').firstMatch(html);
      if (userIdMatch != null) {
        final uidNum = userIdMatch.group(1) ?? userIdMatch.group(2);
        print('✅ Captured Moodle User ID: $uidNum');
      }
    } catch (e) {
      print('❌ Error during Moodle resolution: $e');
    }
  }

  if (moodleSession == null || sesskey == null) {
    print('❌ Aborting: Missing MoodleSession or sesskey');
    return;
  }

  // Save session info to a local json file for quick re-use
  try {
    final sessionFile = File('.session_cache.json');
    await sessionFile.writeAsString(json.encode({
      'moodleSession': moodleSession,
      'sesskey': sesskey,
      'updatedAt': DateTime.now().toIso8601String(),
    }));
    print('💾 Saved active session to .session_cache.json for instant future re-runs.');
  } catch (_) {}

  print('\n==================================================');
  print('3. Fetching Enrolled Courses');
  print('==================================================');

  List<dynamic> courses = [];
  try {
    final coursesResp = await dio.post<dynamic>(
      'https://lms.cuchd.in/lib/ajax/service.php?sesskey=$sesskey&info=core_course_get_enrolled_courses_by_timeline_classification',
      data: [
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
      ],
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Cookie': 'MoodleSession=$moodleSession',
        },
      ),
    );

    final raw = coursesResp.data;
    final List<dynamic> list = raw is String ? json.decode(raw) as List : raw as List;
    courses = list[0]['data']['courses'] as List;

    print('✅ Enrolled Courses Fetched Successfully (${courses.length} courses):');
    for (int i = 0; i < courses.length; i++) {
      final c = courses[i];
      print('   [${i + 1}] ID: ${c['id']} | ${c['shortname']} - ${c['fullname']} (Progress: ${c['progress'] ?? 0}%)');
    }
  } catch (e) {
    print('❌ Failed to fetch courses: $e');
  }

  print('\n==================================================');
  print('4. Fetching Course Contents / Units (First Course)');
  print('==================================================');

  if (courses.isNotEmpty) {
    for (final course in courses.take(3)) {
      final courseId = course['id'];
      final courseName = course['shortname'];
      print('\n--- Fetching Inside: Course $courseId ($courseName) ---');
      try {
        final stateResp = await dio.post<dynamic>(
          'https://lms.cuchd.in/lib/ajax/service.php?sesskey=$sesskey&info=core_courseformat_get_state',
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
              'Cookie': 'MoodleSession=$moodleSession',
              'X-Requested-With': 'XMLHttpRequest',
            },
          ),
        );

        final raw = stateResp.data;
        final List<dynamic> list = raw is String ? json.decode(raw) as List : raw as List;
        if (list.isNotEmpty && list[0]['error'] == false) {
          final state = json.decode(list[0]['data'] as String) as Map<String, dynamic>;
          final sections = (state['section'] as List? ?? []);
          final cms = (state['cm'] as List? ?? []);
          print('✅ Fetched State: ${sections.length} Sections, ${cms.length} Total Course Modules (cm)');
          
          final cmMap = <String, Map<String, dynamic>>{};
          for (final item in cms) {
            cmMap[(item as Map<String, dynamic>)['id'].toString()] = item;
          }

          int printedSections = 0;
          for (final sec in sections) {
            final secMap = sec as Map<String, dynamic>;
            final cmList = (secMap['cmlist'] as List? ?? []).map((e) => e.toString()).toList();
            if (cmList.isEmpty && secMap['number'] != 0) continue;
            
            final title = (secMap['title'] as String?)?.trim() ?? 'Section ${secMap['number']}';
            print('   📁 Section ${secMap['number']}: $title (${cmList.length} items)');
            
            for (final cmId in cmList.take(3)) {
              final cm = cmMap[cmId];
              if (cm != null) {
                print('      📄 [${cm['modname']}] ${cm['name']} -> ${cm['url']}');
              }
            }
            if (cmList.length > 3) {
              print('      ... and ${cmList.length - 3} more items');
            }

            if (++printedSections >= 4) {
              final remaining = sections.length - printedSections;
              if (remaining > 0) print('   ... and $remaining more sections');
              break;
            }
          }
        }
      } catch (e) {
        print('❌ Course $courseId fetch error: $e');
      }
    }
  }

  print('\n==================================================');
  print('5. Fetching Calendar Deadlines / Action Events');
  print('==================================================');

  try {
    final now = DateTime.now();
    final from = now.subtract(const Duration(days: 7)).millisecondsSinceEpoch ~/ 1000;
    final to = now.add(const Duration(days: 60)).millisecondsSinceEpoch ~/ 1000;

    final eventsResp = await dio.post<dynamic>(
      'https://lms.cuchd.in/lib/ajax/service.php?sesskey=$sesskey&info=core_calendar_get_action_events_by_timesort',
      data: [
        {
          "index": 0,
          "methodname": "core_calendar_get_action_events_by_timesort",
          "args": {
            "limitnum": 20,
            "timesortfrom": from,
            "timesortto": to,
            "limittononsuspendedevents": true
          }
        }
      ],
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Cookie': 'MoodleSession=$moodleSession',
        },
      ),
    );

    final raw = eventsResp.data;
    final List<dynamic> list = raw is String ? json.decode(raw) as List : raw as List;
    final events = list[0]['data']['events'] as List;

    print('✅ Calendar Action Events Fetched (${events.length} deadlines):');
    for (int i = 0; i < events.length; i++) {
      final ev = events[i];
      final name = ev['name'] ?? 'Event';
      final formattedTime = ev['formattedtime'] ?? '';
      final courseName = ev['course']?['fullname'] ?? '';
      print('   [${i + 1}] $name');
      print('       Course: $courseName');
      print('       Deadline: $formattedTime');
    }
  } catch (e) {
    print('❌ Failed to fetch calendar events: $e');
  }

  print('\n==================================================');
  print('6. Fetching Moodle Popup Notifications');
  print('==================================================');

  try {
    final notifResp = await dio.post<dynamic>(
      'https://lms.cuchd.in/lib/ajax/service.php?sesskey=$sesskey&info=message_popup_get_popup_notifications',
      data: [
        {
          "index": 0,
          "methodname": "message_popup_get_popup_notifications",
          "args": {
            "limit": 20,
            "offset": 0,
          }
        }
      ],
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Cookie': 'MoodleSession=$moodleSession',
        },
      ),
    );

    final raw = notifResp.data;
    final List<dynamic> list = raw is String ? json.decode(raw) as List : raw as List;
    final notifData = list[0]['data'];
    if (notifData != null && notifData['notifications'] != null) {
      final notifs = notifData['notifications'] as List;
      final unreadCount = notifData['unreadcount'] ?? 0;
      print('✅ Popup Notifications Fetched ($unreadCount unread, ${notifs.length} total received):');
      for (int i = 0; i < notifs.length; i++) {
        final n = notifs[i];
        final subject = n['subject'] ?? 'Notification';
        final text = (n['text'] as String?)?.replaceAll(RegExp(r'<[^>]*>'), ' ').trim() ?? '';
        final timecreated = n['timecreatedpretty'] ?? '';
        print('   [${i + 1}] $subject ($timecreated)');
        if (text.isNotEmpty) {
          print('       ${text.length > 120 ? "${text.substring(0, 120)}..." : text}');
        }
      }
    } else {
      print('ℹ️ Response for message_popup_get_popup_notifications: $notifData');
    }
  } catch (e) {
    print('ℹ️ Note on message_popup_get_popup_notifications: $e');
  }

  print('\n==================================================');
  print('7. Fetching Unread Conversation / Message Counts');
  print('==================================================');

  try {
    final msgResp = await dio.post<dynamic>(
      'https://lms.cuchd.in/lib/ajax/service.php?sesskey=$sesskey&info=core_message_get_unread_conversations_count',
      data: [
        {
          "index": 0,
          "methodname": "core_message_get_unread_conversations_count",
          "args": {}
        }
      ],
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Cookie': 'MoodleSession=$moodleSession',
        },
      ),
    );

    final raw = msgResp.data;
    final List<dynamic> list = raw is String ? json.decode(raw) as List : raw as List;
    final count = list[0]['data'];
    print('✅ Unread Conversations / Messages Count: $count');
  } catch (e) {
    print('ℹ️ Note on core_message_get_unread_conversations_count: $e');
  }

  print('\n==================================================');
  print('8. DEBUG: Assignment Page — activity-description Check');
  print('==================================================');

  // Pass an assign ID via --assign <id>, else skip
  int? debugAssignId;
  for (int i = 0; i < args.length; i++) {
    if (args[i] == '--assign' && i + 1 < args.length) {
      debugAssignId = int.tryParse(args[i + 1]);
    }
  }

  if (debugAssignId == null) {
    print('ℹ️  Skipped. Run with: --assign <assign_id> to debug an assignment page.');
  } else {
    try {
      final resp = await dio.get<String>(
        'https://lms.cuchd.in/mod/assign/view.php?id=$debugAssignId',
        options: Options(
          headers: {'Cookie': 'MoodleSession=$moodleSession'},
        ),
      );
      final html = resp.data ?? '';

      // Use a simple regex approach to find the key sections
      // (no html package available in bin/ context — use string search)
      print('\n🔍 Searching for description-related HTML blocks...\n');

      final selectors = [
        'activity-description',
        'id="intro"',
        'data-region="activity-information"',
        'region-assign-intro',
        'class="box generalbox"',
      ];

      for (final sel in selectors) {
        final idx = html.indexOf(sel);
        if (idx == -1) {
          print('❌  "$sel" — NOT FOUND in page');
        } else {
          // Print ~600 chars around the match
          final start = (idx - 100).clamp(0, html.length);
          final end = (idx + 600).clamp(0, html.length);
          final snippet = html.substring(start, end)
              .replaceAll('\n', '↵ ')
              .replaceAll(RegExp(r' {2,}'), ' ');
          print('✅  "$sel" FOUND at index $idx:');
          print('   >>> $snippet');
          print('');
        }
      }

      // Also dump the submissionstatustable rows
      print('\n📋 Submission Status Table rows:');
      final tableIdx = html.indexOf('submissionstatustable');
      if (tableIdx == -1) {
        print('❌  "submissionstatustable" — NOT FOUND');
        // Try generaltable
        final gt = html.indexOf('generaltable');
        if (gt != -1) {
          final snippet = html.substring(gt, (gt + 1000).clamp(0, html.length))
              .replaceAll('\n', '↵ ')
              .replaceAll(RegExp(r' {2,}'), ' ');
          print('ℹ️  Found "generaltable" instead:');
          print('   >>> $snippet');
        }
      } else {
        final end = (tableIdx + 2000).clamp(0, html.length);
        final snippet = html.substring(tableIdx, end)
            .replaceAll('\n', '↵ ')
            .replaceAll(RegExp(r' {2,}'), ' ');
        print('✅  Found:');
        print('   >>> $snippet');
      }
    } catch (e) {
      print('❌ Error fetching assignment page: $e');
    }
  }

  print('\n==================================================');
  print('🎉 Test Script Completed Successfully!');
  print('==================================================');
}
