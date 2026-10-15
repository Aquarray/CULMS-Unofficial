import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../data/models/course_content.dart';
import '../../../providers/settings_provider.dart';
import '../../widgets/ai_brand_icons.dart';

/// Modal sheet for "Learn with AI" feature.
/// Allows the user to select their AI provider (Gemini or ChatGPT),
/// copies an exam-ready learning prompt with the Subject header,
/// reminds them to attach the unit ZIP file, and launches the AI app/web.
class AiStudyPromptSheet extends ConsumerStatefulWidget {
  final String courseName;
  final CourseUnit unit;
  final VoidCallback? onExportZip;
  final int? itemsCount;
  final bool? isChapter;
  final String? chapterNumber;

  const AiStudyPromptSheet({
    super.key,
    required this.courseName,
    required this.unit,
    this.onExportZip,
    this.itemsCount,
    this.isChapter,
    this.chapterNumber,
  });

  /// Static helper to display the sheet
  static void show(
    BuildContext context, {
    required String courseName,
    required CourseUnit unit,
    VoidCallback? onExportZip,
    int? itemsCount,
    bool? isChapter,
    String? chapterNumber,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => AiStudyPromptSheet(
        courseName: courseName,
        unit: unit,
        onExportZip: onExportZip,
        itemsCount: itemsCount,
        isChapter: isChapter,
        chapterNumber: chapterNumber,
      ),
    );
  }

  static String resolveUnitNumber(CourseUnit? unit, String unitTitle) {
    if (unit != null) {
      final unitMatch = RegExp(r'(?:unit)[\s\-_]*(\d+)', caseSensitive: false).firstMatch(unit.parentUnit) ??
          RegExp(r'(?:unit)[\s\-_]*(\d+)', caseSensitive: false).firstMatch(unit.title);
      if (unitMatch != null) {
        return unitMatch.group(1)!;
      }
      final digits = RegExp(r'\d+').firstMatch(unit.parentUnit);
      if (digits != null) {
        return digits.group(0)!;
      }
      if (unit.sectionNumber > 0) {
        return unit.sectionNumber.toString();
      }
    }
    final titleMatch = RegExp(r'(?:unit)[\s\-_]*(\d+)', caseSensitive: false).firstMatch(unitTitle);
    if (titleMatch != null) {
      return titleMatch.group(1)!;
    }
    final titleDigits = RegExp(r'\d+').firstMatch(unitTitle);
    if (titleDigits != null) {
      return titleDigits.group(0)!;
    }
    return '1';
  }

  static String resolveChapterNumber(CourseUnit? unit, String unitTitle, {bool? isChapter}) {
    if (isChapter == false) {
      return '';
    }

    final targetText = (unit != null && unit.title.isNotEmpty) ? unit.title : unitTitle;
    final match = RegExp(r'(?:chapter|chap|ch)[\s\-_]*(\d+)', caseSensitive: false).firstMatch(targetText);
    if (match != null) {
      return match.group(1)!;
    }

    if (isChapter == true) {
      final numMatch = RegExp(r'^\s*(\d+)').firstMatch(targetText);
      if (numMatch != null) {
        return numMatch.group(1)!;
      }
      if (unit != null && unit.sectionNumber > 0) {
        return unit.sectionNumber.toString();
      }
    }

    return '';
  }

  static String resolveItemsCount(CourseUnit? unit, int? itemsCount) {
    if (itemsCount != null) {
      return itemsCount.toString();
    }
    if (unit != null) {
      final valid = unit.activities.where((a) =>
          a.iconType == 'file' || a.iconType == 'folder' || a.iconType == 'page');
      return (valid.isNotEmpty ? valid.length : unit.activities.length).toString();
    }
    return '0';
  }

