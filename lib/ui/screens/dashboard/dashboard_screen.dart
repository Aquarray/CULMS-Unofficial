import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/calendar_event.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/course_provider.dart';
import '../../../providers/dashboard_provider.dart';
import '../../common/notification_permission_banner.dart';
import '../../common/slide_scroll_item.dart';
import '../assignments/assignment_detail_screen.dart';
import '../browser/app_browser_screen.dart';
import '../courses/course_detail_screen.dart';
import '../quiz/quiz_webview_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  void _handleEventTap(BuildContext context, LmsCalendarEvent event) {
    final urlString = event.actionUrl;
    if (urlString != null) {
      if (urlString.contains('mod/assign')) {
        final assignIdMatch =
            RegExp(r'[?&]id=(\d+)').firstMatch(urlString);
        if (assignIdMatch != null) {
          final assignId = int.tryParse(assignIdMatch.group(1)!);
          if (assignId != null) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AssignmentDetailScreen(
                  assignId: assignId,
                  initialTitle: event.name,
                ),
              ),
            );
            return;
          }
        }
      } else if (urlString.contains('mod/quiz')) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => QuizWebViewScreen(
              quizUrl: urlString,
              quizTitle: event.name,
              courseName: event.courseName,
            ),
          ),
        );
        return;
      }
      AppBrowserScreen.open(
        context,
        url: urlString,
        title: event.name,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final dashboardData = ref.watch(dashboardProvider);
    final stats = ref.watch(dashboardStatsProvider);
    final coursesState = ref.watch(coursesProvider);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final studentUid = authState.session?.uid.toUpperCase() ?? 'STUDENT';
    final studentName = authState.session?.studentName;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              studentName != null && studentName.isNotEmpty
                  ? 'Hello, $studentName'
                  : 'Hello, $studentUid',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Chandigarh University LMS',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Timeline',
            onPressed: () {
              ref.read(dashboardProvider.notifier).loadDashboard(forceRefresh: true);
              ref.read(coursesProvider.notifier).loadCourses(forceRefresh: true);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait<dynamic>([
            ref.read(dashboardProvider.notifier).loadDashboard(forceRefresh: true),
            ref.read(coursesProvider.notifier).loadCourses(forceRefresh: true),
          ]);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            // Notification Permission Prompt Banner
            const NotificationPermissionBanner(),

            // Academic Metrics Overview
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Enrolled Courses',
                      value: '${stats['totalCourses']}',
                      icon: Icons.school_outlined,
                      color: theme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: 'Avg Completion',
                      value: '${(stats['avgProgress'] as double).toStringAsFixed(0)}%',
                      icon: Icons.trending_up_rounded,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: 'Deadlines',
                      value: '${stats['upcomingDeadlinesCount']}',
                      icon: Icons.event_note_rounded,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ),

            // Active Courses Slider
            if (coursesState.allCourses.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Jump Back In',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${coursesState.allCourses.length} active',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 145,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: coursesState.allCourses.take(5).length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, idx) {
                    final course = coursesState.allCourses[idx];
                    return SlideScrollItem(
                      key: ValueKey('dash_course_${course.id}'),
                      index: idx,
                      direction: SlideDirection.left,
                      child: SizedBox(
                        width: 240,
                        child: Card(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CourseDetailScreen(course: course),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        course.courseCode,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: theme.primaryColor,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        course.cleanTitle,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          height: 1.25,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: course.progress / 100,
                                            minHeight: 4,
                                            backgroundColor: isDark ? Colors.white12 : Colors.black12,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              course.progress >= 100 ? Colors.green : theme.primaryColor,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${course.progress}%',
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Upcoming Action Events & Deadlines
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Upcoming Timeline',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${dashboardData.events.length} events',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),

            if (dashboardData.isLoading && dashboardData.events.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (dashboardData.events.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.check_circle_outline_rounded, size: 40, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('All caught up! No upcoming deadlines.'),
                    ],
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    for (int idx = 0; idx < dashboardData.events.length; idx++) ...[
                      if (idx > 0) const SizedBox(height: 10),
                      SlideScrollItem(
                        key: ValueKey('dash_event_${dashboardData.events[idx].id}_${dashboardData.events[idx].timesort}'),
                        index: idx,
                        direction: SlideDirection.up,
                        child: _EventCard(
                          event: dashboardData.events[idx],
                          onActionTap: dashboardData.events[idx].actionUrl != null
                              ? () => _handleEventTap(context, dashboardData.events[idx])
                              : null,
                          onCardTap: dashboardData.events[idx].actionUrl != null
                              ? () => _handleEventTap(context, dashboardData.events[idx])
                              : null,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final LmsCalendarEvent event;
  final VoidCallback? onActionTap;
  final VoidCallback? onCardTap;

  const _EventCard({
    required this.event,
    this.onActionTap,
    this.onCardTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onCardTap ?? onActionTap,
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.assignment_outlined,
                        color: Colors.orange, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.name,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        if (event.courseName != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            event.courseName!,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded,
                          size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        event.cleanFormattedTime,
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                  if (event.actionName != null && onActionTap != null)
                    ElevatedButton(
                      onPressed: onActionTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(
                        event.actionName!,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600),
                      ),
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
