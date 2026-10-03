import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../data/models/assignment.dart';
import '../../../providers/assignment_provider.dart';
import '../browser/app_browser_screen.dart';
import '../reader/pdf_viewer_screen.dart';

class AssignmentUploadScreen extends ConsumerStatefulWidget {
  final int assignId;
  final String? assignmentTitle;

  const AssignmentUploadScreen({
    super.key,
    required this.assignId,
    this.assignmentTitle,
  });

  @override
  ConsumerState<AssignmentUploadScreen> createState() =>
      _AssignmentUploadScreenState();
}

class _AssignmentUploadScreenState
    extends ConsumerState<AssignmentUploadScreen> {
  Future<void> _pickAndStageFile(AssignmentSubmissionConfig config) async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.any,
      );

      if (files.isEmpty) return;

      final file = files.first;
      final name = file.name;

      final bytes = await file.xFile.readAsBytes();
      await _uploadBytes(name, bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File selection failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _uploadBytes(String name, List<int> bytes) async {
    final notifier =
        ref.read(assignmentUploadProvider(widget.assignId).notifier);
    final success = await notifier.stageDraftFile(
      filename: name,
      bytes: bytes,
    );

    if (!mounted) return;
    final state = ref.read(assignmentUploadProvider(widget.assignId));
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully staged "$name" in draft.'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (state.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.errorMessage!),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _confirmDelete(String filename) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Draft File?'),
        content: Text(
          'Are you sure you want to remove "$filename" from the draft area?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final notifier =
          ref.read(assignmentUploadProvider(widget.assignId).notifier);
      await notifier.deleteDraftFile(filename);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Removed "$filename" from draft.')),
        );
      }
    }
  }

  Future<void> _confirmAndSubmit(AssignmentSubmissionConfig config) async {
    if (config.draftFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select and stage a file first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final stagedName = config.draftFiles.first.filename;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline_rounded, color: Colors.green),
            SizedBox(width: 8),
            Text('Confirm Submission'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to submit your assignment for grading?',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.description_rounded, size: 20, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      stagedName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Once submitted, CU LMS will register your work and mark it as submitted for faculty grading.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('Submit Now'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final notifier =
          ref.read(assignmentUploadProvider(widget.assignId).notifier);
      final success = await notifier.submitFinalAssignment();

      if (!mounted) return;

      if (success) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.task_alt_rounded, color: Colors.green, size: 28),
                SizedBox(width: 10),
                Text('Submitted!'),
              ],
            ),
            content: const Text(
              'Your assignment was successfully submitted to CU LMS and recorded for grading.',
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop(true);
                },
                child: const Text('Back to Assignment'),
              ),
            ],
          ),
        );
      } else {
        final state = ref.read(assignmentUploadProvider(widget.assignId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.errorMessage ?? 'Submission failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uploadState = ref.watch(assignmentUploadProvider(widget.assignId));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.assignmentTitle ?? 'Submit Assignment',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () {
              ref
                  .read(assignmentUploadProvider(widget.assignId).notifier)
                  .loadConfig(forceRefresh: true);
            },
          ),
        ],
      ),
      body: uploadState.isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading submission configuration...'),
                ],
              ),
            )
          : uploadState.config == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            size: 48, color: Colors.orange),
                        const SizedBox(height: 12),
                        const Text(
                          'Submission Area Unavailable',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          uploadState.errorMessage ??
                              'This assignment might not be currently open for file submissions.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () => ref
                              .read(assignmentUploadProvider(widget.assignId)
                                  .notifier)
                              .loadConfig(forceRefresh: true),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    // Instructions & Workflow banner
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.primary.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded,
                              color: theme.colorScheme.primary, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Assignment Submission Flow',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '1. Choose and stage your file.\n2. Verify the preview.\n3. Click "Submit Assignment" to officially submit it for grading.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Constraints & Limits Card
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
                                Icon(Icons.tune_rounded, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Submission Rules & Limits',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                _buildConstraintBadge(
                                  icon: Icons.inventory_2_outlined,
                                  label: 'Max Files',
                                  value:
                                      '${uploadState.config!.maxFiles} file',
                                  theme: theme,
                                ),
                                const SizedBox(width: 12),
                                _buildConstraintBadge(
                                  icon: Icons.data_usage_rounded,
                                  label: 'Max Size',
                                  value: uploadState.config!.maxBytesText,
                                  theme: theme,
                                ),
                              ],
                            ),
                            if (uploadState.config!.acceptedTypes.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              const Text(
                                'Accepted Formats',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: uploadState.config!.acceptedTypes
                                    .map(
                                      (t) => Chip(
                                        label: Text(
                                          t,
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                        padding: EdgeInsets.zero,
                                        visualDensity: VisualDensity.compact,
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Staged Draft Files Card
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.folder_shared_outlined, size: 18),
                                    SizedBox(width: 8),
                                    Text(
                                      'Staged Files for Submission',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: theme.primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${uploadState.config!.draftFiles.length} / ${uploadState.config!.maxFiles}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: theme.primaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (uploadState.config!.draftFiles.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.02)
                                      : Colors.grey.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white10
                                        : Colors.black12,
                                    style: BorderStyle.solid,
                                  ),
                                ),
                                child: const Column(
                                  children: [
                                    Icon(Icons.cloud_upload_outlined,
                                        size: 40, color: Colors.grey),
                                    SizedBox(height: 8),
                                    Text(
                                      'No file selected yet',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Select a file from your device below to stage it.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 11, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              )
                            else
                              ...uploadState.config!.draftFiles.map((file) {
                                final isPdf =
                                    file.filename.toLowerCase().endsWith('.pdf');
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withOpacity(0.04)
                                        : Colors.grey.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.white12
                                          : Colors.black12,
                                    ),
                                  ),
                                  child: ListTile(
                                    dense: true,
                                    leading: Icon(
                                      isPdf
                                          ? Icons.picture_as_pdf_rounded
                                          : Icons.insert_drive_file_rounded,
                                      color: isPdf
                                          ? Colors.redAccent
                                          : theme.primaryColor,
                                    ),
                                    title: Text(
                                      file.filename,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      file.filesize ?? 'Staged ready to submit',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isPdf && file.url != null)
                                          IconButton(
                                            icon: const Icon(
                                                Icons.visibility_rounded,
                                                size: 20),
                                            tooltip: 'Preview PDF',
                                            onPressed: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      PdfViewerScreen(
                                                    title: file.filename,
                                                    downloadUrl: file.url,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline_rounded,
                                            size: 20,
                                            color: Colors.redAccent,
                                          ),
                                          tooltip: 'Remove',
                                          onPressed: () =>
                                              _confirmDelete(file.filename),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // File Selection / Upload Button
                    if (uploadState.isUploading)
                      const Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text('Uploading file to Moodle draft area...'),
                          ],
                        ),
                      )
                    else if (uploadState.isSubmitting)
                      const Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text(
                              'Submitting assignment to CU LMS...',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      OutlinedButton.icon(
                        onPressed: () => _pickAndStageFile(uploadState.config!),
                        icon: const Icon(Icons.add_circle_outline_rounded),
                        label: Text(
                          uploadState.config!.draftFiles.isEmpty
                              ? 'Choose File from Device'
                              : 'Replace Staged File',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Final Submit Assignment Button
                      FilledButton.icon(
                        onPressed: uploadState.config!.draftFiles.isEmpty
                            ? null
                            : () => _confirmAndSubmit(uploadState.config!),
                        icon: const Icon(Icons.task_alt_rounded),
                        label: const Text(
                          'Submit Assignment',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Fallback button to open Moodle editsubmission page
                    Center(
                      child: TextButton.icon(
                        onPressed: () {
                          AppBrowserScreen.open(
                            context,
                            url: 'https://lms.cuchd.in/mod/assign/view.php?id=${widget.assignId}&action=editsubmission',
                            title: widget.assignmentTitle ?? 'Edit Submission',
                          );
                        },
                        icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                        label: const Text(
                          'Open in Moodle Browser',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
    );
  }

  Widget _buildConstraintBadge({
    required IconData icon,
    required String label,
    required String value,
    required ThemeData theme,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
