import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/services/reading_html_service.dart';
import '../../../core/theme/reading_theme.dart';
import '../../../data/models/app_settings.dart';
import '../../../data/models/course_content.dart';
import '../../../data/network/lms_content_parser.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/course_provider.dart';
import '../../../providers/settings_provider.dart';
import '../browser/app_browser_screen.dart';
import 'pdf_viewer_screen.dart';

class HtmlReadingView extends ConsumerStatefulWidget {
  const HtmlReadingView({
    super.key,
    required this.html,
    required this.sourceUrl,
    required this.onProgress,
  });
  final String html;
  final String sourceUrl;
  final ValueChanged<double> onProgress;

  @override
  ConsumerState<HtmlReadingView> createState() => _HtmlReadingViewState();
}

class _HtmlReadingViewState extends ConsumerState<HtmlReadingView> {
  WebViewController? _controller;
  bool _loading = true;
  bool _failed = false;
  bool _openingLink = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  String _color(Color color) =>
      '#${color.toARGB32().toRadixString(16).substring(2)}';
  String _font(AppFontFamily font) => switch (font) {
    AppFontFamily.inter => 'Inter',
    AppFontFamily.plusJakarta => 'Plus Jakarta Sans',
    AppFontFamily.roboto => 'Roboto',
    AppFontFamily.literata => 'Georgia',
    AppFontFamily.systemSans => 'sans-serif',
  };

  Future<void> _initialize() async {
    if (kIsWeb ||
        ![
          TargetPlatform.android,
          TargetPlatform.iOS,
        ].contains(defaultTargetPlatform)) {
      if (mounted) {
        setState(() {
          _failed = true;
          _loading = false;
        });
      }
      return;
    }
    try {
      final settings = ref.read(settingsProvider);
      final theme = ReadingThemeConfig.getTheme(settings.readerContrast);
      final session = ref.read(authProvider).session;
      if (session != null) {
        await WebViewCookieManager().setCookie(
          WebViewCookie(
            name: 'MoodleSession',
            value: session.moodleSession,
            domain: 'lms.cuchd.in',
            path: '/',
          ),
        );
      }
      final math = await rootBundle.loadString('assets/mathjax/tex-mml-svg.js');
      if (!mounted) return;
      final controller = WebViewController();
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setBackgroundColor(theme.backgroundColor);
      await controller.addJavaScriptChannel(
        'ReadingProgress',
        onMessageReceived: (message) {
          final progress = double.tryParse(message.message);
          if (mounted && progress != null && progress.isFinite) {
            widget.onProgress(progress.clamp(0, 1));
          }
        },
      );
      await controller.addJavaScriptChannel(
        'ReadingLink',
        onMessageReceived: (message) {
          try {
            final link = json.decode(message.message) as Map<String, dynamic>;
            _openLink(link['url'] as String, isPdf: link['pdf'] == true);
          } catch (_) {}
        },
      );
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final target = Uri.tryParse(request.url);
            final source = Uri.tryParse(widget.sourceUrl);
            if (!request.isMainFrame ||
                request.url == 'about:blank' ||
                request.url.startsWith('data:') ||
                (target != null &&
                    source != null &&
                    target.hasFragment &&
                    target.replace(fragment: '') ==
                        source.replace(fragment: ''))) {
              return NavigationDecision.navigate;
            }
            _openLink(request.url);
            return NavigationDecision.prevent;
          },
          onPageFinished: (_) async {
            if (!mounted) return;
            await controller.runJavaScript(r'''
            document.addEventListener('click', function(event) {
              var link = event.target.closest('a[href]');
              if (!link || link.getAttribute('href').startsWith('#')) return;
              event.preventDefault();
              ReadingLink.postMessage(JSON.stringify({url: link.href,
                pdf: link.type === 'application/pdf' || /\.pdf$/i.test(link.getAttribute('download') || '')}));
            });
          ''');
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true && mounted) {
              setState(() {
                _failed = true;
                _loading = false;
              });
            }
          },
        ),
      );
      if (!mounted) return;
      setState(() => _controller = controller);
      await controller.loadHtmlString(
        ReadingHtmlService.buildDocument(
          html: widget.html,
          sourceUrl: widget.sourceUrl,
          backgroundColor: _color(theme.backgroundColor),
          textColor: _color(theme.textColor),
          accentColor: _color(theme.accentColor),
          fontFamily: _font(settings.fontFamily),
          fontScale: settings.fontScale,
          lineHeight: settings.lineHeight,
          mathJaxScript: math,
        ),
        baseUrl: widget.sourceUrl,
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _failed = true;
          _loading = false;
        });
      }
    }
  }

  Future<void> _openLink(String url, {bool isPdf = false}) async {
    final uri = Uri.tryParse(url);
    if (!mounted ||
        uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        _openingLink) {
      return;
    }
    if (ReadingHtmlService.youtubeEmbed(url) != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    if (isPdf || LmsContentParser.isPdfUrl(url)) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PdfViewerScreen(
            title: LmsContentParser.filenameFromUrl(url),
            url: url,
            downloadUrl: url,
          ),
        ),
      );
      return;
    }
    // An extensionless LMS download may return application/pdf after redirects.
    if (uri.host == 'lms.cuchd.in' &&
        (uri.path.contains('pluginfile.php') ||
            uri.path.contains('/mod/resource/'))) {
      setState(() => _openingLink = true);
      try {
        final content = await ref.read(lmsContentProvider(url).future);
        if (!mounted) return;
        if (content.type == LmsItemType.singleDocument &&
            content.items.isNotEmpty) {
          final item = content.items.first;
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PdfViewerScreen(
                title: item.name,
                url: item.viewerUrl,
                downloadUrl: item.downloadUrl,
              ),
            ),
          );
          return;
        }
      } catch (_) {
        // Keep the original browser fallback for files the extractor cannot read.
      } finally {
        if (mounted) setState(() => _openingLink = false);
      }
    }
    if (mounted) await AppBrowserScreen.open(context, url: url);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(settingsProvider, (_, settings) {
      final theme = ReadingThemeConfig.getTheme(settings.readerContrast);
      _controller?.setBackgroundColor(theme.backgroundColor);
      _controller?.runJavaScript('''
        document.documentElement.style.backgroundColor=${json.encode(_color(theme.backgroundColor))};
        document.documentElement.style.color=${json.encode(_color(theme.textColor))};
        document.body.style.fontSize=${json.encode('${16 * settings.fontScale}px')};
        document.body.style.lineHeight=${json.encode(settings.lineHeight.toString())};
        document.body.style.fontFamily=${json.encode(_font(settings.fontFamily))};
      ''');
    });
    if (_failed) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            OutlinedButton.icon(
              onPressed: () => launchUrl(
                Uri.parse(widget.sourceUrl),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_browser),
              label: const Text('Open lesson in browser'),
            ),
            const SizedBox(height: 16),
            SelectableText(ReadingHtmlService.plainText(widget.html)),
          ],
        ),
      );
    }
    return Stack(
      children: [
        if (_controller != null) WebViewWidget(controller: _controller!),
        if (_loading || _openingLink)
          const Align(
            alignment: Alignment.topCenter,
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }
}
