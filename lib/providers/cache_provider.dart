import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_providers.dart';
import 'assignment_provider.dart';
import 'course_provider.dart';
import 'dashboard_provider.dart';

/// Clear both persistent storage and Riverpod's retained feature results.
/// Do not reset upload state: it represents live server drafts, not a cache.
final clearAppCacheProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    await ref.read(cacheServiceProvider).clearCache();
    ref.invalidate(courseUnitsProvider);
    ref.invalidate(lmsContentProvider);
    ref.invalidate(assignmentDetailProvider);
    ref.invalidate(coursesProvider);
    ref.invalidate(dashboardProvider);
  };
});
