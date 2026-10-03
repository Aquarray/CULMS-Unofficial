import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/course.dart';
import '../../data/models/course_content.dart';
import 'app_providers.dart';
import 'auth_provider.dart';

class CoursesState {
  final List<Course> allCourses;
  final bool isLoading;
  final String? errorMessage;
  final String searchQuery;
  final String filter; // 'all', 'in_progress', 'completed'

  const CoursesState({
    this.allCourses = const [],
    this.isLoading = false,
    this.errorMessage,
    this.searchQuery = '',
    this.filter = 'all',
  });

  List<Course> get filteredCourses {
    return allCourses.where((c) {
      final matchesSearch = searchQuery.isEmpty ||
          c.fullname.toLowerCase().contains(searchQuery.toLowerCase()) ||
          c.shortname.toLowerCase().contains(searchQuery.toLowerCase());

      if (!matchesSearch) return false;

      if (filter == 'content') {
        return c.isContentCourse;
      } else if (filter == 'assessment') {
        return c.isAssessmentCourse;
      } else if (filter == 'in_progress') {
        return c.progress < 100;
      } else if (filter == 'completed') {
        return c.progress >= 100;
      }
      return true;
    }).toList();
  }

  /// Finds the complementary course (e.g. Test course <-> Content course)
  Course? getCompanionCourse(Course course) {
    for (final other in allCourses) {
      if (other.id == course.id) continue;
      if (other.courseCode.toLowerCase() == course.courseCode.toLowerCase() ||
          other.cleanTitle.toLowerCase() == course.cleanTitle.toLowerCase()) {
        return other;
      }
    }
    return null;
  }

  CoursesState copyWith({
    List<Course>? allCourses,
    bool? isLoading,
    String? errorMessage,
    String? searchQuery,
    String? filter,
    bool clearError = false,
  }) {
    return CoursesState(
      allCourses: allCourses ?? this.allCourses,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      searchQuery: searchQuery ?? this.searchQuery,
      filter: filter ?? this.filter,
    );
  }
}

class CoursesNotifier extends Notifier<CoursesState> {
  @override
  CoursesState build() {
    final auth = ref.watch(authProvider);
    if (auth.isAuthenticated && auth.session != null) {
      Future.microtask(() => loadCourses());
    }
    return const CoursesState();
  }

  Future<void> loadCourses({bool forceRefresh = false}) async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated || auth.session == null) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final apiClient = ref.read(lmsApiClientProvider);
      final courses = await apiClient.getEnrolledCourses(
        auth.session!,
        forceRefresh: forceRefresh,
      );

      state = state.copyWith(
        allCourses: courses,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setFilter(String filter) {
    state = state.copyWith(filter: filter);
  }
}

final coursesProvider = NotifierProvider<CoursesNotifier, CoursesState>(CoursesNotifier.new);

/// Family provider for course units
final courseUnitsProvider = FutureProvider.family<List<CourseUnit>, int>((ref, courseId) async {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated || auth.session == null) return [];

  final apiClient = ref.watch(lmsApiClientProvider);
  return apiClient.getCourseUnits(courseId, auth.session!);
});

/// Family provider for extracted resource/folder content
final lmsContentProvider = FutureProvider.family<LmsExtractedContent, String>((ref, url) async {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated || auth.session == null) {
    throw Exception('Authentication required');
  }

  final apiClient = ref.watch(lmsApiClientProvider);
  return apiClient.extractContent(url: url, session: auth.session!);
});
