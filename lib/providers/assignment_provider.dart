import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/assignment.dart';
import 'app_providers.dart';
import 'auth_provider.dart';

/// Provider for Assignment Detail (overview, instructions, teacher files, status)
final assignmentDetailProvider =
    FutureProvider.family<AssignmentDetail, int>((ref, assignId) async {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated || auth.session == null) {
    throw Exception('Authentication required to view assignment');
  }

  final apiClient = ref.watch(lmsApiClientProvider);
  return apiClient.getAssignmentDetail(assignId, auth.session!);
});

/// State for the assignment upload & submission screen
class AssignmentUploadState {
  final AssignmentSubmissionConfig? config;
  final bool isLoading;
  final bool isUploading;
  final bool isSubmitting;
  final bool isRemoving;
  final bool isSubmissionSuccess;
  final String? errorMessage;
  final String? successMessage;

  const AssignmentUploadState({
    this.config,
    this.isLoading = false,
    this.isUploading = false,
    this.isSubmitting = false,
    this.isRemoving = false,
    this.isSubmissionSuccess = false,
    this.errorMessage,
    this.successMessage,
  });

  AssignmentUploadState copyWith({
    AssignmentSubmissionConfig? config,
    bool? isLoading,
    bool? isUploading,
    bool? isSubmitting,
    bool? isRemoving,
    bool? isSubmissionSuccess,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return AssignmentUploadState(
      config: config ?? this.config,
      isLoading: isLoading ?? this.isLoading,
      isUploading: isUploading ?? this.isUploading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isRemoving: isRemoving ?? this.isRemoving,
      isSubmissionSuccess: isSubmissionSuccess ?? this.isSubmissionSuccess,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

class AssignmentUploadNotifier extends Notifier<AssignmentUploadState> {
  final int assignId;

  AssignmentUploadNotifier(this.assignId);

  @override
  AssignmentUploadState build() {
    Future.microtask(() => loadConfig());
    return const AssignmentUploadState(isLoading: true);
  }

  Future<void> loadConfig({bool forceRefresh = false}) async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated || auth.session == null) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Authentication required',
      );
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final apiClient = ref.read(lmsApiClientProvider);
      final config = await apiClient.getSubmissionConfig(
        assignId,
        auth.session!,
        forceRefresh: forceRefresh,
      );
      state = state.copyWith(
        config: config,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  /// Uploads a file to Moodle's draft staging repository.
  Future<bool> stageDraftFile({
    required String filename,
    required List<int> bytes,
  }) async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated || auth.session == null) {
      state = state.copyWith(errorMessage: 'Authentication required');
      return false;
    }

    final currentConfig = state.config;
    if (currentConfig == null) {
      state = state.copyWith(errorMessage: 'Submission config not loaded');
      return false;
    }

    // Validation: Maximum file count
    if (currentConfig.draftFiles.length >= currentConfig.maxFiles) {
      state = state.copyWith(
        errorMessage:
            'Maximum ${currentConfig.maxFiles} file(s) allowed. Please remove existing file first.',
      );
      return false;
    }

    // Validation: Max file size
    if (bytes.length > currentConfig.maxBytes) {
      state = state.copyWith(
        errorMessage:
            'File size exceeds limit of ${currentConfig.maxBytesText}.',
      );
      return false;
    }

    // Validation: Accepted file types
    if (currentConfig.acceptedTypes.isNotEmpty) {
      final ext = filename.contains('.')
          ? '.${filename.split('.').last.toLowerCase()}'
          : '';
      final isAccepted = currentConfig.acceptedTypes
          .any((t) => t.toLowerCase() == ext || t == 'all');
      if (!isAccepted) {
        state = state.copyWith(
          errorMessage:
              'File type "$ext" not accepted. Allowed: ${currentConfig.acceptedTypes.join(', ')}',
        );
        return false;
      }
    }

    state = state.copyWith(isUploading: true, clearError: true, clearSuccess: true);

    try {
      final apiClient = ref.read(lmsApiClientProvider);
      final uploaded = await apiClient.uploadDraftFile(
        config: currentConfig,
        session: auth.session!,
        filename: filename,
        fileBytes: bytes,
      );

      // Refresh draft files
      final refreshedFiles = await apiClient.getDraftFiles(
        itemId: currentConfig.itemId,
        clientId: currentConfig.clientId,
        session: auth.session!,
      );

      final updatedConfig = currentConfig.copyWith(draftFiles: refreshedFiles);

      state = state.copyWith(
        config: updatedConfig,
        isUploading: false,
        successMessage: 'Staged "$filename" successfully.',
      );
      return uploaded != null || refreshedFiles.isNotEmpty;
    } catch (e) {
      state = state.copyWith(
        isUploading: false,
        errorMessage: 'Upload failed: $e',
      );
      return false;
    }
  }

  /// Removes a file from Moodle's draft staging repository.
  Future<bool> deleteDraftFile(String filename) async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated || auth.session == null) return false;

