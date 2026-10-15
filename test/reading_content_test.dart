import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:cuims_unofficial2/core/services/cache_service.dart';
import 'package:cuims_unofficial2/core/services/reading_html_service.dart';
import 'package:cuims_unofficial2/data/models/auth_state.dart';
import 'package:cuims_unofficial2/data/models/course_content.dart';
import 'package:cuims_unofficial2/data/network/lms_api_client.dart';
import 'package:cuims_unofficial2/data/network/lms_content_parser.dart';

const pageUrl = 'https://lms.cuchd.in/mod/page/view.php?id=42';

void main() {
  group('Material extraction regression', () {
    test(
      'Moodle resource iframe still wins over folder and reading fallbacks',
      () {
        final content = LmsContentParser.parseHtml('''
        <h1>Notes</h1><iframe id="resourceobject" src="/local/officeviewer/pdf.php?id=1"></iframe>
        <span class="local-officeviewer-filename">Slides.pptx</span>
        <a class="btn-primary" download href="/pluginfile.php/slides.pptx">Download</a>
        <div id="folder_tree0"><span class="fp-filename"><a href="other.pdf">other</a></span></div>
      ''', url: pageUrl);
        expect(content.type, LmsItemType.singleDocument);
        expect(content.items.single.fileType, 'pptx');
        expect(
          content.items.single.viewerUrl,
          'https://lms.cuchd.in/local/officeviewer/pdf.php?id=1',
        );
        expect(
          content.items.single.downloadUrl,
          'https://lms.cuchd.in/pluginfile.php/slides.pptx',
        );
      },
    );

    test('folder filenames/types/URLs remain available', () {
      final content = LmsContentParser.parseHtml('''
        <h1>Folder</h1><div id="folder_tree0">
        <span class="fp-filename"><a href="/files/notes.PDF?download=1">notes.PDF</a></span>
        <span class="fp-filename"><a href="/files/slides.pptx">slides.pptx</a></span></div>
      ''', url: 'https://lms.cuchd.in/mod/folder/view.php?id=1');
      expect(content.type, LmsItemType.folderDirectory);
      expect(content.items.map((e) => e.fileType), ['pdf', 'pptx']);
      expect(
        content.items.first.downloadUrl,
        'https://lms.cuchd.in/files/notes.PDF?download=1',
      );
    });

    test(
      'old generalbox folder fallback is retained for non-page resources',
      () {
        final content = LmsContentParser.parseHtml(
          '<div class="box generalbox"><a class="aalink" href="/notes.pdf">notes.pdf</a></div>',
          url: 'https://lms.cuchd.in/mod/folder/view.php?id=1',
        );
        expect(content.type, LmsItemType.folderDirectory);
      },
    );

    test('reading links do not misclassify an HTML lesson as a folder', () {
      final content = LmsContentParser.parseHtml(
        '<div class="box generalbox"><p>Lesson text</p><a class="aalink" href="/notes.pdf">notes.pdf</a></div>',
        url: pageUrl,
      );
      expect(content.type, LmsItemType.pageContent);
      expect(content.pageBodyHtml, contains('Lesson text'));
      expect(content.pageBodyHtml, contains('notes.pdf'));
    });

    test(
      'sample-derived lesson preserves CSS, MathML, tables, images, YouTube',
      () {
        final html = File('test/fixtures/rich_reading_page.html')
            .readAsStringSync();
        final content = LmsContentParser.parseHtml(html, url: pageUrl);
        expect(content.type, LmsItemType.pageContent);
        final body = html_parser.parseFragment(content.pageBodyHtml!);
        expect(body.querySelector('style')!.text, contains('.ailb-lp'));
        expect(body.querySelectorAll('math'), hasLength(3));
        expect(body.querySelectorAll('iframe'), hasLength(2));
        expect(body.querySelector('table'), isNotNull);
        expect(body.querySelector('img'), isNotNull);
        expect(content.pageBodyHtml, isNot(contains('Portal navigation')));
        expect(content.pageBodyHtml, isNot(contains('Portal footer')));
      },
    );

    test('role main and standalone HTML fallback still work', () {
      final role = LmsContentParser.parseHtml(
        '<nav>Menu</nav><div role="main"><p>Reading</p></div>',
        url: pageUrl,
      );
      expect(role.pageBodyHtml, contains('Reading'));
      expect(role.pageBodyHtml, isNot(contains('Menu')));
      final standalone = LmsContentParser.parseHtml(
        '<html><head><style>.topic{color:red}</style></head><body><p class="topic">Plain lesson</p></body></html>',
        url: pageUrl,
      );
      expect(standalone.pageBodyHtml, contains('.topic{color:red}'));
    });

    test('PDF object/embed resources open as documents', () {
      for (final element in [
        '<object type="application/pdf" data="/notes.pdf"></object>',
        '<embed type="application/pdf" src="/notes.pdf">',
      ]) {
        final content = LmsContentParser.parseHtml(
          element,
          url: 'https://lms.cuchd.in/mod/resource/view.php?id=1',
        );
        expect(content.type, LmsItemType.singleDocument);
        expect(
          content.items.single.viewerUrl,
          'https://lms.cuchd.in/notes.pdf',
        );
      }
    });

    test('PDF download-only resource opens as a document', () {
      final content = LmsContentParser.parseHtml(
        '<div class="resourceworkaround"><a href="/notes.PDF?forcedownload=1">Notes</a></div>',
        url: 'https://lms.cuchd.in/mod/resource/view.php?id=1',
      );
      expect(content.type, LmsItemType.singleDocument);
      expect(content.items.single.fileType, 'pdf');
    });

    test('PDF URLs accept query parameters and reject HTML names', () {
      expect(
        LmsContentParser.isPdfUrl(
          'https://lms.cuchd.in/notes.PDF?download=1#page=2',
        ),
        isTrue,
      );
      expect(
        LmsContentParser.isPdfUrl('https://lms.cuchd.in/page?title=file.pdf'),
        isFalse,
      );
    });
  });

  test('PDF embeds inside a lesson retain the surrounding reading content', () {
    final content = LmsContentParser.parseHtml(
      '<div class="generalbox"><h2>Read first</h2><p>Important explanation</p><embed type="application/pdf" src="/notes.pdf"></div>',
      url: pageUrl,
    );
    expect(content.type, LmsItemType.pageContent);
    expect(content.pageBodyHtml, contains('Important explanation'));
  });

  test('captured MathJax CHTML is replaced by its portable MathML source', () {
    final html = ReadingHtmlService.prepareFragment(
      '<mjx-container jax="CHTML"><mjx-math>Old rendering</mjx-math><mjx-assistive-mml><math><mfrac><mi>x</mi><mn>2</mn></mfrac></math></mjx-assistive-mml></mjx-container>',
      sourceUrl: pageUrl,
    );
    final doc = html_parser.parseFragment(html);
    expect(doc.querySelectorAll('math'), hasLength(1));
    expect(doc.querySelector('mjx-container'), isNull);
    expect(doc.querySelector('mjx-assistive-mml'), isNull);
    expect(html, isNot(contains('Old rendering')));
  });

  group('Rich reader document', () {
    test(
      'YouTube watch, short, embed and mobile URLs become inline players',
      () {
        for (final url in [
          'https://youtu.be/QA54KGOS9fA',
          'https://www.youtube.com/watch?v=QA54KGOS9fA',
          'https://m.youtube.com/shorts/QA54KGOS9fA',
          'https://www.youtube.com/embed/QA54KGOS9fA',
        ]) {
          final html = ReadingHtmlService.prepareFragment(
            '<a href="$url">Lecture</a>',
            sourceUrl: pageUrl,
          );
          final doc = html_parser.parseFragment(html);
          expect(
            doc.querySelector('iframe')!.attributes['src'],
            contains('/embed/QA54KGOS9fA'),
          );
          expect(doc.querySelector('a')!.text, contains('Open on YouTube'));
        }
        expect(
          ReadingHtmlService.youtubeEmbed(
            'https://youtube.com.evil.test/watch?v=QA54KGOS9fA',
          ),
          isNull,
        );
      },
    );

    test('embedded player has a responsive wrapper and fallback link', () {
      final html = ReadingHtmlService.prepareFragment(
        '<span class="mediaplugin"><iframe src="https://www.youtube.com/embed/QA54KGOS9fA" title="Lecture"></iframe></span>',
        sourceUrl: pageUrl,
      );
      final doc = html_parser.parseFragment(html);
      expect(doc.querySelectorAll('iframe'), hasLength(1));
      expect(doc.querySelector('.culms-video'), isNotNull);
      expect(
        doc.querySelector('a')!.attributes['href'],
        contains('watch?v=QA54KGOS9fA'),
      );
    });

    test('retains CSS/MathML and resolves image/PDF links', () {
      final html = ReadingHtmlService.prepareFragment(
        '<style>.lesson{color:red}</style><p style="font-weight:700">Topic</p><math><mfrac><mi>x</mi><mn>2</mn></mfrac></math><img src="/files/image.png"><a href="/files/notes.pdf">PDF</a>',
        sourceUrl: pageUrl,
      );
      final doc = html_parser.parseFragment(html);
      expect(doc.querySelector('style')!.text, contains('color:red'));
      expect(doc.querySelector('p')!.attributes['style'], 'font-weight:700');
      expect(doc.querySelector('mfrac'), isNotNull);
      expect(
        doc.querySelector('img')!.attributes['src'],
        'https://lms.cuchd.in/files/image.png',
      );
      expect(
        doc.querySelector('a')!.attributes['href'],
        'https://lms.cuchd.in/files/notes.pdf',
      );
    });

    test(
      'lesson scripts are removed while legacy TeX script equations survive',
      () {
        final html = ReadingHtmlService.prepareFragment(
          r'<script>alert(1)</script><p onclick="alert(2)">Text</p><a href="javascript:alert(3)">bad</a><script type="math/tex">\frac{a}{b}</script><script type="math/tex; mode=display">x^2</script>',
          sourceUrl: pageUrl,
        );
        expect(html, isNot(contains('<script')));
        expect(html, isNot(contains('onclick')));
        expect(html, isNot(contains('javascript:')));
        expect(html, contains(r'\(\frac{a}{b}\)'));
        expect(html, contains(r'\[x^2\]'));
      },
    );

    test('speech/read-time text excludes CSS and scripts', () {
      final text = ReadingHtmlService.plainText(
        '<style>.hidden{color:red}</style><script>bad()</script><h2>Title</h2><p>Study material</p>',
      );
      expect(text, contains('Title'));
      expect(text, contains('Study material'));
      expect(text, isNot(contains('color:red')));
      expect(text, isNot(contains('bad()')));
    });

    test('PDF embeds become clickable native-reader attachments', () {
      final html = ReadingHtmlService.prepareFragment(
        '<iframe src="/file.pdf"></iframe>',
        sourceUrl: pageUrl,
      );
      final doc = html_parser.parseFragment(html);
      expect(doc.querySelector('iframe'), isNull);
      expect(
        doc.querySelector('.culms-attachment')!.attributes['href'],
        'https://lms.cuchd.in/file.pdf',
      );
    });

    test('document configures bundled TeX/MathML and responsive content', () {
      final doc = ReadingHtmlService.buildDocument(
        html: r'<p>\(x^2\)</p><math><mi>x</mi></math>',
        sourceUrl: pageUrl,
        backgroundColor: '#fff',
        textColor: '#111',
        accentColor: '#a22',
        fontFamily: 'Inter',
        fontScale: 1.2,
        lineHeight: 1.6,
        mathJaxScript: 'window.rendererBundled=true;',
      );
      expect(doc, contains('window.rendererBundled=true'));
      expect(doc, contains('"inlineMath"'));
      expect(doc, contains('"displayMath"'));
      expect(doc, contains('"enableMenu":false'));
      expect(doc, contains('19.2px'));
      expect(doc, contains('aspect-ratio:16/9'));
      expect(doc, isNot(contains('cdn.jsdelivr.net')));
    });
  });

  group('PDF network responses', () {
    late Directory root;
    late CacheService cache;
    late AuthSession session;
    setUp(() async {
      root = await Directory.systemTemp.createTemp('culms_reading_');
      cache = CacheService(
        directory: () async => root,
        temporaryDirectory: () async => root,
      );
      session = AuthSession(
        uid: 'student',
        moodleSession: 'cookie',
        sesskey: 'key',
        authenticatedAt: DateTime.now(),
      );
    });
    tearDown(() async => root.delete(recursive: true));

    test(
      'direct PDF URL routes without trying to parse a binary as HTML',
      () async {
        final dio = Dio();
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (_, _) => fail(
              'Direct URL should route to PDF viewer without fetching HTML',
            ),
          ),
        );
        final content = await LmsApiClient(dio: dio, cacheService: cache)
            .extractContent(
              url: 'https://lms.cuchd.in/file.pdf?download=1',
              session: session,
            );
        expect(content.type, LmsItemType.singleDocument);
      },
    );

    test(
      'extensionless PDF MIME response is cached for the native viewer',
      () async {
        final dio = Dio();
        final bytes = utf8.encode('%PDF-1.7\nfixture');
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) => handler.resolve(
              Response(
                requestOptions: options,
                data: bytes,
                statusCode: 200,
                headers: Headers.fromMap({
                  'content-type': ['application/pdf'],
                }),
              ),
            ),
          ),
        );
        final url = 'https://lms.cuchd.in/pluginfile.php/42/download';
        final content = await LmsApiClient(
          dio: dio,
          cacheService: cache,
        ).extractContent(url: url, session: session);
        expect(content.type, LmsItemType.singleDocument);
        final file = await cache.getCachedFile(
          'Document.pdf',
          sourceUrl: url,
          accountId: session.uid,
        );
        expect(await file!.readAsBytes(), bytes);
      },
    );

    test('PDF signature works with generic binary MIME', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.resolve(
            Response(
              requestOptions: options,
              data: utf8.encode('%PDF-1.4\nfixture'),
              statusCode: 200,
              headers: Headers.fromMap({
                'content-type': ['application/octet-stream'],
              }),
            ),
          ),
        ),
      );
      final content = await LmsApiClient(dio: dio, cacheService: cache)
          .extractContent(
            url: 'https://lms.cuchd.in/download?id=1',
            session: session,
          );
      expect(content.type, LmsItemType.singleDocument);
    });
  });
}
