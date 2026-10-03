import 'package:flutter/material.dart';
import '../browser/app_browser_screen.dart';

/// Specialized in-app browser wrapper tailored for Moodle Quizzes and MSTs.
class QuizWebViewScreen extends StatelessWidget {
  final String quizUrl;
  final String quizTitle;
  final String? courseName;

  const QuizWebViewScreen({
    super.key,
    required this.quizUrl,
    required this.quizTitle,
    this.courseName,
  });

  @override
  Widget build(BuildContext context) {
    return AppBrowserScreen(
      initialUrl: quizUrl,
      initialTitle: quizTitle,
      courseName: courseName,
      forceQuizMode: true,
    );
  }
}