    final currentConfig = state.config;
    if (currentConfig == null) return false;

    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      final apiClient = ref.read(lmsApiClientProvider);
      await apiClient.deleteDraftFile(
        config: currentConfig,
        session: auth.session!,
        filename: filename,
      );

      // Refresh draft files
      final refreshedFiles = await apiClient.getDraftFiles(
        itemId: currentConfig.itemId,
        clientId: currentConfig.clientId,
        session: auth.session!,
      );

      final updatedConfig = currentConfig.copyWith(draftFiles: refreshedFiles);

      state = state.copyWith(
        config: updatedConfig,
        isLoading: false,
        successMessage: 'Removed "$filename" from draft.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Delete failed: $e',
      );
      return false;
    }
  }

  /// Permanently submits the assignment by posting savesubmission to Moodle.
  Future<bool> submitFinalAssignment() async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated || auth.session == null) {
      state = state.copyWith(errorMessage: 'Authentication required');
      return false;
    }

    final currentConfig = state.config;
    if (currentConfig == null) {
      state = state.copyWith(errorMessage: 'Submission config not loaded');
      return false;
    }

    if (currentConfig.draftFiles.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Please upload at least one file before submitting.',
      );
      return false;
    }

    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      clearSuccess: true,
      isSubmissionSuccess: false,
    );

    try {
      final apiClient = ref.read(lmsApiClientProvider);
      final success = await apiClient.saveFinalSubmission(
        config: currentConfig,
        session: auth.session!,
      );

      // Invalidate assignment detail to force fresh fetch on view screen
      ref.invalidate(assignmentDetailProvider(assignId));

      if (success) {
        state = state.copyWith(
          isSubmitting: false,
          isSubmissionSuccess: true,
          successMessage: 'Assignment submitted successfully!',
        );
        return true;
      } else {
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: 'Server rejected assignment submission.',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Submission error: $e',
      );
      return false;
    }
  }

  /// Removes an existing submission from Moodle.
  Future<bool> removeSubmission({String? userId}) async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated || auth.session == null) {
      state = state.copyWith(errorMessage: 'Authentication required');
      return false;
    }

    state = state.copyWith(
      isRemoving: true,
      clearError: true,
      clearSuccess: true,
    );

    try {
      final apiClient = ref.read(lmsApiClientProvider);
      final resolvedUserId = userId ??
          auth.session!.moodleUserId ??
          state.config?.hiddenFields['userid'];
      final success = await apiClient.removeSubmission(
        assignId: assignId,
        session: auth.session!,
        userId: resolvedUserId,
      );

      // Invalidate assignment detail
      ref.invalidate(assignmentDetailProvider(assignId));

      if (success) {
        state = state.copyWith(
          isRemoving: false,
          successMessage: 'Submission removed successfully.',
        );
        // Reload submission config
        await loadConfig(forceRefresh: true);
        return true;
      } else {
        state = state.copyWith(
          isRemoving: false,
          errorMessage: 'Failed to remove submission.',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isRemoving: false,
        errorMessage: 'Error removing submission: $e',
      );
      return false;
    }
  }
}

final assignmentUploadProvider = NotifierProvider.family<
    AssignmentUploadNotifier,
    AssignmentUploadState,
    int>(
  (assignId) => AssignmentUploadNotifier(assignId),
);
