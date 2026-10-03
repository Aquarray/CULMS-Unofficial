import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:cuims_unofficial2/core/services/tts_service.dart';
import 'package:cuims_unofficial2/data/models/app_settings.dart';
import 'package:cuims_unofficial2/data/models/assignment.dart';
import 'package:cuims_unofficial2/data/models/auth_state.dart';
import 'package:cuims_unofficial2/data/models/calendar_event.dart';
import 'package:cuims_unofficial2/data/models/course.dart';
import 'package:cuims_unofficial2/data/models/course_content.dart';

void main() {
  group('AppSettings Tests', () {
    test('Default values and JSON serialization', () {
      const settings = AppSettings();
      expect(settings.themeMode, AppThemeMode.system);
      expect(settings.fontFamily, AppFontFamily.inter);
      expect(settings.fontScale, 1.0);
      expect(settings.enableOfflineCache, true);

      final jsonStr = settings.toJson();
      final restored = AppSettings.fromJson(jsonStr);

      expect(restored.themeMode, settings.themeMode);
      expect(restored.fontFamily, settings.fontFamily);
      expect(restored.fontScale, settings.fontScale);
      expect(restored.enableDeadlineAlarms, true);
      expect(restored.alarm24HoursBefore, true);
      expect(restored.alarm1HourBefore, true);
      expect(restored.alarmAtExactTime, true);
      expect(restored.enableLearnWithAi, true);
    });

    test('CopyWith updates individual fields', () {
      const settings = AppSettings();
      final updated = settings.copyWith(
        themeMode: AppThemeMode.dark,
        fontScale: 1.2,
        readerContrast: ReaderContrast.oledBlack,
        enableDeadlineAlarms: false,
        alarm24HoursBefore: false,
        enableLearnWithAi: false,
      );

      expect(updated.themeMode, AppThemeMode.dark);
      expect(updated.fontScale, 1.2);
      expect(updated.readerContrast, ReaderContrast.oledBlack);
      expect(updated.enableLearnWithAi, false);
      expect(updated.fontFamily, AppFontFamily.inter);
      expect(updated.enableDeadlineAlarms, false);
      expect(updated.alarm24HoursBefore, false);
      expect(updated.alarm1HourBefore, true);
    });
  });

  group('Course Model Tests', () {
    test('Parse course list from Moodle AJAX JSON', () {
      final sampleMoodleResponse = json.encode([
        {
          "error": false,
          "data": {
            "courses": [
              {
                "id": 124844,
                "fullname": "CONT_23CST-441 :: RESEARCH METHODOLOGY",
                "shortname": "CONT_23CST-441",
                "viewurl": "https://lms.cuchd.in/course/view.php?id=124844",
                "progress": 45,
                "coursecategory": "MSC_Content : ODD_26271"
              }
            ]
          }
        }
      ]);

      final courses = Course.fromJsonList(sampleMoodleResponse);
      expect(courses.length, 1);
      final course = courses.first;
      expect(course.id, 124844);
      expect(course.courseCode, '23CST-441');
      expect(course.cleanTitle, 'RESEARCH METHODOLOGY');
      expect(course.progress, 45);
    });
  });

  group('Calendar Event Tests', () {
    test('Parse calendar event from Moodle AJAX JSON', () {
      final sampleResponse = json.encode([
        {
          "error": false,
          "data": {
            "events": [
              {
                "id": 405365,
                "name": "Quiz 1 Due",
                "timesort": 1790833920,
                "formattedtime": "<span>Thursday, 1 October</span>",
                "course": {
                  "id": 124844,
                  "fullname": "Research Methodology"
                },
                "action": {
                  "name": "Attempt quiz now",
                  "url": "https://lms.cuchd.in/mod/quiz/view.php?id=3661532"
                }
              }
            ]
          }
        }
      ]);

      final events = LmsCalendarEvent.fromJsonList(sampleResponse);
      expect(events.length, 1);
      final event = events.first;
      expect(event.id, 405365);
      expect(event.name, 'Quiz 1 Due');
      expect(event.courseName, 'Research Methodology');
      expect(event.actionName, 'Attempt quiz now');
      expect(event.cleanFormattedTime, 'Thursday, 1 October');
    });
  });

  group('Content Models Tests', () {
    test('LmsContentItem flags PDF, office, and markdown properly', () {
      const pdfItem = LmsContentItem(
        name: 'Lecture1.pdf',
        fileType: 'pdf',
        viewerUrl: 'https://lms.cuchd.in/local/officeviewer/pdf.php?id=1',
      );
      expect(pdfItem.isPdf, true);
      expect(pdfItem.isOfficeDoc, true); // officeviewer rendered

      const docxItem = LmsContentItem(
        name: 'Assignment.docx',
        fileType: 'docx',
      );
      expect(docxItem.isOfficeDoc, true);
      expect(docxItem.isPdf, false);

      const mdItem = LmsContentItem(
        name: 'Notes.md',
        fileType: 'md',
      );
      expect(mdItem.isMarkdown, true);
    });

    test('CourseUnit and CourseActivity parse JSON correctly', () {
      final unitJson = {
        'id': 'sec_1',
        'title': 'Unit 1: Introduction to Penetration Testing',
        'summary': 'Covers fundamentals and lab setup',
        'activities': [
          {
            'id': '133428_0',
            'name': 'Module 1 Slides',
            'typeName': 'PDF Document',
            'url': 'https://lms.cuchd.in/mod/resource/view.php?id=3661500',
            'iconType': 'file',
          },
          {
            'id': '133428_1',
            'name': 'Lab MST',
            'typeName': 'Quiz',
            'url': 'https://lms.cuchd.in/mod/quiz/view.php?id=3661501',
            'iconType': 'quiz',
          }
        ]
      };

      final unit = CourseUnit.fromJson(unitJson);
      expect(unit.id, 'sec_1');
      expect(unit.title, 'Unit 1: Introduction to Penetration Testing');
      expect(unit.activities.length, 2);
      expect(unit.activities.first.name, 'Module 1 Slides');
      expect(unit.activities.first.iconType, 'file');
      expect(unit.activities.last.typeName, 'Quiz');

      final exportedMap = unit.toJson();
      expect(exportedMap['title'], unit.title);
      expect((exportedMap['activities'] as List).length, 2);
    });

    test('Course categorizes Content vs Assessment courses correctly', () {
      final contentCourse = Course.fromJson({
        'id': 124844,
        'fullname': 'CONT_23CST-441 :: RESEARCH METHODOLOGY',
        'shortname': 'CONT_23CST-441',
      });
      expect(contentCourse.isContentCourse, true);
      expect(contentCourse.isAssessmentCourse, false);
      expect(contentCourse.courseTypeLabel, 'Study Material');

      final assessmentCourse = Course.fromJson({
        'id': 130106,
        'fullname': '23CST-441_23BIS-2_ALL :: RESEARCH METHODOLOGY',
        'shortname': '23CST-441',
      });
      expect(assessmentCourse.isContentCourse, false);
      expect(assessmentCourse.isAssessmentCourse, true);
      expect(assessmentCourse.courseTypeLabel, 'Tests & MSTs');
    });

    test('CourseUnit categorizes Theory vs Practical vs Overview correctly', () {
      final overviewUnit = CourseUnit.fromJson({
        'id': '101',
        'title': 'Course Overview',
        'sectionNumber': 0,
      });
      expect(overviewUnit.isOverview, true);
      expect(overviewUnit.parentUnit, 'Course Overview');

      final theoryUnit = CourseUnit.fromJson({
        'id': '102',
        'title': 'Chapter 1.2 - Relational Model',
        'sectionNumber': 3,
      });
      expect(theoryUnit.isTheory, true);
      expect(theoryUnit.parentUnit, 'Unit 1');

      final practicalUnit = CourseUnit.fromJson({
        'id': '103',
        'title': 'Experiment-2.2: SQL Joins',
        'sectionNumber': 18,
      });
      expect(practicalUnit.isPractical, true);
      expect(practicalUnit.parentUnit, 'Practical Unit 2');
    });

    test('CourseUnit categorizes Assessment course sections (Assessment Model, Live Sessions, Surprise Test, Quiz)', () {
      final assessmentModelUnit = CourseUnit.fromJson({
        'id': '1548440',
        'title': 'Assessment Model',
        'sectionNumber': 0,
        'sectionUrl': 'https://lms.cuchd.in/course/view.php?id=134094&section=0',
      });
      expect(assessmentModelUnit.isAssessmentModel, true);
      expect(assessmentModelUnit.category, CourseSectionCategory.assessmentModel);
      expect(assessmentModelUnit.parentUnit, 'Assessment Model');
      expect(assessmentModelUnit.sectionUrl, 'https://lms.cuchd.in/course/view.php?id=134094&section=0');

      final liveSessionUnit = CourseUnit.fromJson({
        'id': '1548441',
        'title': 'Live Session Links',
        'sectionNumber': 1,
      });
      expect(liveSessionUnit.isLiveSessions, true);
      expect(liveSessionUnit.category, CourseSectionCategory.liveSessions);
      expect(liveSessionUnit.parentUnit, 'Live Session Links');

      final surpriseTestUnit = CourseUnit.fromJson({
        'id': '1548462',
        'title': 'Surprise Test',
        'sectionNumber': 18,
      });
      expect(surpriseTestUnit.isSurpriseTest, true);
      expect(surpriseTestUnit.category, CourseSectionCategory.surpriseTest);
      expect(surpriseTestUnit.parentUnit, 'Surprise Tests');

      final quizUnit = CourseUnit.fromJson({
        'id': '1548463',
        'title': 'Quiz',
        'sectionNumber': 19,
      });
      expect(quizUnit.isQuiz, true);
      expect(quizUnit.category, CourseSectionCategory.quiz);
      expect(quizUnit.parentUnit, 'Quizzes & MSTs');

      // Test toJson and restoration
      final jsonMap = surpriseTestUnit.toJson();
      expect(jsonMap['category'], 'surpriseTest');
      final restored = CourseUnit.fromJson(jsonMap);
      expect(restored.isSurpriseTest, true);
      expect(restored.title, 'Surprise Test');
    });
  });

  group('Assignment Models Tests', () {
    test('AssignmentDetail JSON serialization and status flags', () {
      final now = DateTime.now();
      final detail = AssignmentDetail(
        id: 3726596,
        name: 'ASSIGNMENT-2',
        courseName: 'AGILE DEVELOPMENT METHODOLOGIES',
        dueDate: 'Due: Sunday, 4 October 2026, 11:59 PM',
        openDate: 'Opened: Wednesday, 30 September 2026, 12:00 AM',
        instructionsText: 'Please submit your agile sprint report.',
        submissionStatus: 'Submitted for grading',
        gradingStatus: 'Graded',
        timeRemaining: '4 days 12 hours remaining',
        canEditSubmission: true,
        canRemoveSubmission: true,
        editButtonLabel: 'Edit submission',
        submissionCommentsCount: 2,
        feedbackGrade: '10.00 / 10.00',
        feedbackGradedOn: 'Thursday, 1 October 2026, 9:00 AM',
        feedbackGradedBy: 'Prof. Sharma',
        feedbackComments: 'Well structured and clear methodology.',
        teacherFiles: const [
          AssignmentTeacherFile(
            name: 'Assignment-2_Problem.pdf',
            downloadUrl: 'https://lms.cuchd.in/pluginfile.php/123/problem.pdf',
            fileType: 'pdf',
          ),
        ],
        submittedFiles: const [
          AssignmentSubmissionFile(
            name: 'Sprint_Report_Final.pdf',
            downloadUrl: 'https://lms.cuchd.in/pluginfile.php/456/submission.pdf',
            timeModified: 'Wednesday, 30 September 2026, 10:30 AM',
          ),
        ],
        extraStatusFields: const {
          'Submission comments': 'Comments (2)',
        },
        fetchedAt: now,
      );

      expect(detail.isSubmitted, true);
      expect(detail.isGraded, true);
      expect(detail.canRemoveSubmission, true);
      expect(detail.submissionCommentsCount, 2);
      expect(detail.feedbackGrade, '10.00 / 10.00');
      expect(detail.teacherFiles.first.isPdf, true);
      expect(detail.submittedFiles.first.isPdf, true);

      final jsonMap = detail.toJson();
      final restored = AssignmentDetail.fromJson(jsonMap);

      expect(restored.id, 3726596);
      expect(restored.name, 'ASSIGNMENT-2');
      expect(restored.courseName, 'AGILE DEVELOPMENT METHODOLOGIES');
      expect(restored.teacherFiles.length, 1);
      expect(restored.teacherFiles.first.name, 'Assignment-2_Problem.pdf');
      expect(restored.submittedFiles.length, 1);
      expect(restored.submittedFiles.first.name, 'Sprint_Report_Final.pdf');
      expect(restored.canEditSubmission, true);
      expect(restored.canRemoveSubmission, true);
      expect(restored.submissionCommentsCount, 2);
      expect(restored.feedbackGrade, '10.00 / 10.00');
      expect(restored.feedbackGradedBy, 'Prof. Sharma');
      expect(restored.extraStatusFields['Submission comments'], 'Comments (2)');
    });

    test('AssignmentSubmissionConfig and DraftFileInfo tests', () {
      const config = AssignmentSubmissionConfig(
        assignId: 3726596,
        itemId: 582269922,
        clientId: '6abc97ba96e14',
        maxBytes: 5242880,
        maxBytesText: '5.0 MB',
        maxFiles: 1,
        acceptedTypes: ['.pdf', '.docx', '.doc'],
        contextId: '5211474',
        author: 'Student Name',
        formAction: 'https://lms.cuchd.in/mod/assign/view.php',
        hiddenFields: {
          'id': '3726596',
          'action': 'savesubmission',
          'userid': '741566',
        },
        hasExistingSubmission: true,
        draftFiles: [
          DraftFileInfo(
            filename: 'draft_document.pdf',
            filesize: '1.2 MB',
            url: 'https://lms.cuchd.in/draftfile.php/582269922/draft.pdf',
          ),
        ],
      );

      expect(config.assignId, 3726596);
      expect(config.itemId, 582269922);
      expect(config.maxFiles, 1);
      expect(config.maxBytesText, '5.0 MB');
      expect(config.hasExistingSubmission, true);
      expect(config.hiddenFields['action'], 'savesubmission');
      expect(config.draftFiles.length, 1);
      expect(config.draftFiles.first.filename, 'draft_document.pdf');

      final jsonMap = config.toJson();
      final restored = AssignmentSubmissionConfig.fromJson(jsonMap);

      expect(restored.assignId, config.assignId);
      expect(restored.clientId, config.clientId);
      expect(restored.formAction, 'https://lms.cuchd.in/mod/assign/view.php');
      expect(restored.hiddenFields['id'], '3726596');
      expect(restored.hasExistingSubmission, true);
      expect(restored.draftFiles.length, 1);
      expect(restored.draftFiles.first.filename, 'draft_document.pdf');

      // Test copyWith
      final updated = config.copyWith(draftFiles: const []);
      expect(updated.draftFiles.isEmpty, true);
      expect(updated.itemId, config.itemId);
    });

    test('AuthSession with studentName, moodleUserId, and copyWith', () {
      final session = AuthSession(
        uid: '25bcy70187',
        sesskey: '0d2umB71gR',
        moodleSession: '39bbalai2qu2devdsvq1m6u0ms',
        studentName: 'YUYUTSHU .',
        moodleUserId: '741566',
        authenticatedAt: DateTime.now(),
      );

      expect(session.studentName, 'YUYUTSHU .');
      expect(session.moodleUserId, '741566');

      final jsonStr = session.toJson();
      final restored = AuthSession.fromJson(jsonStr);

      expect(restored.studentName, 'YUYUTSHU .');
      expect(restored.moodleUserId, '741566');

      final updated = session.copyWith(studentName: 'YUYUTSHU UPDATED');
      expect(updated.studentName, 'YUYUTSHU UPDATED');
      expect(updated.moodleUserId, '741566');
    });
  });

  group('TTS and Voice Settings Tests', () {
    test('AppSettings preserves TTS configuration in JSON serialization', () {
      const settings = AppSettings();
      expect(settings.ttsSpeechRate, 0.5);
      expect(settings.ttsPitch, 1.0);
      expect(settings.ttsVolume, 1.0);
      expect(settings.ttsLanguage, 'en-US');

      final updated = settings.copyWith(
        ttsSpeechRate: 0.7,
        ttsPitch: 1.2,
        ttsVolume: 0.9,
        ttsLanguage: 'en-IN',
      );

      final jsonStr = updated.toJson();
      final restored = AppSettings.fromJson(jsonStr);

      expect(restored.ttsSpeechRate, 0.7);
      expect(restored.ttsPitch, 1.2);
      expect(restored.ttsVolume, 0.9);
      expect(restored.ttsLanguage, 'en-IN');
    });

    test('TtsNotifier.cleanMarkdown strips formatting for natural voice reading', () {
      const rawMarkdown = '''
# Welcome to Unit 1: OS Principles

Here is an **important** concept with *emphasis* and [link to portal](https://lms.cuchd.in).

```dart
void main() {
  print("Hello");
}
```

> Remember: Deadlines are strict.

- Item 1
- Item 2
''';

      final cleaned = TtsNotifier.cleanMarkdown(rawMarkdown);

      // Verify header symbols, code block, links, and bold asterisks are removed
      expect(cleaned.contains('#'), false);
      expect(cleaned.contains('**'), false);
      expect(cleaned.contains('*emphasis*'), false);
      expect(cleaned.contains('emphasis'), true);
      expect(cleaned.contains('https://lms.cuchd.in'), false);
      expect(cleaned.contains('link to portal'), true);
      expect(cleaned.contains('[Code Block Omitted]'), true);
      expect(cleaned.contains('print("Hello")'), false);
      expect(cleaned.contains('>'), false);
    });
  });
}


