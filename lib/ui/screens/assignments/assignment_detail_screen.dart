import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../data/models/assignment.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/assignment_provider.dart';
import '../browser/app_browser_screen.dart';
import '../reader/pdf_viewer_screen.dart';
import 'assignment_upload_screen.dart';

class AssignmentDetailScreen extends ConsumerWidget {
  final int assignId;
  final String? initialTitle;

  const AssignmentDetailScreen({
    super.key,
    required this.assignId,
    this.initialTitle,
  });

  Color _getStatusColor(String? status, BuildContext context) {
    if (status == null) return Colors.grey;
    final lower = status.toLowerCase();
    if (lower.contains('submitted') || lower.contains('graded')) {
      return Colors.green;
    }
    if (lower.contains('overdue') || lower.contains('late')) {
      return Colors.red;
    }
    if (lower.contains('draft') || lower.contains('not graded')) {
      return Colors.orange;
    }
    return Colors.blue;
  }

  void _openFile(BuildContext context, String title, String downloadUrl) async {
    final lower = downloadUrl.toLowerCase();
    if (lower.endsWith('.pdf') || title.toLowerCase().endsWith('.pdf')) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PdfViewerScreen(
            title: title,
            downloadUrl: downloadUrl,
          ),
        ),
      );
    } else {
      AppBrowserScreen.open(
        context,
        url: downloadUrl,
        title: title,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignAsync = ref.watch(assignmentDetailProvider(assignId));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          initialTitle ?? 'Assignment Details',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Assignment',
            onPressed: () async {
              // Remove from cache FIRST so the provider fetches fresh from network
              final cache = ref.read(cacheServiceProvider);
              await cache.remove('assign_detail_$assignId');
              ref.invalidate(assignmentDetailProvider(assignId));
            },
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser_rounded),
            tooltip: 'Open in LMS',
            onPressed: () {
              AppBrowserScreen.open(
                context,
                url: 'https://lms.cuchd.in/mod/assign/view.php?id=$assignId',
                title: initialTitle ?? 'Assignment',
              );
            },
          ),
        ],
      ),
      body: assignAsync.when(
        loading: () => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Fetching assignment details...'),
            ],
          ),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text(
                  'Failed to load assignment',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  err.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () =>
                      ref.invalidate(assignmentDetailProvider(assignId)),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
        data: (detail) {
          final statusColor = _getStatusColor(detail.submissionStatus, context);

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Header Card
              Card(
                elevation: 0,
                color: isDark
                    ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.5)
                    : theme.colorScheme.primaryContainer.withOpacity(0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: theme.colorScheme.primary.withOpacity(0.2),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (detail.courseName != null &&
                          detail.courseName!.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            detail.courseName!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Text(
                        detail.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (detail.dueDate != null) ...[
                            Icon(Icons.event_rounded,
                                size: 16, color: theme.colorScheme.primary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                detail.dueDate!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (detail.openDate != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.schedule_rounded,
                                size: 16, color: Colors.grey),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                detail.openDate!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (detail.timeRemaining != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: statusColor.withOpacity(0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.hourglass_top_rounded,
                                  size: 14, color: statusColor),
                              const SizedBox(width: 6),
                              Text(
                                detail.timeRemaining!,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Description / Instructions Card
              if (detail.instructionsText != null &&
                  detail.instructionsText!.isNotEmpty) ...[
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isDark ? Colors.white12 : Colors.black12,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.description_outlined, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Assignment Description',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.04)
                                : Colors.grey.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: SelectableText(
                            detail.instructionsText!,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.6,
                              color: isDark
                                  ? Colors.white.withOpacity(0.87)
                                  : Colors.black.withOpacity(0.87),
                            ),
                          ),
                        ),
                        if (detail.teacherFiles.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Text(
                            'Reference Materials',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...detail.teacherFiles.map((file) {
                            return Card(
                              elevation: 0,
                              color: isDark
                                  ? Colors.white.withOpacity(0.04)
                                  : Colors.black.withOpacity(0.03),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color: isDark
                                      ? Colors.white12
                                      : Colors.black12,
                                ),
                              ),
                              child: ListTile(
                                dense: true,
                                leading: Icon(
                                  file.isPdf
                                      ? Icons.picture_as_pdf_rounded
                                      : Icons.attach_file_rounded,
                                  color: file.isPdf
                                      ? Colors.redAccent
                                      : theme.colorScheme.primary,
                                ),
                                title: Text(
                                  file.name,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: Text(
                                  file.isPdf
                                      ? 'Tap to view PDF'
                                      : 'Tap to open/download',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                trailing: const Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 14),
                                onTap: () =>
                                    _openFile(context, file.name, file.downloadUrl),
                              ),
                            );
                          }),
                        ] else if (detail.teacherFiles.isEmpty) ...[
                          // No teacher files - just description shown above
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ] else if (detail.teacherFiles.isNotEmpty) ...[
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isDark ? Colors.white12 : Colors.black12,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.attach_file_rounded, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Reference Materials',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...detail.teacherFiles.map((file) {
                          return Card(
                            elevation: 0,
                            color: isDark
                                ? Colors.white.withOpacity(0.04)
                                : Colors.black.withOpacity(0.03),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color:
                                    isDark ? Colors.white12 : Colors.black12,
                              ),
                            ),
                            child: ListTile(
                              dense: true,
                              leading: Icon(
                                file.isPdf
                                    ? Icons.picture_as_pdf_rounded
                                    : Icons.attach_file_rounded,
                                color: file.isPdf
                                    ? Colors.redAccent
                                    : theme.colorScheme.primary,
                              ),
                              title: Text(
                                file.name,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                file.isPdf
                                    ? 'Tap to view PDF'
                                    : 'Tap to open/download',
                                style: const TextStyle(fontSize: 11),
                              ),
                              trailing: const Icon(
                                  Icons.arrow_forward_ios_rounded, size: 14),
                              onTap: () =>
                                  _openFile(context, file.name, file.downloadUrl),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Submission Status Table Card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.assignment_turned_in_outlined, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Submission Status',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildStatusRow(
                        'Submission Status',
                        detail.submissionStatus ?? 'Not submitted',
                        valueColor: statusColor,
                        isBold: true,
                      ),
                      const Divider(height: 16),
                      _buildStatusRow(
                        'Grading Status',
                        detail.gradingStatus ?? 'Not graded',
                        valueColor: detail.isGraded
                            ? Colors.green
                            : (isDark ? Colors.white70 : Colors.black87),
                      ),
                      if (detail.timeRemaining != null) ...[
                        const Divider(height: 16),
                        _buildStatusRow(
                          'Time Remaining',
                          detail.timeRemaining!,
                          valueColor: statusColor,
                        ),
                      ],
                      if (detail.lastModified != null) ...[
                        const Divider(height: 16),
                        _buildStatusRow(
                          'Last Modified',
                          detail.lastModified!,
                        ),
                      ],
                      ...detail.extraStatusFields.entries.map((entry) {
                        return Column(
                          children: [
                            const Divider(height: 16),
                            _buildStatusRow(entry.key, entry.value),
                          ],
                        );
                      }),
                      if (detail.submissionCommentsCount > 0) ...[
                        const Divider(height: 16),
                        _buildStatusRow(
                          'Submission Comments',
                          '${detail.submissionCommentsCount} comment(s)',
                        ),
                      ],
                      if (detail.submittedFiles.isNotEmpty) ...[
                        const Divider(height: 20),
                        const Text(
                          'Submitted Files',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...detail.submittedFiles.map((file) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: ListTile(
                              dense: true,
                              leading: Icon(
                                file.isPdf
                                    ? Icons.picture_as_pdf_rounded
                                    : Icons.insert_drive_file_rounded,
                                color: file.isPdf
                                    ? Colors.redAccent
                                    : theme.primaryColor,
                              ),
                              title: Text(
                                file.name,
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                              trailing: const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 14),
                              onTap: () => _openFile(
                                  context, file.name, file.downloadUrl),
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ),

              // Feedback / Grade Card (when graded or feedback exists)
              if (detail.feedbackGrade != null || detail.isGraded) ...[
                const SizedBox(height: 16),
                Card(
                  elevation: 0,
                  color: isDark
                      ? Colors.green.withOpacity(0.1)
                      : Colors.green.withOpacity(0.05),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: Colors.green.withOpacity(0.3),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.stars_rounded,
                                color: Colors.green, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Feedback & Grade',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        if (detail.feedbackGrade != null) ...[
                          const SizedBox(height: 12),
                          _buildStatusRow(
                            'Grade',
                            detail.feedbackGrade!,
                            valueColor: Colors.green,
                            isBold: true,
                          ),
                        ],
                        if (detail.feedbackGradedOn != null) ...[
                          const Divider(height: 16),
                          _buildStatusRow('Graded On', detail.feedbackGradedOn!),
                        ],
                        if (detail.feedbackGradedBy != null) ...[
                          const Divider(height: 16),
                          _buildStatusRow('Graded By', detail.feedbackGradedBy!),
                        ],
                        if (detail.feedbackComments != null &&
                            detail.feedbackComments!.isNotEmpty) ...[
                          const Divider(height: 16),
                          _buildStatusRow(
                              'Feedback Comments', detail.feedbackComments!),
                        ],
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Action Buttons: Add / Edit Submission & Remove Submission
              FilledButton.icon(
                onPressed: () async {
                  final result = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => AssignmentUploadScreen(
                        assignId: assignId,
                        assignmentTitle: detail.name,
                      ),
                    ),
                  );
                  if (result == true && context.mounted) {
                    final cache = ref.read(cacheServiceProvider);
                    await cache.remove('assign_detail_$assignId');
                    ref.invalidate(assignmentDetailProvider(assignId));
                  }
                },
                icon: Icon(
                  detail.submittedFiles.isNotEmpty
                      ? Icons.edit_document
                      : Icons.cloud_upload_rounded,
                ),
                label: Text(
                  detail.submittedFiles.isNotEmpty
                      ? 'Edit / Replace Submission'
                      : 'Add Submission',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              if (detail.canRemoveSubmission && detail.isSubmitted) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color: Colors.red),
                            SizedBox(width: 8),
                            Text('Remove Submission?'),
                          ],
                        ),
                        content: const Text(
                          'Are you sure you want to remove your submission from CU LMS? Your submitted files will be deleted from the server.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            child: const Text('Remove'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true && context.mounted) {
                      final notifier = ref.read(
                          assignmentUploadProvider(assignId).notifier);
                      final success = await notifier.removeSubmission(
                        userId: detail.moodleUserId,
                      );
                      if (context.mounted) {
                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Submission removed successfully.'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          final cache = ref.read(cacheServiceProvider);
                          await cache.remove('assign_detail_$assignId');
                          ref.invalidate(assignmentDetailProvider(assignId));
                        } else {
                          final err = ref.read(assignmentUploadProvider(assignId)).errorMessage;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(err ?? 'Failed to remove submission.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    }
                  },
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: Colors.red, size: 18),
                  label: const Text(
                    'Remove Submission',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusRow(
    String label,
    String value, {
    Color? valueColor,
    bool isBold = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }
}
