import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:share_plus/share_plus.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/auth_provider.dart';

class PdfViewerScreen extends ConsumerStatefulWidget {
  final String title;
  final String? url;
  final File? localFile;
  final String? downloadUrl;

  const PdfViewerScreen({
    super.key,
    required this.title,
    this.url,
    this.localFile,
    this.downloadUrl,
  });

  @override
  ConsumerState<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends ConsumerState<PdfViewerScreen> {
  late final PdfViewerController _pdfController;
  int _pageNumber = 1;
  int _pageCount = 0;
  bool _isDownloading = false;
  File? _downloadedFile;
  bool _isInverted = false;

  @override
  void initState() {
    super.initState();
    _pdfController = PdfViewerController();
    _downloadedFile = widget.localFile;

    if (_downloadedFile == null && widget.url != null) {
      _downloadAndCachePdf();
    }
  }

  Future<void> _downloadAndCachePdf() async {
    final targetUrl = widget.url ?? widget.downloadUrl;
    if (targetUrl == null) return;

    setState(() {
      _isDownloading = true;
    });

    try {
      final cacheService = ref.read(cacheServiceProvider);
      final filename = '${widget.title.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}.pdf';

      // Check if already in cache
      final existing = await cacheService.getCachedFile(filename);
      if (existing != null) {
        setState(() {
          _downloadedFile = existing;
          _isDownloading = false;
        });
        return;
      }

      // Download with Moodle Session
      final auth = ref.read(authProvider);
      final dio = ref.read(dioProvider);

      final resp = await dio.get<List<int>>(
        targetUrl,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {
            if (auth.session != null) 'Cookie': 'MoodleSession=${auth.session!.moodleSession}',
            'User-Agent': 'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36',
          },
        ),
      );

      if (resp.data != null) {
        final saved = await cacheService.saveFile(filename, resp.data!);
        setState(() {
          _downloadedFile = saved;
          _isDownloading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isDownloading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load PDF: $e')),
        );
      }
    }
  }

  void _sharePdf() {
    if (_downloadedFile != null) {
      Share.shareXFiles([XFile(_downloadedFile!.path)], text: widget.title);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isInverted ? Icons.invert_colors_off_rounded : Icons.invert_colors_rounded,
              color: _isInverted ? Colors.amber : null,
            ),
            tooltip: 'Night Inversion',
            onPressed: () {
              setState(() {
                _isInverted = !_isInverted;
              });
            },
          ),
          if (_downloadedFile != null)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Share / Export PDF',
              onPressed: _sharePdf,
            ),
        ],
      ),
      body: _isDownloading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Loading document...',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            )
          : _downloadedFile != null
              ? Stack(
                  children: [
                    ColorFiltered(
                      colorFilter: _isInverted
                          ? const ColorFilter.matrix([
                              -1, 0, 0, 0, 255, // red
                              0, -1, 0, 0, 255, // green
                              0, 0, -1, 0, 255, // blue
                              0, 0, 0, 1, 0, // alpha
                            ])
                          : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                      child: PdfViewer.file(
                        _downloadedFile!.path,
                        controller: _pdfController,
                        params: PdfViewerParams(
                          onPageChanged: (page) {
                            setState(() {
                              _pageNumber = page ?? 1;
                            });
                          },
                          onViewerReady: (document, controller) {
                            setState(() {
                              _pageCount = document.pages.length;
                            });
                          },
                        ),
                      ),
                    ),

                    // Floating Bottom Controls
                    Positioned(
                      bottom: 20,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 16),
                                onPressed: _pageNumber > 1
                                    ? () => _pdfController.goToPage(pageNumber: _pageNumber - 1)
                                    : null,
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Text(
                                  '$_pageNumber / ${_pageCount > 0 ? _pageCount : "-"}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
                                onPressed: _pageNumber < _pageCount
                                    ? () => _pdfController.goToPage(pageNumber: _pageNumber + 1)
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 20),
                                onPressed: () {
                                  _pdfController.zoomUp();
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.zoom_out_rounded, color: Colors.white, size: 20),
                                onPressed: () {
                                  _pdfController.zoomDown();
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.picture_as_pdf_outlined, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text('Failed to load PDF preview'),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _downloadAndCachePdf,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
    );
  }
}
