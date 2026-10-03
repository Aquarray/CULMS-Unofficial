import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/theme/reading_theme.dart';
import '../../../data/models/app_settings.dart';
import '../../../providers/settings_provider.dart';

class MarkdownViewerScreen extends ConsumerStatefulWidget {
  final String title;
  final String markdownContent;

  const MarkdownViewerScreen({
    super.key,
    required this.title,
    required this.markdownContent,
  });

  @override
  ConsumerState<MarkdownViewerScreen> createState() => _MarkdownViewerScreenState();
}

class _MarkdownViewerScreenState extends ConsumerState<MarkdownViewerScreen> {
  final ScrollController _scrollController = ScrollController();
  double _readingProgress = 0.0;

  bool _showAudioBar = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateProgress);
  }

  void _updateProgress() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final current = _scrollController.position.pixels;
    if (maxScroll > 0) {
      setState(() {
        _readingProgress = (current / maxScroll).clamp(0.0, 1.0);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    // Stop reading when leaving page
    ref.read(ttsProvider.notifier).stop();
    super.dispose();
  }

  void _toggleAudioBar() {
    final ttsState = ref.read(ttsProvider);
    setState(() {
      _showAudioBar = !_showAudioBar;
    });
    if (_showAudioBar && ttsState.isStopped) {
      ref.read(ttsProvider.notifier).speakMarkdown(widget.markdownContent);
    }
  }

  int _estimateReadTimeMinutes() {
    final words = widget.markdownContent.split(RegExp(r'\s+')).length;
    final minutes = (words / 200).ceil();
    return minutes < 1 ? 1 : minutes;
  }

  void _showReadingPreferencesSheet() {
    final notifier = ref.read(settingsProvider.notifier);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final currentSettings = ref.watch(settingsProvider);

            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Reading Environment',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Contrast Preset Selector
                  const Text('Contrast Theme', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ReaderContrast.values.map((contrast) {
                        final isSelected = currentSettings.readerContrast == contrast;
                        final config = ReadingThemeConfig.getTheme(contrast);

                        String label = '';
                        switch (contrast) {
                          case ReaderContrast.cleanLight:
                            label = 'Light';
                            break;
                          case ReaderContrast.mediumSepia:
                            label = 'Sepia Warm';
                            break;
                          case ReaderContrast.softDark:
                            label = 'Soft Dark';
                            break;
                          case ReaderContrast.oledBlack:
                            label = 'OLED Black';
                            break;
                          case ReaderContrast.forestMist:
                            label = 'Forest';
                            break;
                        }

                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: InkWell(
                            onTap: () {
                              notifier.updateReaderContrast(contrast);
                              setSheetState(() {});
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: config.backgroundColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? Colors.redAccent : Colors.grey.withOpacity(0.3),
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 6,
                                    backgroundColor: config.textColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    label,
                                    style: TextStyle(
                                      color: config.textColor,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Font Family Selector
                  const Text('Sans-Serif Typography', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: AppFontFamily.values.map((font) {
                      final isSelected = currentSettings.fontFamily == font;
                      String name = '';
                      switch (font) {
                        case AppFontFamily.inter:
                          name = 'Inter';
                          break;
                        case AppFontFamily.plusJakarta:
                          name = 'Plus Jakarta';
                          break;
                        case AppFontFamily.roboto:
                          name = 'Roboto';
                          break;
                        case AppFontFamily.literata:
                          name = 'Literata';
                          break;
                        case AppFontFamily.systemSans:
                          name = 'System Sans';
                          break;
                      }

                      return ChoiceChip(
                        label: Text(name),
                        selected: isSelected,
                        onSelected: (val) {
                          if (val) {
                            notifier.updateFontFamily(font);
                            setSheetState(() {});
                          }
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // Font Size Scale
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Font Scale', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      Text('${(currentSettings.fontScale * 100).toInt()}%',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Slider(
                    value: currentSettings.fontScale,
                    min: 0.8,
                    max: 1.4,
                    divisions: 6,
                    label: '${(currentSettings.fontScale * 100).toInt()}%',
                    onChanged: (val) {
                      notifier.updateFontScale(val);
                      setSheetState(() {});
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final themeConfig = ReadingThemeConfig.getTheme(settings.readerContrast);
    final ttsState = ref.watch(ttsProvider);

    final baseTextStyle = ReadingThemeConfig.getReadingTextStyle(
      fontFamily: settings.fontFamily,
      fontScale: settings.fontScale,
      lineHeight: settings.lineHeight,
      color: themeConfig.textColor,
    );

    return Scaffold(
      backgroundColor: themeConfig.backgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Column(
          children: [
            AppBar(
              backgroundColor: themeConfig.backgroundColor,
              foregroundColor: themeConfig.textColor,
              elevation: 0,
              title: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: themeConfig.textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              actions: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: themeConfig.codeBackgroundColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_estimateReadTimeMinutes()} min read',
                      style: TextStyle(
                        fontSize: 11,
                        color: themeConfig.secondaryTextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                // Read Aloud / TTS toggle button
                IconButton(
                  icon: Icon(
                    ttsState.isPlaying
                        ? Icons.volume_up_rounded
                        : (ttsState.isPaused ? Icons.pause_circle_outline_rounded : Icons.headphones_rounded),
                    color: ttsState.isPlaying || _showAudioBar ? themeConfig.accentColor : themeConfig.textColor,
                  ),
                  tooltip: 'Read Aloud (TTS)',
                  onPressed: _toggleAudioBar,
                ),
                IconButton(
                  icon: const Icon(Icons.format_size_rounded),
                  tooltip: 'Reading Customizer',
                  onPressed: _showReadingPreferencesSheet,
                ),
              ],
            ),
            // Progress Bar at the top of reading screen
            LinearProgressIndicator(
              value: _readingProgress,
              backgroundColor: themeConfig.dividerColor,
              valueColor: AlwaysStoppedAnimation<Color>(themeConfig.accentColor),
              minHeight: 2.5,
            ),
          ],
        ),
      ),
      bottomNavigationBar: _showAudioBar
          ? _buildTtsAudioBar(context, themeConfig, ttsState, settings)
          : null,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 750), // Optimal reading column width
            child: Markdown(
              controller: _scrollController,
              data: widget.markdownContent,
              selectable: true,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              styleSheet: MarkdownStyleSheet(
                p: baseTextStyle,
                h1: baseTextStyle.copyWith(
                  fontSize: (26 * settings.fontScale).toDouble(),
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                  letterSpacing: -0.5,
                ),
                h2: baseTextStyle.copyWith(
                  fontSize: (22 * settings.fontScale).toDouble(),
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
                h3: baseTextStyle.copyWith(
                  fontSize: (18 * settings.fontScale).toDouble(),
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
                blockquote: baseTextStyle.copyWith(
                  color: themeConfig.secondaryTextColor,
                  fontStyle: FontStyle.italic,
                ),
                blockquoteDecoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: themeConfig.accentColor,
                      width: 3.5,
                    ),
                  ),
                ),
                code: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: (14 * settings.fontScale).toDouble(),
                  color: themeConfig.accentColor,
                  backgroundColor: themeConfig.codeBackgroundColor,
                ),
                codeblockDecoration: BoxDecoration(
                  color: themeConfig.codeBackgroundColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: themeConfig.dividerColor),
                ),
                horizontalRuleDecoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: themeConfig.dividerColor,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTtsAudioBar(
    BuildContext context,
    ReadingThemeConfig themeConfig,
    TtsState ttsState,
    AppSettings settings,
  ) {
    final ttsNotifier = ref.read(ttsProvider.notifier);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    return Container(
      decoration: BoxDecoration(
        color: themeConfig.backgroundColor,
        border: Border(top: BorderSide(color: themeConfig.dividerColor, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress line
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: ttsState.currentProgress > 0 ? ttsState.currentProgress : null,
                backgroundColor: themeConfig.dividerColor,
                valueColor: AlwaysStoppedAnimation<Color>(themeConfig.accentColor),
                minHeight: 3,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  ttsState.isPlaying ? Icons.record_voice_over_rounded : Icons.voice_over_off_rounded,
                  color: ttsState.isPlaying ? themeConfig.accentColor : themeConfig.secondaryTextColor,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        ttsState.isPlaying
                            ? 'Reading aloud...'
                            : (ttsState.isPaused ? 'Paused' : 'Ready to read'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: themeConfig.textColor,
                        ),
                      ),
                      Text(
                        '${(settings.ttsSpeechRate * 2).toStringAsFixed(1)}x speed • ${settings.ttsLanguage}',
                        style: TextStyle(
                          fontSize: 11,
                          color: themeConfig.secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                // Speed Chip
                InkWell(
                  onTap: () {
                    // Cycle speed: 0.4 (0.8x) -> 0.5 (1.0x) -> 0.6 (1.2x) -> 0.75 (1.5x)
                    double nextRate = 0.5;
                    if (settings.ttsSpeechRate < 0.45) {
                      nextRate = 0.5;
                    } else if (settings.ttsSpeechRate < 0.55) {
                      nextRate = 0.65;
                    } else if (settings.ttsSpeechRate < 0.7) {
                      nextRate = 0.8;
                    } else {
                      nextRate = 0.4;
                    }
                    settingsNotifier.updateTtsSpeechRate(nextRate);
                    ttsNotifier.applySettings(settings.copyWith(ttsSpeechRate: nextRate));
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: themeConfig.codeBackgroundColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: themeConfig.dividerColor),
                    ),
                    child: Text(
                      '${(settings.ttsSpeechRate * 2).toStringAsFixed(1)}x',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: themeConfig.textColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Play / Pause Button
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: themeConfig.accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(8),
                  ),
                  icon: Icon(
                    ttsState.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 20,
                  ),
                  onPressed: () {
                    if (ttsState.isPlaying) {
                      ttsNotifier.pause();
                    } else if (ttsState.isPaused) {
                      ttsNotifier.resume();
                    } else {
                      ttsNotifier.speakMarkdown(widget.markdownContent);
                    }
                  },
                ),
                const SizedBox(width: 4),
                // Stop Button
                IconButton(
                  icon: const Icon(Icons.stop_rounded),
                  color: themeConfig.secondaryTextColor,
                  tooltip: 'Stop',
                  onPressed: () {
                    ttsNotifier.stop();
                  },
                ),
                // Dismiss Bar Button
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: themeConfig.secondaryTextColor,
                  tooltip: 'Hide audio player',
                  onPressed: () {
                    setState(() {
                      _showAudioBar = false;
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

