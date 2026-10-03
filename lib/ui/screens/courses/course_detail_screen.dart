import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/course.dart';
import '../../../data/models/course_content.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/course_provider.dart';
import '../../../providers/settings_provider.dart';
import '../assignments/assignment_detail_screen.dart';
import '../browser/app_browser_screen.dart';
import '../quiz/quiz_webview_screen.dart';
import '../reader/markdown_viewer_screen.dart';
import '../reader/pdf_viewer_screen.dart';
import 'unit_export_sheet.dart';
import 'ai_study_prompt_sheet.dart';

class CourseDetailScreen extends ConsumerStatefulWidget {
  final Course course;

  const CourseDetailScreen({super.key, required this.course});

  @override
  ConsumerState<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends ConsumerState<CourseDetailScreen> {
  String _selectedTab = 'all';

  Future<void> _refreshMaterials() async {
    final apiClient = ref.read(lmsApiClientProvider);
    await apiClient.clearCourseUnitsCache(widget.course.id);
    ref.invalidate(courseUnitsProvider(widget.course.id));
  }

  void _openActivity(CourseActivity activity) async {
    // 1. Direct Web / Live Session Links: launch in-app browser with cookies
    if (activity.iconType == 'url' || activity.url.contains('mod/url')) {
      AppBrowserScreen.open(
        context,
        url: activity.url,
        title: activity.name,
      );
      return;
    }

    // 2. Assignments: Open in native AssignmentDetailScreen
    if (activity.iconType == 'assign' || activity.url.contains('mod/assign')) {
      final assignIdMatch = RegExp(r'[?&]id=(\d+)').firstMatch(activity.url);
      if (assignIdMatch != null) {
        final assignId = int.tryParse(assignIdMatch.group(1)!);
        if (assignId != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AssignmentDetailScreen(
                assignId: assignId,
                initialTitle: activity.name,
              ),
            ),
          );
          return;
        }
      }
    }

