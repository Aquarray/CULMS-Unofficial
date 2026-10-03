import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cuims_unofficial2/data/models/app_settings.dart';
import 'package:cuims_unofficial2/data/models/course_content.dart';
import 'package:cuims_unofficial2/ui/screens/courses/ai_study_prompt_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testUnit = CourseUnit(
    id: '1',
    title: 'Unit 1: Introduction to Research',
    activities: const [
      CourseActivity(
        id: '101',
        name: 'Lecture 1 Slides',
        url: 'https://lms.cuims.in/mod/resource/view.php?id=101',
        iconType: 'file',
        typeName: 'File',
      ),
    ],
  );

  group('AiStudyPromptSheet Tests', () {
    test('buildPrompt includes Subject name on top and exact role instructions', () {
      final prompt = AiStudyPromptSheet.buildPrompt(
        courseName: 'RESEARCH METHODOLOGY',
        unitTitle: testUnit.title,
      );

      // Verify subject is at the top
      expect(prompt.startsWith('Subject: RESEARCH METHODOLOGY - Unit 1: Introduction to Research'), true);

      // Verify role and core sections
      expect(prompt.contains('ROLE: You are a study-material assistant'), true);
      expect(prompt.contains('SOURCE PRIORITY:'), true);
      expect(prompt.contains('WORKFLOW:'), true);
      expect(prompt.contains('MST-style prep, EST-style prep, or both'), true);
      expect(prompt.contains('MASTER SYLLABUS LIST:'), true);
      expect(prompt.contains('CONSTRAINTS:'), true);
      expect(prompt.contains('Ask user to attcah the zip file if not given'), true);
    });

    testWidgets('Renders sheet with Gemini and ChatGPT options and copies prompt', (tester) async {
      String? copiedText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            copiedText = (methodCall.arguments as Map)['text'] as String?;
            return null;
          }
          return null;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => AiStudyPromptSheet.show(
                  context,
                  courseName: 'RESEARCH METHODOLOGY',
                  unit: testUnit,
                ),
                child: const Text('Open AI Sheet'),
              ),
            ),
          ),
        ),
      );

      // Open the sheet
      await tester.tap(find.text('Open AI Sheet'));
      await tester.pumpAndSettle();

      // Verify sheet contents
      expect(find.text('Learn with AI'), findsOneWidget);
      expect(find.text('Google Gemini'), findsOneWidget);
      expect(find.text('OpenAI ChatGPT'), findsOneWidget);
      expect(find.text('Attach your exported Unit ZIP'), findsOneWidget);
      expect(find.text('Copy Prompt'), findsOneWidget);

      // Tap Copy Prompt button
      await tester.tap(find.text('Copy Prompt'));
      await tester.pumpAndSettle();

      expect(copiedText, isNotNull);
      expect(copiedText!.contains('Subject: RESEARCH METHODOLOGY'), true);
      expect(copiedText!.contains('ROLE: You are a study-material assistant'), true);
    });

    test('AppSettings enableLearnWithAi defaults to true and can be toggled', () {
      const defaultSettings = AppSettings();
      expect(defaultSettings.enableLearnWithAi, true);

      final disabled = defaultSettings.copyWith(enableLearnWithAi: false);
      expect(disabled.enableLearnWithAi, false);

      final serialized = disabled.toJson();
      final restored = AppSettings.fromJson(serialized);
      expect(restored.enableLearnWithAi, false);
    });
  });
}
