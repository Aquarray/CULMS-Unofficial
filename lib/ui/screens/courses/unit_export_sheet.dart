import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/services/zip_export_service.dart';
import '../../../data/models/app_settings.dart';
import '../../../data/models/course_content.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../widgets/ai_brand_icons.dart';
import 'ai_study_prompt_sheet.dart';

enum ExportScope { chapter, wholeUnit }

/// Minimal, elegant bottom sheet for exporting course materials as a ZIP archive or direct folder.
class UnitExportSheet extends ConsumerStatefulWidget {
  final String courseName;
  final CourseUnit? unit;
  final String? groupTitle;
  final List<CourseUnit> allUnitsInGroup;
  final bool exportWholeGroupInitially;

  const UnitExportSheet({
    super.key,
    required this.courseName,
    this.unit,
    this.groupTitle,
    this.allUnitsInGroup = const [],
    this.exportWholeGroupInitially = false,
  });

  @override
  ConsumerState<UnitExportSheet> createState() => _UnitExportSheetState();
}

class _UnitExportSheetState extends ConsumerState<UnitExportSheet> {
  late ExportScope _selectedScope;
  late MaterialExportFormat _selectedFormat;
  bool _isExporting = false;
  int _current = 0;
  int _total = 0;
  String _statusText = '';
  MaterialExportResult? _exportResult;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final hasGroup = widget.allUnitsInGroup.isNotEmpty;
    if (widget.exportWholeGroupInitially && hasGroup) {
      _selectedScope = ExportScope.wholeUnit;
    } else if (widget.unit != null) {
      _selectedScope = ExportScope.chapter;
    } else if (hasGroup) {
      _selectedScope = ExportScope.wholeUnit;
    } else {
      _selectedScope = ExportScope.chapter;
    }
    _selectedFormat = ref.read(settingsProvider).exportFormat;
  }

  List<LmsContentItem> _extractItemsFromUnits(List<CourseUnit> units) {
    final list = <LmsContentItem>[];
    final seenUrls = <String>{};

    for (final unit in units) {
      for (final act in unit.activities) {
        if (act.iconType == 'file' || act.iconType == 'folder' || act.iconType == 'page') {
          if (act.url.isNotEmpty && seenUrls.add(act.url)) {
            list.add(LmsContentItem(
              name: act.name,
              downloadUrl: act.url,
              fileType: act.iconType == 'page' ? 'page' : act.typeName.toLowerCase(),
            ),);
          }
        }
      }
    }
    return list;
  }

  List<LmsContentItem> _getActiveItems() {
    if (_selectedScope == ExportScope.wholeUnit && widget.allUnitsInGroup.isNotEmpty) {
      return _extractItemsFromUnits(widget.allUnitsInGroup);
    }
    if (widget.unit != null) {
      return _extractItemsFromUnits([widget.unit!]);
    }
    return _extractItemsFromUnits(widget.allUnitsInGroup);
  }

  String _getActiveTitle() {
    if (_selectedScope == ExportScope.wholeUnit && widget.allUnitsInGroup.isNotEmpty) {
      return widget.groupTitle ?? widget.unit?.parentUnit ?? 'Whole Unit';
    }
    return widget.unit?.title ?? widget.groupTitle ?? 'Unit Materials';
  }

  Future<void> _startExport() async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated || auth.session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Active session required to download files.'),),
      );
      return;
    }

    final items = _getActiveItems();
    if (items.isEmpty) {
      setState(() {
        _errorMessage = 'No downloadable files found in this selection.';
      });
      return;
    }

    setState(() {
      _isExporting = true;
      _errorMessage = null;
      _current = 0;
      _total = items.length;
      _statusText = 'Preparing export...';
      _exportResult = null;
    });

    try {
      final exportService = ref.read(zipExportServiceProvider);
      final settings = ref.read(settingsProvider);
      final activeTitle = _getActiveTitle();

      final result = await exportService.exportUnitMaterials(
        courseName: widget.courseName,
        unitName: activeTitle,
        items: items,
        moodleSession: auth.session!.moodleSession,
        accountId: auth.session!.uid,
        format: _selectedFormat,
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
          _exportResult = result;
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
    final isDark = theme.brightness == Brightness.dark;
    final settings = ref.watch(settingsProvider);

    final chapterItems = widget.unit != null ? _extractItemsFromUnits([widget.unit!]) : <LmsContentItem>[];
    final wholeGroupItems = widget.allUnitsInGroup.isNotEmpty
        ? _extractItemsFromUnits(widget.allUnitsInGroup)
        : chapterItems;

    final activeItems = _getActiveItems();
    final hasMultipleScopeOptions = widget.unit != null && widget.allUnitsInGroup.length > 1;
    final groupName = widget.groupTitle ?? widget.unit?.parentUnit ?? 'Unit';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // Minimal Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _selectedFormat == MaterialExportFormat.zip
                        ? Icons.folder_zip_rounded
                        : Icons.folder_open_rounded,
                    color: Colors.amber,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedFormat == MaterialExportFormat.zip
                            ? 'Export Materials as ZIP'
                            : 'Export Materials to Folder',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold,),
                      ),
                      Text(
                        widget.courseName,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Scope Selector: This Chapter vs Whole Unit
            if (hasMultipleScopeOptions && !_isExporting && _exportResult == null) ...[
              SegmentedButton<ExportScope>(
                segments: [
                  ButtonSegment<ExportScope>(
                    value: ExportScope.chapter,
                    icon: const Icon(Icons.menu_book_rounded, size: 16),
                    label: Text(
                      'Chapter (${chapterItems.length})',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  ButtonSegment<ExportScope>(
                    value: ExportScope.wholeUnit,
                    icon: const Icon(Icons.folder_zip_rounded, size: 16),
                    label: Text(
                      'Whole $groupName (${wholeGroupItems.length})',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
                selected: {_selectedScope},
                onSelectionChanged: (newSelection) {
                  setState(() {
                    _selectedScope = newSelection.first;
                    _errorMessage = null;
                  });
                },
              ),
              const SizedBox(height: 10),
            ],

            // Format Toggle: ZIP Archive vs Direct Folder
            if (!_isExporting && _exportResult == null) ...[
              Row(
                children: [
                  Expanded(
                    child: SegmentedButton<MaterialExportFormat>(
                      segments: const [
                        ButtonSegment(
                          value: MaterialExportFormat.zip,
                          icon: Icon(Icons.folder_zip_rounded, size: 15),
                          label: Text('ZIP (.zip)', style: TextStyle(fontSize: 11),),
                        ),
                        ButtonSegment(
                          value: MaterialExportFormat.folder,
                          icon: Icon(Icons.folder_open_rounded, size: 15),
                          label: Text('Folder', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                      selected: {_selectedFormat},
                      onSelectionChanged: (newVal) {
                        setState(() {
                          _selectedFormat = newVal.first;
                          _errorMessage = null;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],

            const SizedBox(height: 14),

            // Progress indicator during export
            if (_isExporting) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _total > 0 ? (_current / _total) : null,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _statusText,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$_current/$_total',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold,),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],

            // Error display
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.red, size: 18,),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Success display
            if (_exportResult != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10,),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3),),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20,),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _exportResult!.isZip
                                ? 'Saved in Downloads/CULMS'
                                : 'Folder created in Downloads/CULMS',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          Text(
                            _exportResult!.isZip
                                ? _exportResult!.zipFile!.path.split('/').last
                                : 'CULMS/${_exportResult!.path.split('/CULMS/').last}',
                            style: const TextStyle(fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.share_outlined, size: 18),
                      tooltip: 'Share',
                      onPressed: () {
                        SharePlus.instance.share(
                          ShareParams(
                            files: _exportResult!.files.map((f) => XFile(f.path)).toList(),
                            subject: '${widget.courseName} - ${_getActiveTitle()}',
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              if (settings.enableLearnWithAi && widget.unit != null) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    AiStudyPromptSheet.show(
                      context,
                      courseName: widget.courseName,
                      unit: widget.unit!,
                      itemsCount: _getActiveItems().length,
                      isChapter: _selectedScope == ExportScope.chapter,
                    );
                  },
                  icon: const GeminiIcon(size: 16, useGradient: true),
                  label: const Text(
                    'Study this unit with AI',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
              const SizedBox(height: 10),
            ],

            // Main Action Button
            if (_exportResult == null)
              FilledButton.icon(
                onPressed: _isExporting || activeItems.isEmpty ? null : _startExport,
                icon: _isExporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        _selectedFormat == MaterialExportFormat.zip
                            ? Icons.download_rounded
                            : Icons.drive_folder_upload_rounded,
                        size: 18,
                      ),
                label: Text(
                  _isExporting
                      ? 'Exporting... ($_current/$_total)'
                      : 'Export (${activeItems.length} files)',
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),),
                ),
              )
            else
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),),
                ),
                child: const Text('Done'),
              ),
          ],
        ),
      ),
    );
  }
}