    // 3. Interactive Quizzes & Surprise Tests: launch in-app WebView with active student session
    if (activity.iconType == 'quiz' || activity.url.contains('mod/quiz')) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => QuizWebViewScreen(
            quizUrl: activity.url,
            quizTitle: activity.name,
            courseName: widget.course.fullname,
          ),
        ),
      );
      return;
    }

    // 4. Discussion Forums / Announcements: Open in-app browser with active cookies
    if (activity.iconType == 'forum' || activity.url.contains('mod/forum')) {
      AppBrowserScreen.open(
        context,
        url: activity.url,
        title: activity.name,
      );
      return;
    }

    // 4. Study documents, files, folders & pages: open in-app
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final content = await ref.read(lmsContentProvider(activity.url).future);
      if (mounted) Navigator.pop(context); // close loader

      if (!mounted) return;

      if (content.type == LmsItemType.singleDocument && content.items.isNotEmpty) {
        final item = content.items.first;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PdfViewerScreen(
              title: item.name,
              url: item.viewerUrl,
              downloadUrl: item.downloadUrl,
            ),
          ),
        );
      } else if (content.type == LmsItemType.folderDirectory) {
        _showFolderSheet(content);
      } else if (content.type == LmsItemType.pageContent) {
        final cleanText = (content.pageBodyHtml ?? '')
            .replaceAll(RegExp(r'<[^>]*>'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();

        final md = '''# ${content.pageTitle}

$cleanText
''';
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MarkdownViewerScreen(
              title: content.pageTitle,
              markdownContent: md,
            ),
          ),
        );
      } else {
        AppBrowserScreen.open(
          context,
          url: activity.url,
          title: activity.name,
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // close loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load item: $e')),
        );
      }
    }
  }

  void _showFolderSheet(LmsExtractedContent folderContent) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollCtrl) => Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.folder_open_rounded, color: Colors.amber, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      folderContent.pageTitle,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Expanded(
                child: ListView.separated(
                  controller: scrollCtrl,
                  itemCount: folderContent.items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, idx) {
                    final item = folderContent.items[idx];
                    return ListTile(
                      leading: _getFileIcon(item.fileType),
                      title: Text(item.name, style: const TextStyle(fontSize: 14)),
                      subtitle: Text(
                        '${item.fileType.toUpperCase()} File',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PdfViewerScreen(
                              title: item.name,
                              url: item.viewerUrl,
                              downloadUrl: item.downloadUrl,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getFileIcon(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return const Icon(Icons.picture_as_pdf_rounded, color: Colors.red);
      case 'pptx':
      case 'ppt':
        return const Icon(Icons.slideshow_rounded, color: Colors.orange);
      case 'docx':
      case 'doc':
        return const Icon(Icons.description_rounded, color: Colors.blue);
      default:
        return const Icon(Icons.insert_drive_file_rounded, color: Colors.grey);
    }
  }

  void _exportUnit(CourseUnit unit) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => UnitExportSheet(
        courseName: widget.course.cleanTitle,
        unit: unit,
      ),
    );
  }

  void _openLearnWithAi(CourseUnit unit) {
    AiStudyPromptSheet.show(
      context,
      courseName: widget.course.cleanTitle,
      unit: unit,
      onExportZip: () => _exportUnit(unit),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final unitsAsync = ref.watch(courseUnitsProvider(widget.course.id));
    final coursesState = ref.watch(coursesProvider);
    final companionCourse = coursesState.getCompanionCourse(widget.course);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.course.courseCode),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Materials',
            onPressed: _refreshMaterials,
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser_rounded),
            tooltip: 'Open in LMS',
            onPressed: () {
              AppBrowserScreen.open(
                context,
                url: widget.course.viewurl,
                title: widget.course.fullname,
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshMaterials,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Header Summary Card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: theme.primaryColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                widget.course.courseCode,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: theme.primaryColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: widget.course.isContentCourse
                                    ? const Color(0xFF3B82F6).withValues(alpha: 0.15)
                                    : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                widget.course.isContentCourse ? '📘 Study Material' : '📝 Tests & MSTs',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: widget.course.isContentCourse
                                      ? const Color(0xFF3B82F6)
                                      : const Color(0xFFD97706),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.course.cleanTitle,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: widget.course.progress / 100,
                                  minHeight: 6,
                                  backgroundColor: isDark ? Colors.white12 : Colors.black12,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    widget.course.progress >= 100 ? Colors.green : theme.primaryColor,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${widget.course.progress}%',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),

                        // Companion Course Link if available
                        if (companionCourse != null) ...[
                          const Divider(height: 24),
                          InkWell(
                            onTap: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CourseDetailScreen(course: companionCourse),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF22272E) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    companionCourse.isContentCourse
                                        ? Icons.menu_book_rounded
                                        : Icons.assignment_turned_in_rounded,
                                    size: 18,
                                    color: companionCourse.isContentCourse
                                        ? const Color(0xFF3B82F6)
                                        : const Color(0xFFF59E0B),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      companionCourse.isContentCourse
                                          ? 'Switch to Companion Study Content'
                                          : 'Switch to Companion Tests & MSTs',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: companionCourse.isContentCourse
                                            ? const Color(0xFF3B82F6)
                                            : const Color(0xFFD97706),
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Course Materials Sections
            unitsAsync.when(
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 40, color: Colors.red),
                        const SizedBox(height: 12),
                        Text('Failed to load course materials: $err', textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _refreshMaterials,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              data: (units) {
                if (units.isEmpty) {
                  return const SliverFillRemaining(
                    child: Center(child: Text('No units or materials found.')),
                  );
                }

                final isAssessmentCourse = widget.course.isAssessmentCourse;

                // Test Course Specific Sections
                final assessmentModelUnits = units.where((u) => u.isAssessmentModel).toList();
                final liveSessionUnits = units.where((u) => u.isLiveSessions).toList();
                final surpriseTestUnits = units.where((u) => u.isSurpriseTest).toList();
                final quizUnits = units.where((u) => u.isQuiz).toList();
                final assignmentUnits = units.where((u) => u.isAssignment).toList();

                final hasAssessmentModel = assessmentModelUnits.isNotEmpty;
                final hasLiveSessions = liveSessionUnits.isNotEmpty;
                final hasSurpriseTest = surpriseTestUnits.isNotEmpty;
                final hasQuiz = quizUnits.isNotEmpty;
                final hasAssignment = assignmentUnits.isNotEmpty;

                final totalAssessmentActivities = assessmentModelUnits.fold<int>(0, (s, u) => s + u.activities.length) +
                    liveSessionUnits.fold<int>(0, (s, u) => s + u.activities.length) +
                    surpriseTestUnits.fold<int>(0, (s, u) => s + u.activities.length) +
                    quizUnits.fold<int>(0, (s, u) => s + u.activities.length) +
                    assignmentUnits.fold<int>(0, (s, u) => s + u.activities.length);

                // Content Course Specific Sections
                final hasTheory = units.any((u) => u.isTheory && u.activities.isNotEmpty);
                final hasPractical = units.any((u) => u.isPractical && u.activities.isNotEmpty);
                final hasOverview = units.any((u) => u.isOverview && u.activities.isNotEmpty);

                // Filter units based on selected tab
                final filteredUnits = units.where((u) {
                  if (isAssessmentCourse) {
                    if (_selectedTab == 'assessment_model') return u.isAssessmentModel;
                    if (_selectedTab == 'live_sessions') return u.isLiveSessions;
                    if (_selectedTab == 'surprise_test') return u.isSurpriseTest;
                    if (_selectedTab == 'quiz') return u.isQuiz;
                    if (_selectedTab == 'assignment') return u.isAssignment;
                    // In 'all' for test course: show all assessment sections plus any unit with activities
                    return u.isAssessmentModel ||
                        u.isLiveSessions ||
                        u.isSurpriseTest ||
                        u.isQuiz ||
                        u.isAssignment ||
                        u.activities.isNotEmpty;
                  } else {
                    if (_selectedTab == 'theory') return u.isTheory;
                    if (_selectedTab == 'practical') return u.isPractical;
                    if (_selectedTab == 'overview') return u.isOverview;
                    return true;
                  }
                }).toList();

                // Group sub-units under parent units
                final groupedUnits = <String, List<CourseUnit>>{};
                for (final u in filteredUnits) {
                  if (!isAssessmentCourse &&
                      u.isHeaderOnly &&
                      filteredUnits.any((other) => other.parentUnit == u.parentUnit && other.id != u.id)) {
                    continue;
                  }
                  groupedUnits.putIfAbsent(u.parentUnit, () => []).add(u);
                }

                // Construct filter chips
                final List<Widget> filterChips = [];

                if (isAssessmentCourse) {
                  filterChips.add(
                    _CategoryChip(
                      label: 'All (${totalAssessmentActivities > 0 ? totalAssessmentActivities : filteredUnits.length})',
                      isSelected: _selectedTab == 'all',
                      onTap: () => setState(() => _selectedTab = 'all'),
                    ),
                  );

                  if (hasAssessmentModel) {
                    final amCount = assessmentModelUnits.fold<int>(0, (s, u) => s + u.activities.length);
                    filterChips.add(const SizedBox(width: 8));
                    filterChips.add(
                      _CategoryChip(
                        label: '📋 Assessment Model${amCount > 0 ? " ($amCount)" : ""}',
                        isSelected: _selectedTab == 'assessment_model',
                        onTap: () => setState(() => _selectedTab = 'assessment_model'),
                      ),
                    );
                  }

                  if (hasLiveSessions) {
                    final lsCount = liveSessionUnits.fold<int>(0, (s, u) => s + u.activities.length);
                    filterChips.add(const SizedBox(width: 8));
                    filterChips.add(
                      _CategoryChip(
                        label: '📹 Live Session Links${lsCount > 0 ? " ($lsCount)" : ""}',
                        isSelected: _selectedTab == 'live_sessions',
                        onTap: () => setState(() => _selectedTab = 'live_sessions'),
                      ),
                    );
                  }

                  if (hasSurpriseTest) {
                    final stCount = surpriseTestUnits.fold<int>(0, (s, u) => s + u.activities.length);
                    filterChips.add(const SizedBox(width: 8));
                    filterChips.add(
                      _CategoryChip(
                        label: '⚡ Surprise Test${stCount > 0 ? " ($stCount)" : ""}',
                        isSelected: _selectedTab == 'surprise_test',
                        onTap: () => setState(() => _selectedTab = 'surprise_test'),
                      ),
                    );
                  }

                  if (hasQuiz) {
                    final qzCount = quizUnits.fold<int>(0, (s, u) => s + u.activities.length);
                    filterChips.add(const SizedBox(width: 8));
                    filterChips.add(
                      _CategoryChip(
                        label: '📝 Quiz${qzCount > 0 ? " ($qzCount)" : ""}',
                        isSelected: _selectedTab == 'quiz',
                        onTap: () => setState(() => _selectedTab = 'quiz'),
                      ),
                    );
                  }

                  if (hasAssignment) {
                    final asgCount = assignmentUnits.fold<int>(0, (s, u) => s + u.activities.length);
                    filterChips.add(const SizedBox(width: 8));
                    filterChips.add(
                      _CategoryChip(
                        label: '📑 Assignments${asgCount > 0 ? " ($asgCount)" : ""}',
                        isSelected: _selectedTab == 'assignment',
                        onTap: () => setState(() => _selectedTab = 'assignment'),
                      ),
                    );
                  }
                } else {
                  filterChips.add(
                    _CategoryChip(
                      label: 'All (${units.where((u) => u.activities.isNotEmpty).length})',
                      isSelected: _selectedTab == 'all',
                      onTap: () => setState(() => _selectedTab = 'all'),
                    ),
                  );
                  if (hasTheory) {
                    filterChips.add(const SizedBox(width: 8));
                    filterChips.add(
                      _CategoryChip(
                        label: '📖 Theory',
                        isSelected: _selectedTab == 'theory',
                        onTap: () => setState(() => _selectedTab = 'theory'),
                      ),
                    );
                  }
                  if (hasPractical) {
                    filterChips.add(const SizedBox(width: 8));
                    filterChips.add(
                      _CategoryChip(
                        label: '🧪 Practical',
                        isSelected: _selectedTab == 'practical',
                        onTap: () => setState(() => _selectedTab = 'practical'),
                      ),
                    );
                  }
                  if (hasOverview) {
                    filterChips.add(const SizedBox(width: 8));
                    filterChips.add(
                      _CategoryChip(
                        label: 'ℹ️ Overview',
                        isSelected: _selectedTab == 'overview',
                        onTap: () => setState(() => _selectedTab = 'overview'),
                      ),
                    );
                  }
                }

                return SliverMainAxisGroup(
                  slivers: [
                    // Tab Selector
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(children: filterChips),
                        ),
                      ),
                    ),

                    // Grouped Units Display
                    if (groupedUnits.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.assignment_outlined, size: 48, color: Colors.grey.withValues(alpha: 0.5)),
                                const SizedBox(height: 12),
                                const Text(
                                  'No items found under this filter.',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, groupIdx) {
                              final groupKey = groupedUnits.keys.elementAt(groupIdx);
                              final groupSections = groupedUnits[groupKey]!;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Unit Group Header Divider
                                  Padding(
                                    padding: const EdgeInsets.only(top: 14.0, bottom: 8.0, left: 4),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 4,
                                          height: 16,
                                          decoration: BoxDecoration(
                                            color: _getGroupKeyColor(groupKey, theme),
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          groupKey,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white70 : const Color(0xFF334155),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Sub-chapters / Experiments inside this Unit
                                  ...groupSections.map((unit) {
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF1B1E22) : Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isDark ? const Color(0xFF2A2E35) : const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: ExpansionTile(
                                        initiallyExpanded: isAssessmentCourse || groupIdx == 0,
                                        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                        leading: Container(
                                          height: 36,
                                          width: 36,
                                          decoration: BoxDecoration(
                                            color: _getUnitColor(unit, theme).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          alignment: Alignment.center,
                                          child: Icon(
                                            _getUnitIcon(unit),
                                            size: 20,
                                            color: _getUnitColor(unit, theme),
                                          ),
                                        ),
                                        title: Text(
                                          unit.title,
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                        ),
                                        subtitle: Text(
                                          unit.activities.isEmpty
                                              ? (isAssessmentCourse ? 'Awaiting faculty uploads' : '0 items')
                                              : '${unit.activities.length} ${unit.activities.length == 1 ? "item" : "items"}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: unit.activities.isEmpty && isAssessmentCourse
                                                ? const Color(0xFFF59E0B)
                                                : Colors.grey,
                                          ),
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (unit.activities.isNotEmpty) ...[
                                              if (settings.enableLearnWithAi)
                                                Semantics(
                                                label: 'Learn with AI',
                                                button: true,
                                                child: IconButton(
                                                  icon: const Icon(
                                                    Icons.auto_awesome_rounded,
                                                    size: 20,
                                                    color: Color(0xFF8B5CF6),
                                                  ),
                                                  tooltip: 'Learn with AI',
                                                  onPressed: () => _openLearnWithAi(unit),
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.archive_outlined, size: 20),
                                                tooltip: 'Export Unit as ZIP',
                                                onPressed: () => _exportUnit(unit),
                                              ),
                                            ],
                                            if (unit.sectionUrl != null && unit.sectionUrl!.isNotEmpty)
                                              IconButton(
                                                icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                                                tooltip: 'Open Section in LMS',
                                                onPressed: () {
                                                  AppBrowserScreen.open(
                                                    context,
                                                    url: unit.sectionUrl!,
                                                    title: unit.title,
                                                  );
                                                },
                                              ),
                                          ],
                                        ),
                                        children: unit.activities.isEmpty
                                            ? [_buildEmptySection(unit, isDark)]
                                            : unit.activities.map((act) {
                                                return _buildActivityTile(act, isDark);
                                              }).toList(),
                                      ),
                                    );
                                  }),
                                ],
                              );
                            },
                            childCount: groupedUnits.length,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySection(CourseUnit unit, bool isDark) {
    IconData icon = Icons.inbox_rounded;
    String title = 'No Materials';
    String message = 'No items uploaded in this section yet.';

    if (unit.isSurpriseTest) {
      icon = Icons.bolt_rounded;
      title = 'No Surprise Tests Yet';
      message = 'Surprise tests and classroom assessments uploaded by your teacher will appear here.';
    } else if (unit.isLiveSessions) {
      icon = Icons.videocam_off_rounded;
      title = 'No Active Live Sessions';
      message = 'Online lecture links (Zoom / Google Meet) posted by your faculty will appear here.';
    } else if (unit.isQuiz) {
      icon = Icons.quiz_outlined;
      title = 'No Active Quizzes';
      message = 'Quizzes, MSTs, and practice assessments will appear here once scheduled.';
    } else if (unit.isAssessmentModel) {
      icon = Icons.fact_check_outlined;
      title = 'Assessment Guidelines';
      message = 'Syllabus and evaluation scheme updates from your department.';
    } else if (unit.isAssignment) {
      icon = Icons.assignment_outlined;
      title = 'No Active Assignments';
      message = 'Homework and project submissions will appear here.';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(icon, size: 36, color: Colors.grey.withValues(alpha: 0.6)),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          if (unit.sectionUrl != null && unit.sectionUrl!.isNotEmpty) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.open_in_browser_rounded, size: 14),
              label: const Text('Open Section in App Browser', style: TextStyle(fontSize: 11)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minimumSize: const Size(0, 30),
              ),
              onPressed: () {
                AppBrowserScreen.open(
                  context,
                  url: unit.sectionUrl!,
                  title: unit.title,
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActivityTile(CourseActivity act, bool isDark) {
    final isUrl = act.iconType == 'url';
    final isQuiz = act.iconType == 'quiz';
    final isAssign = act.iconType == 'assign';

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: _getActivityIcon(act.iconType),
      title: Text(
        act.name,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        act.typeName,
        style: const TextStyle(fontSize: 11, color: Colors.grey),
      ),
      trailing: isUrl
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0EA5E9).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Join Link', style: TextStyle(fontSize: 11, color: Color(0xFF0EA5E9), fontWeight: FontWeight.w600)),
                  SizedBox(width: 4),
                  Icon(Icons.launch_rounded, size: 12, color: Color(0xFF0EA5E9)),
                ],
              ),
            )
          : (isQuiz
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Attempt Quiz', style: TextStyle(fontSize: 11, color: Color(0xFF8B5CF6), fontWeight: FontWeight.w600)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 12, color: Color(0xFF8B5CF6)),
                    ],
                  ),
                )
              : (isAssign
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('View Task', style: TextStyle(fontSize: 11, color: Color(0xFFF59E0B), fontWeight: FontWeight.w600)),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward_rounded, size: 12, color: Color(0xFFF59E0B)),
                        ],
                      ),
                    )
                  : const Icon(Icons.chevron_right_rounded, size: 18))),
      onTap: () => _openActivity(act),
    );
  }

  Color _getGroupKeyColor(String groupKey, ThemeData theme) {
    if (groupKey.contains('Practical')) return const Color(0xFF10B981);
    if (groupKey.contains('Surprise')) return const Color(0xFFF59E0B);
    if (groupKey.contains('Quiz')) return const Color(0xFF8B5CF6);
    if (groupKey.contains('Live Session')) return const Color(0xFF0EA5E9);
    if (groupKey.contains('Assessment')) return const Color(0xFF10B981);
    if (groupKey.contains('Assignment')) return const Color(0xFFEC4899);
    return theme.primaryColor;
  }

  Color _getUnitColor(CourseUnit unit, ThemeData theme) {
    if (unit.isSurpriseTest) return const Color(0xFFF59E0B);
    if (unit.isQuiz) return const Color(0xFF8B5CF6);
    if (unit.isLiveSessions) return const Color(0xFF0EA5E9);
    if (unit.isAssessmentModel) return const Color(0xFF10B981);
    if (unit.isAssignment) return const Color(0xFFEC4899);
    if (unit.isPractical) return const Color(0xFF10B981);
    return theme.primaryColor;
  }

  IconData _getUnitIcon(CourseUnit unit) {
    if (unit.isSurpriseTest) return Icons.bolt_rounded;
    if (unit.isQuiz) return Icons.quiz_rounded;
    if (unit.isLiveSessions) return Icons.videocam_rounded;
    if (unit.isAssessmentModel) return Icons.fact_check_rounded;
    if (unit.isAssignment) return Icons.assignment_turned_in_rounded;
    if (unit.isPractical) return Icons.science_rounded;
    if (unit.isOverview) return Icons.info_outline_rounded;
    return Icons.article_rounded;
  }

  Widget _getActivityIcon(String iconType) {
    switch (iconType.toLowerCase()) {
      case 'file':
        return const Icon(Icons.description_rounded, color: Colors.redAccent, size: 20);
      case 'folder':
        return const Icon(Icons.folder_rounded, color: Colors.amber, size: 20);
      case 'page':
        return const Icon(Icons.menu_book_rounded, color: Colors.blue, size: 20);
      case 'quiz':
        return const Icon(Icons.quiz_rounded, color: Colors.purple, size: 20);
      case 'forum':
        return const Icon(Icons.forum_rounded, color: Colors.teal, size: 20);
      case 'assign':
        return const Icon(Icons.assignment_turned_in_rounded, color: Colors.orange, size: 20);
      case 'url':
        return const Icon(Icons.link_rounded, color: Colors.lightBlue, size: 20);
      default:
        return const Icon(Icons.insert_drive_file_rounded, color: Colors.grey, size: 20);
    }
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.primaryColor
              : (isDark ? const Color(0xFF1F2328) : const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white70 : const Color(0xFF334155)),
          ),
        ),
      ),
    );
  }
}
