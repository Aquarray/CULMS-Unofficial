import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/course.dart';
import '../../../providers/course_provider.dart';
import '../../common/slide_scroll_item.dart';
import 'course_detail_screen.dart';

class CoursesScreen extends ConsumerWidget {
  const CoursesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesState = ref.watch(coursesProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Enrolled Courses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Courses',
            onPressed: () => ref.read(coursesProvider.notifier).loadCourses(forceRefresh: true),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              children: [
                TextField(
                  onChanged: (val) => ref.read(coursesProvider.notifier).setSearchQuery(val),
                  decoration: InputDecoration(
                    hintText: 'Search subjects, course codes...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1B1E22) : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All (${coursesState.allCourses.length})',
                        isSelected: coursesState.filter == 'all',
                        onTap: () => ref.read(coursesProvider.notifier).setFilter('all'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: '📘 Study Content (${coursesState.allCourses.where((c) => c.isContentCourse).length})',
                        isSelected: coursesState.filter == 'content',
                        onTap: () => ref.read(coursesProvider.notifier).setFilter('content'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: '📝 Tests & MSTs (${coursesState.allCourses.where((c) => c.isAssessmentCourse).length})',
                        isSelected: coursesState.filter == 'assessment',
                        onTap: () => ref.read(coursesProvider.notifier).setFilter('assessment'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'In Progress',
                        isSelected: coursesState.filter == 'in_progress',
                        onTap: () => ref.read(coursesProvider.notifier).setFilter('in_progress'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Completed',
                        isSelected: coursesState.filter == 'completed',
                        onTap: () => ref.read(coursesProvider.notifier).setFilter('completed'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Course List
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: coursesState.isLoading && coursesState.allCourses.isEmpty
                  ? const Center(key: ValueKey('loading'), child: CircularProgressIndicator())
                  : RefreshIndicator(
                      key: ValueKey('list_${coursesState.filter}_${coursesState.searchQuery.isNotEmpty}'),
                      onRefresh: () =>
                          ref.read(coursesProvider.notifier).loadCourses(forceRefresh: true),
                      child: coursesState.filteredCourses.isEmpty
                          ? ListView(
                              key: const ValueKey('empty_courses'),
                              children: const [
                                SizedBox(height: 80),
                                Center(
                                  child: Text('No courses match your search or filter.'),
                                ),
                              ],
                            )
                          : ListView.builder(
                              key: const ValueKey('populated_courses'),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: coursesState.filteredCourses.length,
                              itemBuilder: (context, index) {
                                final course = coursesState.filteredCourses[index];
                                return SlideScrollItem(
                                  key: ValueKey('course_${course.id}'),
                                  index: index,
                                  direction: SlideDirection.up,
                                  child: _CourseCard(course: course),
                                );
                              },
                            ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
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
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.primaryColor
              : (isDark ? const Color(0xFF1F2328) : const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(20),
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

class _CourseCard extends ConsumerWidget {
  final Course course;

  const _CourseCard({required this.course});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isContent = course.isContentCourse;
    final badgeColor = isContent ? const Color(0xFF3B82F6) : const Color(0xFFF59E0B);
    final badgeLabel = isContent ? '📘 Study Material' : '📝 Tests & Quizzes';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CourseDetailScreen(course: course),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Hero(
                    tag: 'course_badge_${course.id}',
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: badgeColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (course.coursecategory.isNotEmpty)
                    Flexible(
                      child: Text(
                        course.coursecategory.split(':').last.trim(),
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Hero(
                tag: 'course_title_${course.id}',
                child: Material(
                  color: Colors.transparent,
                  child: Text(
                    course.cleanTitle,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: course.progress / 100,
                        minHeight: 5,
                        backgroundColor: isDark ? Colors.white12 : Colors.black12,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          course.progress >= 100 ? Colors.green : theme.primaryColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${course.progress}%',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
