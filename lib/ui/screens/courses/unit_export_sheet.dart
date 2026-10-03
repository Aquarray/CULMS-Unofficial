import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/course_content.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/settings_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'ai_study_prompt_sheet.dart';

class UnitExportSheet extends ConsumerStatefulWidget {
  final String courseName;
  final CourseUnit unit;

  const UnitExportSheet({
    super.key,
    required this.courseName,
    required this.unit,
  });

  @override
  ConsumerState<UnitExportSheet> createState() => _UnitExportSheetState();
}

class _UnitExportSheetState extends ConsumerState<UnitExportSheet> {
  bool _isExporting = false;
  int _current = 0;
  int _total = 0;
  String _statusText = '';
  File? _resultZip;
  String? _errorMessage;

  List<LmsContentItem> _extractDownloadableItems() {
    final list = <LmsContentItem>[];
    for (final act in widget.unit.activities) {
      if (act.iconType == 'file' || act.iconType == 'folder' || act.iconType == 'page') {
        list.add(LmsContentItem(
          name: act.name,
          downloadUrl: act.url,
          fileType: act.iconType == 'page' ? 'page' : act.typeName.toLowerCase(),
        ));
      }
    }
    return list;
  }

  Future<void> _startExport() async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated || auth.session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Active session required to download files.')),
      );
      return;
    }

    final items = _extractDownloadableItems();
    if (items.isEmpty) {
      setState(() {
        _errorMessage = 'No downloadable files found in this unit.';
      });
      return;
    }

    setState(() {
      _isExporting = true;
      _errorMessage = null;
      _current = 0;
      _total = items.length;
      _statusText = 'Preparing export...';
    });

    try {
      final exportService = ref.read(zipExportServiceProvider);
      final settings = ref.read(settingsProvider);

      final zipFile = await exportService.exportUnitToZip(
        courseName: widget.courseName,
        unitName: widget.unit.title,
        items: items,
        moodleSession: auth.session!.moodleSession,
        autoShare: settings.autoShareExportedZip,
        onProgress: (current, total, status) {
          if (mounted) {
            setState(() {
              _current = current;
              _total = total;
              _statusText = status;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isExporting = false;
          _resultZip = zipFile;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = _extractDownloadableItems();
    final settings = ref.watch(settingsProvider);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.archive_outlined, color: Colors.amber, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Export Unit as ZIP',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      widget.unit.title,
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (settings.enableLearnWithAi)
                IconButton(
                  icon: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF8B5CF6)),
                  tooltip: 'Learn with AI',
                  onPressed: () {
                    Navigator.of(context).pop();
                    AiStudyPromptSheet.show(
                      context,
                      courseName: widget.courseName,
                      unit: widget.unit,
                    );
                  },
                ),
              ],
            ),
          const SizedBox(height: 16),

          Text(
            'Package all ${items.length} materials in this unit directly into a compressed .zip archive for offline study or sharing.',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 16),

          if (_isExporting) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _total > 0 ? (_current / _total) : null,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _statusText,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
          ],

          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
          ],

          if (_resultZip != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.green, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _resultZip!.path.contains('Download')
                              ? 'Saved to Downloads Folder!'
                              : 'ZIP Archive Ready!',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _resultZip!.path.split('/').last,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.share_outlined, size: 20),
                    tooltip: 'Share ZIP',
                    onPressed: () {
                      Share.shareXFiles(
                        [XFile(_resultZip!.path)],
                        subject: '${widget.courseName} - ${widget.unit.title} Files',
                      );
                    },
                  ),
                ],
              ),
            ),
            if (settings.enableLearnWithAi) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  AiStudyPromptSheet.show(
                    context,
                    courseName: widget.courseName,
                    unit: widget.unit,
                  );
                },
                icon: const Icon(Icons.auto_awesome_rounded, size: 18, color: Color(0xFF8B5CF6)),
                label: const Text('Learn with AI (Gemini / ChatGPT)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF6366F1),
                  side: const BorderSide(color: Color(0xFF8B5CF6)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],

          ElevatedButton.icon(
            onPressed: _isExporting ? null : _startExport,
            icon: const Icon(Icons.download_rounded, size: 18),
            label: Text(_isExporting ? 'Exporting...' : 'Generate & Export ZIP'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
