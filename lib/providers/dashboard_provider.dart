import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/calendar_event.dart';
import 'app_providers.dart';
import 'auth_provider.dart';
import 'course_provider.dart';
import 'settings_provider.dart';

class DashboardData {
  final List<LmsCalendarEvent> events;
  final bool isLoading;
  final String? errorMessage;

  const DashboardData({
    this.events = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  DashboardData copyWith({
    List<LmsCalendarEvent>? events,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DashboardData(
      events: events ?? this.events,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class DashboardNotifier extends Notifier<DashboardData> {
  @override
  DashboardData build() {
    final auth = ref.watch(authProvider);
    if (auth.isAuthenticated && auth.session != null) {
      Future.microtask(() => loadDashboard());
    }
    return const DashboardData();
  }

  Future<void> loadDashboard({bool forceRefresh = false}) async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated || auth.session == null) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final apiClient = ref.read(lmsApiClientProvider);
      final events = await apiClient.getTimelineEvents(
        auth.session!,
        forceRefresh: forceRefresh,
      );

      state = state.copyWith(
        events: events,
        isLoading: false,
      );

      // User requirement: "The alarm timing will be refreshed on refreshing the homepage by canceling previous alarms."
      try {
        final settings = ref.read(settingsProvider);
        final alarmService = ref.read(alarmServiceProvider);
        await alarmService.refreshAlarms(
          events: events,
          settings: settings,
        );
      } catch (e) {
        // Prevent alarm scheduling errors from interrupting UI
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }
}

final dashboardProvider = NotifierProvider<DashboardNotifier, DashboardData>(DashboardNotifier.new);

final dashboardStatsProvider = Provider<Map<String, dynamic>>((ref) {
  final coursesState = ref.watch(coursesProvider);
  final dashboardState = ref.watch(dashboardProvider);

  final totalCourses = coursesState.allCourses.length;
  double avgProgress = 0.0;
  if (totalCourses > 0) {
    final sum = coursesState.allCourses.fold<int>(0, (prev, c) => prev + c.progress);
    avgProgress = sum / totalCourses;
  }

  final upcomingDeadlinesCount = dashboardState.events.where((e) => e.isUpcoming).length;

  return {
    'totalCourses': totalCourses,
    'avgProgress': avgProgress,
    'upcomingDeadlinesCount': upcomingDeadlinesCount,
  };
});
