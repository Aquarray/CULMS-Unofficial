import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../models/course_content.dart';

/// Keeps document/folder detection separate from lesson rendering so richer
/// pages cannot accidentally replace the existing resource flows.
class LmsContentParser {
  static bool isPdfUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null && uri.path.toLowerCase().endsWith('.pdf');
  }

  static String? resolveUrl(String? value, String baseUrl) {
    if (value == null || value.trim().isEmpty) return null;
    final uri = Uri.tryParse(baseUrl)?.resolve(value.trim());
    if (uri == null || !['http', 'https'].contains(uri.scheme)) return null;
    return uri.toString();
  }

  static String filenameFromUrl(
    String url, {
    String fallback = 'Document.pdf',
  }) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.pathSegments.isEmpty) return fallback;
    final name = uri.pathSegments.last;
    return name.toLowerCase().endsWith('.pdf') ? name : fallback;
  }

  static LmsExtractedContent pdf(String url, {String? title}) {
    final name = title ?? filenameFromUrl(url);
    return LmsExtractedContent(
      pageTitle: name,
      type: LmsItemType.singleDocument,
      originalUrl: url,
      items: [
        LmsContentItem(
          name: name,
          viewerUrl: url,
          downloadUrl: url,
          fileType: 'pdf',
        ),
      ],
    );
  }

  static LmsExtractedContent parseHtml(String html, {required String url}) {
    final doc = html_parser.parse(html);
    final pageTitle =
        doc.querySelector('.page-header-headings h1')?.text.trim() ??
        doc.querySelector('h1, h2, title')?.text.trim() ??
        'Course Content';
    final isReadingPage =
        Uri.tryParse(url)?.path.contains('/mod/page/') ?? false;

    // Existing Moodle office/PDF resource iframe has first priority.
    final viewer =
        doc.querySelector('iframe#resourceobject, object#resourceobject') ??
        (isReadingPage
            ? null
            : doc.querySelector(
                'embed[type="application/pdf"], object[type="application/pdf"]',
              ));
    final viewerUrl = resolveUrl(
      viewer?.attributes['src'] ?? viewer?.attributes['data'],
      url,
    );
    if (viewerUrl != null && !_isYoutube(viewerUrl)) {
      final download = doc.querySelector(
        'a.btn-primary[download], a.btn[download]',
      );
      final name =
          doc.querySelector('.local-officeviewer-filename')?.text.trim() ??
          pageTitle;
      final lower = name.toLowerCase();
      return LmsExtractedContent(
        pageTitle: pageTitle,
        type: LmsItemType.singleDocument,
        originalUrl: url,
        items: [
          LmsContentItem(
            name: name,
            viewerUrl: viewerUrl,
            downloadUrl: resolveUrl(download?.attributes['href'], url),
            fileType: lower.endsWith('.pptx') || lower.endsWith('.ppt')
                ? 'pptx'
                : lower.endsWith('.docx') || lower.endsWith('.doc')
                ? 'docx'
                : 'pdf',
          ),
        ],
      );
    }

    // Retain folder selectors, but do not interpret ordinary reading links as
    // files just because Moodle wraps a lesson in a .box.generalbox.
    final folder =
        doc.querySelector('#folder_tree0, .filemanager') ??
        (isReadingPage ? null : doc.querySelector('.box.generalbox'));
    if (folder != null) {
      final items = <LmsContentItem>[];
      for (final node in folder.querySelectorAll('.fp-filename a, a.aalink')) {
        final href = resolveUrl(node.attributes['href'], url);
        final name = node.text.trim();
        if (href == null || name.isEmpty) continue;
        final icon =
            node.parent?.parent
                ?.querySelector('.fp-icon img, img')
                ?.attributes['src'] ??
            '';
        final lower = name.toLowerCase();
        final type =
            icon.contains('/f/document') ||
                lower.endsWith('.docx') ||
                lower.endsWith('.doc')
            ? 'docx'
            : icon.contains('/f/powerpoint') ||
                  lower.endsWith('.pptx') ||
                  lower.endsWith('.ppt')
            ? 'pptx'
            : icon.contains('/f/pdf') ||
                  isPdfUrl(href) ||
                  lower.endsWith('.pdf')
            ? 'pdf'
            : 'unknown';
        items.add(
          LmsContentItem(name: name, downloadUrl: href, fileType: type),
        );
      }
      if (items.isNotEmpty) {
        return LmsExtractedContent(
          pageTitle: pageTitle,
          type: LmsItemType.folderDirectory,
          items: items,
          originalUrl: url,
        );
      }
    }

    // Resource pages sometimes provide only a download/workaround link.
    // Mixed lessons retain PDF links in place instead of losing the lesson.
    final resourceLink = doc.querySelector(
      '.resourceworkaround a, a[download]',
    );
    final resourceUrl = resolveUrl(resourceLink?.attributes['href'], url);
    if (!isReadingPage &&
        resourceUrl != null &&
        (isPdfUrl(resourceUrl) ||
            (resourceLink?.attributes['download'] ?? '').toLowerCase().endsWith(
              '.pdf',
            ))) {
      return pdf(
        resourceUrl,
        title: resourceLink!.text.trim().isEmpty
            ? filenameFromUrl(resourceUrl)
            : resourceLink.text.trim(),
      );
    }

    final body =
        doc.querySelector('[role="main"] .generalbox') ??
        doc.querySelector('.generalbox') ??
        doc.querySelector('#region-main .content') ??
        doc.querySelector('[role="main"]') ??
        doc.body;
    final content = body?.clone(true);
    if (content != null) {
      content
          .querySelectorAll(
            'script:not([type="math/tex"]):not([type="math/tex; mode=display"]), nav, footer, .activity-navigation',
          )
          .forEach((e) => e.remove());
      // Standalone HTML resources can define their lesson CSS in <head>.
      for (final style in doc.head?.querySelectorAll('style') ?? <Element>[]) {
        content.nodes.insert(0, style.clone(true));
      }
    }
    return LmsExtractedContent(
      pageTitle: pageTitle,
      type: LmsItemType.pageContent,
      items: [],
      pageBodyHtml: content?.innerHtml ?? '',
      originalUrl: url,
    );
  }

  static bool _isYoutube(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase();
    return [
      'youtube.com',
      'www.youtube.com',
      'm.youtube.com',
      'youtu.be',
      'youtube-nocookie.com',
      'www.youtube-nocookie.com',
    ].contains(host);
  }
}