  /// Builds the structured exam-ready study prompt with Subject on top.
  static String buildPrompt({
    required String courseName,
    required String unitTitle,
    String? template,
    CourseUnit? unit,
    int? itemsCount,
    bool? isChapter,
    String? chapterNumber,
  }) {
    if (template != null && template.trim().isNotEmpty) {
      final cleanSubject = courseName.trim();
      final unitNum = resolveUnitNumber(unit, unitTitle);
      final chapNum = chapterNumber ?? resolveChapterNumber(unit, unitTitle, isChapter: isChapter);
      final count = resolveItemsCount(unit, itemsCount);

      return template
          .replaceAll('{%subject_name%}', cleanSubject)
          .replaceAll('{%course_name%}', cleanSubject)
          .replaceAll('{%unit_number%}', unitNum)
          .replaceAll('{%unit%}', unitNum)
          .replaceAll('{%chapter_number%}', chapNum)
          .replaceAll('{%chapter%}', chapNum)
          .replaceAll('{%items_count%}', count)
          .replaceAll('{%number_of_items%}', count);
    }

    final cleanSubject = courseName.trim();
    final subjectLine = unitTitle.trim().isNotEmpty
        ? 'Subject: $cleanSubject - ${unitTitle.trim()}'
        : 'Subject: $cleanSubject';

    return '''$subjectLine

ROLE: You are a study-material assistant that converts a ZIP archive of unit/chapter files (PPT, DOCX, TXT) into a structured, exam-ready learning guide.

SOURCE PRIORITY: When extracting content, treat PPT as the primary source, DOCX as secondary, and TXT as tertiary. If sources conflict, prioritize in this order: DOCX > PPT > TXT. If DOCX contains topics absent from the PPT, include them in the syllabus anyway, clearly marked as "(from DOCX)".

WORKFLOW:
1. On receiving the ZIP, extract and parse all PPT, DOCX, and TXT files for the unit.
2. Before generating any content, ask the user:
   a. Subject name (user will paste this above the prompt).
   b. Whether they want MST-style prep, EST-style prep, or both.
      - MST: 2-mark and 5-mark Q&A.
      - EST: 2-mark, 5-mark, and 10-mark Q&A.
   c. Confirm the user wants to proceed topic-by-topic (one topic at a time, waiting for user confirmation before moving to the next).
3. Build a MASTER SYLLABUS LIST: a hierarchical list of all topics and subtopics (with levels, e.g., 1, 1.1, 1.1.1) found across all sources combined. Output this list immediately after analysis, BEFORE starting topic-by-topic teaching. Repeat/reference this master list at the start of each subsequent topic's output so it is never lost, even if conversation context is long.
4. For each topic (taken one at a time, in syllabus order, waiting for user go-ahead to proceed to the next):
   a. Give a detailed summary of the topic.
   b. Explicitly connect it to the previous topic (if a relationship exists), with a concrete example illustrating the connection.
   c. Use terminology/jargon with definitions in brackets on first use. Shorten the bracketed definition on second use. Drop the bracketed definition entirely by the third use (assume the term is now learned).
   d. Adapt teaching style to subject type:
      - For quantitative subjects (math, physics, etc.): give one worked example per concept, then practice questions covering all basic variants of that concept, followed by 1–2 combined/mixed questions integrating multiple concepts.
      - For subjective/theory subjects: provide Q&A pairs formatted by mark-weight (2/5/10 marks as selected by the user), using jargon-with-brackets as described above.
   e. For diagrams/visuals: do NOT generate images. Instead, provide a working link to a clear, easy-to-understand diagram from any credible public source (no specific source preference required).
5. Ensure complete topical coverage — cross-check against the master syllabus list before concluding each topic and before finishing the unit.
6. Maintain the master syllabus list as top priority context — re-state it at logical checkpoints (e.g., every few topics) to prevent loss due to context limits.

CONSTRAINTS:
- Do not skip any topic present in any of the three source types.
- Do not generate images; only links.
- Wait for explicit user confirmation (MST/EST choice) before producing any Q&A content.
- Proceed strictly topic-by-topic; do not dump the entire unit's content in one response.
- Ask user to attcah the zip file if not given''';
  }

  @override
  ConsumerState<AiStudyPromptSheet> createState() => _AiStudyPromptSheetState();
}

class _AiStudyPromptSheetState extends ConsumerState<AiStudyPromptSheet> {
  bool _showPromptPreview = false;

