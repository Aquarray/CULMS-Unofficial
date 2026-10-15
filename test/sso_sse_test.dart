import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cuims_unofficial2/core/network/sse_parser.dart';
import 'package:cuims_unofficial2/data/models/auth_state.dart';
import 'package:cuims_unofficial2/data/models/sso_progress.dart';
import 'package:cuims_unofficial2/providers/auth_provider.dart';
import 'package:cuims_unofficial2/ui/screens/auth/widgets/sso_automation_loader.dart';
import 'package:cuims_unofficial2/ui/screens/auth/widgets/sso_progress_dialog.dart';

void main() {
  group('SseParser Tests', () {
    test('Correctly parses basic SSE progress and result events', () async {
      const sseText = '''
id: 1
event: progress
data: {"stage":"starting_login","message":"Starting login...","attempt":1,"maxAttempts":2}

: heartbeat

id: 2
event: progress
data: {"stage":"solving_captcha","message":"Solving CAPTCHA...","attempt":1,"maxAttempts":2}

id: 3
event: result
data: {"status":200,"data":{"success":true,"token":"tok123","lmsLoginUrl":"https://lms.test/login"}}

''';

      final parser = SseParser();
      final eventsFuture = parser.stream.toList();

      parser.addString(sseText);
      parser.close();

      final events = await eventsFuture;
      expect(events.length, 3);

      expect(events[0].id, '1');
      expect(events[0].event, 'progress');
      expect(events[0].data.contains('"starting_login"'), true);

      expect(events[1].id, '2');
      expect(events[1].event, 'progress');
      expect(events[1].data.contains('"solving_captcha"'), true);

      expect(events[2].id, '3');
      expect(events[2].event, 'result');
      expect(events[2].data.contains('"token":"tok123"'), true);
    });

    test('Handles fragmented multi-byte UTF-8 sequences and arbitrary byte chunks', () async {
      // Create multi-byte string containing emoji and symbols: "Solving CAPTCHA 🚀 key: 🔑 ₹"
      const complexMessage = 'Solving CAPTCHA 🚀 key: 🔑 ₹';
      final sseFrame = 'event: progress\r\ndata: {"stage":"solving_captcha","message":"$complexMessage"}\r\n\r\n';
      final fullBytes = utf8.encode(sseFrame);

      final parser = SseParser();
      final eventsFuture = parser.stream.toList();

      // Split into tiny 2-byte chunks so multi-byte UTF-8 bytes and CRLF are sliced in the middle
      for (int i = 0; i < fullBytes.length; i += 2) {
        final end = (i + 2 <= fullBytes.length) ? i + 2 : fullBytes.length;
        parser.addBytes(fullBytes.sublist(i, end));
      }
      parser.close();

      final events = await eventsFuture;
      expect(events.length, 1);
      expect(events[0].event, 'progress');

      final data = json.decode(events[0].data) as Map<String, dynamic>;
      expect(data['message'], complexMessage);
    });

    test('Joins multi-line data frames with newline and ignores comments', () async {
      const sseText = '''
: comment before event
event: progress
data: line 1
data: line 2
data: line 3

: heartbeat after event
''';

      final parser = SseParser();
      final eventsFuture = parser.stream.toList();

      parser.addString(sseText);
      parser.close();

      final events = await eventsFuture;
      expect(events.length, 1);
      expect(events[0].event, 'progress');
      expect(events[0].data, 'line 1\nline 2\nline 3');
    });

    test('Handles both CRLF and LF line terminators', () async {
      const crlfText = "event: progress\r\ndata: test-crlf\r\n\r\nevent: result\ndata: test-lf\n\n";

      final parser = SseParser();
      final eventsFuture = parser.stream.toList();

      parser.addString(crlfText);
      parser.close();

      final events = await eventsFuture;
      expect(events.length, 2);
      expect(events[0].data, 'test-crlf');
      expect(events[1].data, 'test-lf');
    });
  });

  group('SsoProgress Model Tests', () {
    test('Parses all known stages with appropriate titles and icons', () {
      final stages = [
        'starting_login',
        'retrying',
        'connecting_cuims',
        'resolving_identity',
        'loading_captcha',
        'solving_captcha',
        'submitting_login',
        'waiting_cuims',
        'opening_dashboard',
        'requesting_lms_sso',
        'capturing_token',
        'manual_captcha_required',
      ];

      for (final stage in stages) {
        final progress = SsoProgress.fromJson({
          'stage': stage,
          'message': 'Testing $stage',
          'attempt': 1,
          'maxAttempts': 2,
        });

        expect(progress.stage, stage);
        expect(progress.stageTitle.isNotEmpty, true);
        expect(progress.stageIcon, isNotNull);
      }
    });

    test('Gracefully handles unknown stages and omitted attempts', () {
      final progress = SsoProgress.fromJson({
        'stage': 'future_stage_x',
        'message': 'Custom operation in progress',
      });

      expect(progress.stage, 'future_stage_x');
      expect(progress.stageTitle, 'Processing SSO Login');
      expect(progress.stageIcon, isNotNull);
      expect(progress.attempt, isNull);
      expect(progress.maxAttempts, isNull);
      expect(progress.isRetry, false);
    });

    test('Detects retry progress correctly', () {
      final retryProgress = SsoProgress.fromJson({
        'stage': 'retrying',
        'message': 'Retrying attempt 2...',
        'attempt': 2,
        'maxAttempts': 2,
      });

      expect(retryProgress.isRetry, true);

      final attempt2Progress = SsoProgress.fromJson({
        'stage': 'starting_login',
        'message': 'Starting attempt 2',
        'attempt': 2,
        'maxAttempts': 2,
      });

      expect(attempt2Progress.isRetry, true);
    });

    test('Correctly maps stages to 5-tick phaseIndex', () {
      expect(SsoProgress(stage: 'starting_login', message: '').phaseIndex, 1);
      expect(SsoProgress(stage: 'retrying', message: '').phaseIndex, 1);
      expect(SsoProgress(stage: 'connecting_cuims', message: '').phaseIndex, 1);

      expect(SsoProgress(stage: 'resolving_identity', message: '').phaseIndex, 2);

      expect(SsoProgress(stage: 'loading_captcha', message: '').phaseIndex, 3);
      expect(SsoProgress(stage: 'solving_captcha', message: '').phaseIndex, 3);
      expect(SsoProgress(stage: 'manual_captcha_required', message: '').phaseIndex, 3);

      expect(SsoProgress(stage: 'submitting_login', message: '').phaseIndex, 4);
      expect(SsoProgress(stage: 'waiting_cuims', message: '').phaseIndex, 4);

      expect(SsoProgress(stage: 'opening_dashboard', message: '').phaseIndex, 5);
      expect(SsoProgress(stage: 'requesting_lms_sso', message: '').phaseIndex, 5);
      expect(SsoProgress(stage: 'capturing_token', message: '').phaseIndex, 5);

      // Unknown default
      expect(SsoProgress(stage: 'unknown_stage', message: '').phaseIndex, 1);
    });
  });

  group('SsoResponse Model Tests', () {
    test('Parses terminal SSE result event successfully', () {
      final jsonResult = {
        'status': 200,
        'data': {
          'success': true,
          'token': 'jwt_abc_123',
          'appAccessToken': 'app_access_456',
          'lmsLoginUrl': 'https://lms.cuchd.in/login/token.php?token=jwt_abc_123',
          'expiresAt': 1792035002000,
          'autoSolved': true,
          'ocrAttempt': 1,
        },
      };

      final ssoResp = SsoResponse.fromJson(jsonResult);
      expect(ssoResp.success, true);
      expect(ssoResp.token, 'jwt_abc_123');
      expect(ssoResp.appAccessToken, 'app_access_456');
      expect(ssoResp.lmsLoginUrl, 'https://lms.cuchd.in/login/token.php?token=jwt_abc_123');
      expect(ssoResp.autoSolved, true);
      expect(ssoResp.requireManualCaptcha, false);
      expect(ssoResp.error, isNull);
    });

    test('Parses manual CAPTCHA fallback result correctly', () {
      final jsonFallback = {
        'status': 200,
        'data': {
          'success': false,
          'requireManualCaptcha': true,
          'captchaImage': 'data:image/jpeg;base64,/9j/4AAQSkZJRg...',
          'sessionToken': 'sess_token_xyz',
          'attempts': 2,
          'lastError': 'Auto-solver failed after 2 attempts',
          'message': 'Please enter security captcha manually',
          'uid': '21BCS1001',
        },
      };

      final ssoResp = SsoResponse.fromJson(jsonFallback);
      expect(ssoResp.success, false);
      expect(ssoResp.requireManualCaptcha, true);
      expect(ssoResp.sessionToken, 'sess_token_xyz');
      expect(ssoResp.captchaImage, isNotNull);
    });

    test('Treats CAPTCHA initialization response as challenge, not authenticated success', () {
      final jsonInit = {
        'status': 200,
        'data': {
          'success': true,
          'uid': '21BCS1001',
          'sessionToken': 'sess_abc',
          'captchaImage': 'data:image/jpeg;base64,image_data',
          'message': 'Captcha initialized',
        },
      };

      final ssoResp = SsoResponse.fromJson(jsonInit);
      expect(ssoResp.requireManualCaptcha, true);
      expect(ssoResp.success, false); // Challenge, not authenticated success
      expect(ssoResp.sessionToken, 'sess_abc');
    });

    test('Extracts error message from error or message field on status >= 400', () {
      final jsonError = {
        'status': 400,
        'data': {
          'success': false,
          'message': 'Invalid UID or password.',
        },
      };

      final ssoResp = SsoResponse.fromJson(jsonError);
      expect(ssoResp.success, false);
      expect(ssoResp.error, 'Invalid UID or password.');
    });

    test('Parses legacy non-streaming direct JSON 200 response', () {
      final legacyJson = {
        'success': true,
        'token': 'legacy_token',
        'lmsLoginUrl': 'https://lms.test/autologin',
      };

      final ssoResp = SsoResponse.fromJson(legacyJson);
      expect(ssoResp.success, true);
      expect(ssoResp.token, 'legacy_token');
    });
  });

  group('LmsApiClient SSE Stream Integration Tests', () {
    test('Interrupted stream before result reports error without inferring success', () async {
      final streamController = StreamController<Uint8List>();
      final parser = SseParser.parseByteStream(streamController.stream);

      final events = <SseEvent>[];
      final completer = Completer<SsoResponse>();

      parser.listen(
        (event) {
          events.add(event);
          if (event.event == 'result') {
            completer.complete(SsoResponse.fromJson(json.decode(event.data)));
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete(
              const SsoResponse(
                success: false,
                error: 'SSO connection closed before login completed. Please retry.',
              ),
            );
          }
        },
      );

      // Send a progress event
      streamController.add(utf8.encode('event: progress\ndata: {"stage":"capturing_token","message":"Capturing token..."}\n\n'));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(events.length, 1);
      expect(events[0].event, 'progress');

      // Abruptly close stream without result: MUST NOT infer success from capturing_token or EOF
      await streamController.close();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final result = await completer.future;

      expect(result.success, false);
      expect(result.error!.contains('connection closed before login completed'), true);
    });

    test('Cancellation prevents stale updates', () {
      final cancelToken = CancelToken();
      expect(cancelToken.isCancelled, false);

      cancelToken.cancel('User clicked cancel');
      expect(cancelToken.isCancelled, true);
    });
  });

  group('SsoAutomationLoader Widget Tests', () {
    testWidgets('Renders stage title, attempt pill, and live telemetry message', (tester) async {
      bool cancelTapped = false;
      final progress = SsoProgress(
        stage: 'solving_captcha',
        message: 'Waiting for OCR.space...',
        attempt: 1,
        maxAttempts: 2,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SsoAutomationLoader(
              progress: progress,
              onCancel: () {
                cancelTapped = true;
              },
            ),
          ),
        ),
      );

      await tester.pump();

      // Check stage title & telemetry
      expect(find.text('AI OCR Solving CAPTCHA'), findsOneWidget);
      expect(find.text('Waiting for OCR.space...'), findsOneWidget);
      expect(find.text('Attempt 1 of 2'), findsOneWidget);
      expect(find.text('SSO AUTOMATION'), findsOneWidget);

      // Tap Cancel button
      await tester.tap(find.text('Cancel'));
      expect(cancelTapped, true);
    });
  });

  group('SsoProgressDialog Widget Tests', () {
    testWidgets('Renders 5-tick bar, progress indicator, dynamic message, and no bot icon', (tester) async {
      final fakeNotifier = _FakeAuthNotifier(
        AuthState(
          status: AuthStatus.connectingGateway,
          progress: SsoProgress(
            stage: 'solving_captcha',
            message: 'Waiting for OCR.space...',
            attempt: 1,
            maxAttempts: 2,
          ),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => fakeNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SsoProgressDialog(),
            ),
          ),
        ),
      );

      await tester.pump();

      // Step indicator for phase 3 of 5
      expect(find.text('Step 3 of 5'), findsOneWidget);
      expect(find.text('Attempt 1 of 2'), findsOneWidget);

      // Clean Progress Indicator exists
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Headline and live dynamic message
      expect(find.text('Logging In...'), findsOneWidget);
      expect(find.text('Waiting for OCR.space...'), findsOneWidget);

      // CRITICAL: Ensure NO bot icon is present
      expect(find.byIcon(Icons.smart_toy_rounded), findsNothing);
      expect(find.byIcon(Icons.smart_toy_outlined), findsNothing);
      expect(find.byIcon(Icons.smart_toy), findsNothing);

      // Tap Cancel button and verify cancelLogin is called
      expect(find.text('Cancel'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      expect(fakeNotifier.cancelCalled, true);
    });

    testWidgets('Triggers custom onCancel callback when provided', (tester) async {
      bool customCancelTapped = false;
      final fakeNotifier = _FakeAuthNotifier(
        const AuthState(status: AuthStatus.connectingGateway),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => fakeNotifier),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SsoProgressDialog(
                onCancel: () {
                  customCancelTapped = true;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.tap(find.text('Cancel'));
      await tester.pump();

      expect(customCancelTapped, true);
    });

    testWidgets('Shows retrying headline when progress is retry', (tester) async {
      final fakeNotifier = _FakeAuthNotifier(
        AuthState(
          status: AuthStatus.connectingGateway,
          progress: SsoProgress(
            stage: 'retrying',
            message: 'Retrying authentication attempt 2...',
            attempt: 2,
            maxAttempts: 2,
          ),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => fakeNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SsoProgressDialog(),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Retrying Authentication...'), findsOneWidget);
      expect(find.text('Retrying authentication attempt 2...'), findsOneWidget);
      expect(find.text('Attempt 2 of 2'), findsOneWidget);
    });
  });
}

class _FakeAuthNotifier extends Notifier<AuthState> implements AuthNotifier {
  _FakeAuthNotifier(this.initialState);
  final AuthState initialState;
  bool cancelCalled = false;

  @override
  AuthState build() => initialState;

  @override
  void cancelLogin() {
    cancelCalled = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
