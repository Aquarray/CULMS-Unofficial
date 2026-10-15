import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../../data/network/lms_content_parser.dart';

/// Builds a self-contained lesson document; Moodle navigation and scripts are
/// not needed to render teacher-authored HTML, CSS, media or mathematics.
class ReadingHtmlService {
  static String plainText(String html) {
    final doc = html_parser.parseFragment(html);
    doc.querySelectorAll('style, script, iframe').forEach((e) => e.remove());
    for (final element in doc.querySelectorAll(
      'p, div, h1, h2, h3, li, tr, br',
    )) {
      element.nodes.add(Text('\n'));
    }
    return (doc.text ?? '').replaceAll(RegExp(r'[ \t]+'), ' ').trim();
  }

  static Uri? youtubeEmbed(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !['https', 'http'].contains(uri.scheme)) return null;
    final host = uri.host.toLowerCase();
    if (![
      'youtube.com',
      'www.youtube.com',
      'm.youtube.com',
      'youtu.be',
      'youtube-nocookie.com',
      'www.youtube-nocookie.com',
    ].contains(host)) {
      return null;
    }
    String? id;
    if (host == 'youtu.be' && uri.pathSegments.isNotEmpty) {
      id = uri.pathSegments.first;
    } else if (uri.path == '/watch') {
      id = uri.queryParameters['v'];
    } else if (uri.pathSegments.length >= 2 &&
        ['embed', 'shorts', 'live'].contains(uri.pathSegments.first)) {
      id = uri.pathSegments[1];
    }
    if (id == null || !RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(id)) return null;
    final start = uri.queryParameters['start'] ?? uri.queryParameters['t'];
    return Uri.https('www.youtube-nocookie.com', '/embed/$id', {
      'rel': '0',
      if (start != null && int.tryParse(start) != null) 'start': start,
    });
  }

  static String prepareFragment(String html, {required String sourceUrl}) {
    final fragment = html_parser.parseFragment(html);
    // Saved Moodle DOM can already contain MathJax's generated CHTML. Its
    // hidden assistive MathML is the portable source; rendering the captured
    // wrappers again would duplicate equations or leave the new SVG hidden.
    for (final rendered
        in fragment.querySelectorAll('mjx-container, .MathJax').toList()) {
      final math = rendered.querySelector('math');
      if (math != null) rendered.replaceWith(math.clone(true));
    }
    // Retain legacy MathJax TeX script contents as equations, not executable JS.
    for (final script in fragment.querySelectorAll('script').toList()) {
      final type = script.attributes['type'] ?? '';
      if (type.startsWith('math/tex')) {
        final display = type.contains('mode=display');
        script.replaceWith(
          Element.tag('span')
            ..text = display
                ? r'\[' + script.text + r'\]'
                : r'\(' + script.text + r'\)',
        );
      } else {
        script.remove();
      }
    }
    fragment
        .querySelectorAll('base, meta, link, form, input, button, nav, footer')
        .forEach((e) => e.remove());
    for (final element in fragment.querySelectorAll('*')) {
      element.attributes.removeWhere(
        (name, _) =>
            name.toString().toLowerCase().startsWith('on') ||
            ['srcdoc', 'formaction'].contains(name),
      );
      for (final attribute in ['href', 'src', 'poster', 'data']) {
        final value = element.attributes[attribute];
        if (value == null || (attribute == 'href' && value.startsWith('#'))) {
          continue;
        }
        if (attribute == 'src' &&
            RegExp(
              r'^data:image/(png|jpeg|gif|webp);base64,',
              caseSensitive: false,
            ).hasMatch(value)) {
          continue;
        }
        final absolute = LmsContentParser.resolveUrl(value, sourceUrl);
        if (absolute == null) {
          element.attributes.remove(attribute);
        } else {
          element.attributes[attribute] = absolute;
        }
      }
      // Lazy-loaded images otherwise may never initialize without Moodle JS.
      if (element.localName == 'img' && element.attributes['src'] == null) {
        final src = LmsContentParser.resolveUrl(
          element.attributes['data-src'],
          sourceUrl,
        );
        if (src != null) element.attributes['src'] = src;
      }
    }

    // Turn video iframes and plain YouTube links into responsive inline players,
    // always leaving an ordinary link as a fallback when embedding is restricted.
    for (final element
        in fragment.querySelectorAll('iframe, embed, object').toList()) {
      final url = element.attributes['src'] ?? element.attributes['data'];
      if (url == null) {
        element.remove();
        continue;
      }
      final video = youtubeEmbed(url);
      if (video != null) {
        element.replaceWith(
          _video(video, element.attributes['title'] ?? 'YouTube video'),
        );
      } else {
        element.replaceWith(
          _attachment(
            url,
            element.attributes['title'] ??
                (LmsContentParser.isPdfUrl(url)
                    ? 'Open PDF'
                    : 'Open embedded material'),
          ),
        );
      }
    }
    for (final link in fragment.querySelectorAll('a[href]').toList()) {
      final url = link.attributes['href']!;
      if (link.classes.contains('culms-video-link')) continue;
      final video = youtubeEmbed(url);
      if (video != null) {
        link.replaceWith(
          _video(
            video,
            link.text.trim().isEmpty ? 'YouTube video' : link.text.trim(),
          ),
        );
      }
    }
    return fragment.outerHtml;
  }

  static Element _video(Uri embed, String title) {
    final wrapper = Element.tag('div')..classes.add('culms-video');
    wrapper.children.add(
      Element.tag('iframe')
        ..attributes.addAll({
          'src': embed.toString(),
          'title': title,
          'loading': 'lazy',
          'allow': 'accelerometer; encrypted-media; gyroscope; picture-in-picture; fullscreen',
          'allowfullscreen': '',
          'referrerpolicy': 'strict-origin-when-cross-origin',
        }),
    );
    wrapper.children.add(
      Element.tag('a')
        ..classes.add('culms-video-link')
        ..attributes['href'] = Uri.https('www.youtube.com', '/watch', {
          'v': embed.pathSegments.last,
        }).toString()
        ..text = '$title — Open on YouTube',
    );
    return wrapper;
  }

  static Element _attachment(String url, String title) => Element.tag('a')
    ..classes.add('culms-attachment')
    ..attributes['href'] = url
    ..text = title;

  static String buildDocument({
    required String html,
    required String sourceUrl,
    required String backgroundColor,
    required String textColor,
    required String accentColor,
    required String fontFamily,
    required double fontScale,
    required double lineHeight,
    required String mathJaxScript,
  }) {
    final body = prepareFragment(html, sourceUrl: sourceUrl);
    // All interpolated values except body/script are generated by the app.
    final font = const HtmlEscape(HtmlEscapeMode.element).convert(fontFamily);
    final base = const HtmlEscape(HtmlEscapeMode.attribute).convert(sourceUrl);
    final mathConfig = json.encode({
      'tex': {
        'inlineMath': [
          [r'\(', r'\)'],
          [r'$', r'$'],
        ],
        'displayMath': [
          [r'\[', r'\]'],
          [r'$$', r'$$'],
        ],
        'processEscapes': true,
        'packages': [
          'base',
          'ams',
          'newcommand',
          'noundefined',
          'configmacros',
        ],
      },
      'svg': {'fontCache': 'local'},
      'options': {
        'enableMenu': false,
        'skipHtmlTags': [
          'script',
          'noscript',
          'style',
          'textarea',
          'pre',
          'code',
        ],
      },
    });
    final script = mathJaxScript.replaceAll(
      RegExp('</script', caseSensitive: false),
      r'<\/script',
    );
    return '''<!doctype html><html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<base href="$base">
<style id="culms-reader-theme">
html { background:$backgroundColor; color:$textColor; }
body { margin:0; padding:20px 24px; font-family:$font, sans-serif; font-size:${16 * fontScale}px; line-height:$lineHeight; overflow-wrap:anywhere; }
a { color:$accentColor; } img, video, svg { max-width:100%; }
img { height:auto; } table { max-width:100%; border-collapse:collapse; }
th,td { border:1px solid #8886; padding:8px; } pre { overflow-x:auto; }
.culms-video { margin:16px 0; width:100%; height:auto!important; padding:0!important; position:static!important; }
#culms-lesson .culms-video>iframe { display:block; position:static!important; width:100%!important; height:auto!important; aspect-ratio:16/9; border:0; }
.culms-video-link { display:block; font-size:0.85em; padding:8px 0; }
.culms-attachment { display:block; padding:12px; border:1px solid #8886; border-radius:8px; margin:12px 0; }
/* Legacy Moodle wrappers must not collapse our responsive inline player. */
#culms-lesson .mediaplugin:has(.culms-video) { position:static!important; height:auto!important; padding:0!important; overflow:visible!important; }
mjx-container[display="true"] { overflow-x:auto; overflow-y:hidden; padding:4px 0; max-width:100%; }
</style></head><body><main id="culms-lesson">$body</main>
<script>window.MathJax=$mathConfig;</script>
<script>$script</script>
<script>
function culmsProgress() {
  var max = document.documentElement.scrollHeight - innerHeight;
  if (window.ReadingProgress) ReadingProgress.postMessage(String(max > 0 ? scrollY / max : 1));
}
addEventListener('scroll',culmsProgress,{passive:true});
addEventListener('load',culmsProgress);
if (window.MathJax && MathJax.startup) MathJax.startup.promise.then(culmsProgress);
</script></body></html>''';
  }
}