  String get _promptText {
    final settings = ref.read(settingsProvider);
    return AiStudyPromptSheet.buildPrompt(
      courseName: widget.courseName,
      unitTitle: widget.unit.title,
      template: settings.aiStudyPromptTemplate,
      unit: widget.unit,
      itemsCount: widget.itemsCount,
      isChapter: widget.isChapter,
      chapterNumber: widget.chapterNumber,
    );
  }

  Future<void> _selectProvider({
    required String name,
    required String url,
  }) async {
    // 1. Copy prompt to clipboard
    await Clipboard.setData(ClipboardData(text: _promptText));
    HapticFeedback.lightImpact();

    if (!mounted) return;

    // 2. Close sheet
    Navigator.of(context).pop();

    // 3. Show helpful guidance SnackBar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Prompt copied! Attach the exported ZIP in $name and paste.',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ),
    );

    // 4. Open link via url_launcher
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Fallback
    }
  }

  Future<void> _copyPromptOnly() async {
    await Clipboard.setData(ClipboardData(text: _promptText));
    HapticFeedback.selectionClick();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Study prompt copied to clipboard!'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // Header: Title & Subject
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Learn with AI',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${widget.courseName} • ${widget.unit.title}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : const Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Instruction Card: Attach ZIP File Reminder
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E2638)
                    : const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF374151)
                      : const Color(0xFFC7D2FE),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.folder_zip_rounded,
                    color: Color(0xFF6366F1),
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Attach your exported Unit ZIP',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ensure this unit has been exported as a ZIP (located in your Downloads / device files). When the AI opens, attach that ZIP file and paste your copied prompt.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                            height: 1.35,
                          ),
                        ),
                        if (widget.onExportZip != null) ...[
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () {
                              Navigator.of(context).pop();
                              widget.onExportZip?.call();
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.download_rounded,
                                    size: 15,
                                    color: theme.primaryColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Export Unit ZIP first',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: theme.primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Provider selection header
            const Text(
              'Select AI Provider',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),

            // 1. Google Gemini Option
            _AiProviderTile(
              title: 'Google Gemini',
              subtitle: 'Opens gemini.google.com with prompt copied',
              iconWidget: const GeminiIcon(size: 22, useGradient: true),
              accentColor: const Color(0xFF3B82F6),
              isDark: isDark,
              onTap: () => _selectProvider(
                name: 'Gemini',
                url: 'https://gemini.google.com/app',
              ),
            ),
            const SizedBox(height: 10),

            // 2. OpenAI ChatGPT Option
            _AiProviderTile(
              title: 'OpenAI ChatGPT',
              subtitle: 'Opens chatgpt.com with prompt copied',
              iconWidget: const OpenAiIcon(size: 22, color: Color(0xFF10A37F)),
              accentColor: const Color(0xFF10A37F),
              isDark: isDark,
              onTap: () => _selectProvider(
                name: 'ChatGPT',
                url: 'https://chatgpt.com/',
              ),
            ),
            const SizedBox(height: 16),

            // Quick Actions: Copy Prompt & Preview
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _copyPromptOnly,
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copy Prompt'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _showPromptPreview = !_showPromptPreview;
                      });
                    },
                    icon: Icon(
                      _showPromptPreview
                          ? Icons.expand_less_rounded
                          : Icons.visibility_outlined,
                      size: 16,
                    ),
                    label: Text(_showPromptPreview ? 'Hide Prompt' : 'View Prompt'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Expandable Prompt Preview
            if (_showPromptPreview) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                constraints: const BoxConstraints(maxHeight: 220),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF16191E) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF2A2E35) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _promptText,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AiProviderTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget iconWidget;
  final Color accentColor;
  final bool isDark;
  final VoidCallback onTap;

  const _AiProviderTile({
    required this.title,
    required this.subtitle,
    required this.iconWidget,
    required this.accentColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2228) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? const Color(0xFF2A2E35) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: SizedBox(
                width: 22,
                height: 22,
                child: Center(child: iconWidget),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }
}
