import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/course_content.dart';
import 'cache_service.dart';

typedef ProgressCallback = void Function(int current, int total, String status);

class MaterialExportResult {
  final bool isZip;
  final File? zipFile;
  final Directory? folder;
  final int fileCount;
  final String path;
  final List<File> files;

  MaterialExportResult({
    required this.isZip,
    this.zipFile,
    this.folder,
    required this.fileCount,
    required this.path,
    this.files = const [],
  });
}

class _DownloadedFile {
  final String filename;
  final List<int> bytes;

  _DownloadedFile({required this.filename, required this.bytes});
}

class ZipExportService {
  final Dio dio;
  final CacheService cacheService;

  ZipExportService({
    required this.dio,
    required this.cacheService
  });

  /// Checks if downloaded bytes are an HTML text response instead of binary content.
  static bool isHtml(List<int> bytes) {
    if (bytes.length < 4) return false;

    // Binary magic numbers:
    // PK\x03\x04 (zip, pptx, docx, xlsx)
    if (bytes[0] == 0x50 && bytes[1] == 0x4B && bytes[2] == 0x03 && bytes[3] == 0x04) {
      return false;
    }
    // %PDF
    if (bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46) {
      return false;
    }
    // OLE Compound File (legacy .ppt, .doc, .xls): \xD0\xCF\x11\xE0
    if (bytes[0] == 0xD0 && bytes[1] == 0xCF && bytes[2] == 0x11 && bytes[3] == 0xE0) {
      return false;
    }

    // Inspect initial bytes as string
    final sampleLength = bytes.length < 500 ? bytes.length : 500;
    final sample = utf8.decode(bytes.sublist(0, sampleLength), allowMalformed: true).toLowerCase().trim();

    return sample.startsWith('<!doctype') ||
        sample.startsWith('<html') ||
        sample.contains('<head') ||
        sample.contains('<body') ||
        sample.contains('<div') ||
        sample.contains('<script');
  }

  /// Extracts clean filename from a URL path (e.g. .../Topic%202.1.1.pptx?forcedownload=1 -> Topic 2.1.1.pptx).
  static String extractFilenameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      if (segments.isNotEmpty) {
        final lastSegment = Uri.decodeComponent(segments.last);
        if (lastSegment.contains('.')) {
          return lastSegment;
        }
      }
    } catch (_) {}
    return '';
  }

  /// Resolves the proper file extension based on magic bytes and original name.
  static String resolveExtension(List<int> bytes, {required String originalName,}) {
    if (bytes.length >= 4) {
      // %PDF
      if (bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46) {
        return 'pdf';
      }
      // Legacy PPT: \xD0\xCF\x11\xE0
      if (bytes[0] == 0xD0 && bytes[1] == 0xCF && bytes[2] == 0x11 && bytes[3] == 0xE0) {
        if (originalName.toLowerCase().endsWith('.doc')) return 'doc';
        return 'ppt';
      }
      // OpenXML: PK\x03\x04
      if (bytes[0] == 0x50 && bytes[1] == 0x4B && bytes[2] == 0x03 && bytes[3] == 0x04) {
        if (originalName.toLowerCase().endsWith('.docx')) return 'docx';
        if (originalName.toLowerCase().endsWith('.xlsx')) return 'xlsx';
        return 'pptx';
      }
    }

    // Fallback to existing extension if available
    final dotIndex = originalName.lastIndexOf('.');
    if (dotIndex != -1 && dotIndex < originalName.length - 1) {
      return originalName.substring(dotIndex + 1).toLowerCase();
    }
    return 'bin';
  }

  /// Converts HTML page body into clean Markdown text.
  static String htmlToMarkdown(String html, {required String title}) {
    final doc = html_parser.parse(html);
    final mainContent = doc.querySelector('.generalbox, #region-main .content, role=main, .box.generalbox',) ?? doc.body;

    if (mainContent == null) {
      return '# $title\n';
    }

    // Remove script, style, and navigation tags
    mainContent.querySelectorAll('script, style, noscript, nav, header, footer').forEach((el) => el.remove());

    final buffer = StringBuffer();
    buffer.writeln('# $title\n');

    for (final node in mainContent.children) {
      final tag = node.localName?.toLowerCase();
      final text = node.text.trim();
      if (text.isEmpty) continue;

      if (tag == 'h1') {
        buffer.writeln('# $text\n');
      } else if (tag == 'h2') {
        buffer.writeln('## $text\n');
      } else if (tag == 'h3') {
        buffer.writeln('### $text\n');
      } else if (tag == 'ul' || tag == 'ol') {
        for (final li in node.querySelectorAll('li')) {
          final liText = li.text.trim();
          if (liText.isNotEmpty) {
            buffer.writeln('- $liText');
          }
        }
        buffer.writeln();
      } else if (tag == 'p') {
        buffer.writeln('$text\n');
      } else {
        buffer.writeln('$text\n');
      }
    }

    final result = buffer.toString().trim();
    return result.isNotEmpty ? result : '# $title\n\n${mainContent.text.trim()}';
  }

  /// Resolves the user-accessible destination folder (preferably Downloads on Android).
  Future<Directory> _getDestinationDirectory() async {
    if (Platform.isAndroid) {
      try {
        final status = await Permission.storage.status;
        if (!status.isGranted) {
          await Permission.storage.request();
        }
      } catch (_) {}

      // Public Downloads directory on Android devices
      final standardDownload = Directory('/storage/emulated/0/Download');
      if (await standardDownload.exists()) {
        return standardDownload;
      }

      final sdcardDownload = Directory('/sdcard/Download');
      if (await sdcardDownload.exists()) {
        return sdcardDownload;
      }
    }

    // Platform-provided Downloads directory (desktop / iOS / fallback)
    try {
      final downloads = await getDownloadsDirectory();
      if (downloads != null && await downloads.exists()) {
        return downloads;
      }
    } catch (_) {}

    // App-specific external storage directory on Android
    try {
      final ext = await getExternalStorageDirectory();
      if (ext != null && await ext.exists()) {
        return ext;
      }
    } catch (_) {}

    // Fallbacks
    try {
      return await getApplicationDocumentsDirectory();
    } catch (_) {
      return await getTemporaryDirectory();
    }
  }

  /// Resolves the dedicated CULMS destination folder (Downloads/CULMS on Android/Desktop).
  Future<Directory> _getCulmsDirectory() async {
    final baseDir = await _getDestinationDirectory();
    final culmsDir = Directory('${baseDir.path}/CULMS');
    if (!await culmsDir.exists()) {
      try {
        await culmsDir.create(recursive: true);
        return culmsDir;
      } catch (_) {
        return baseDir;
      }
    }
    return culmsDir;
  }

  /// Fetches bytes while manually following redirects and preserving the MoodleSession Cookie.
  Future<Response<List<int>>?> _fetchBytesWithCookie(
    String initialUrl,
    String moodleSession, {
    int maxRedirects = 5,
  }) async {
    String currentUrl = initialUrl;
    int redirects = 0;

    while (redirects < maxRedirects) {
      try {
        final uri = Uri.parse(currentUrl);
        final baseUrl = '${uri.scheme}://${uri.host}';

        final response = await dio.get<List<int>>(
          currentUrl,
          options: Options(
            responseType: ResponseType.bytes,
            followRedirects: false, // Handle redirects manually so Cookie is NEVER stripped!
            validateStatus: (s) => s != null && s < 500,
            headers: {
              'Cookie': 'MoodleSession=$moodleSession',
              'User-Agent': 'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36',
            },
          ),
        );

        final statusCode = response.statusCode ?? 200;
        if (statusCode >= 300 && statusCode < 400) {
          final location = response.headers['location']?.first;
          if (location != null && location.isNotEmpty) {
            String nextUrl = location;
            if (!nextUrl.startsWith('http://') && !nextUrl.startsWith('https://')) {
              nextUrl = nextUrl.startsWith('/') ? '$baseUrl$nextUrl' : '$baseUrl/$nextUrl';
            }

            if (nextUrl.contains('login/index.php')) {
              // Session expired or login required
              return response;
            }

            currentUrl = nextUrl;
            redirects++;
            continue;
          }
        }

        return response;
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// Resolves an activity item (reading page, Moodle office viewer, or binary file) into actual files.
  Future<List<_DownloadedFile>> _resolveAndDownloadItem(
    LmsContentItem item,
    String moodleSession,
    String? accountId,
    int cacheGeneration,
  ) async {
    if (item.downloadUrl == null || item.downloadUrl!.isEmpty) {
      return [];
    }

    // 1. Text reading page (mod/page or iconType == 'page')
    if (item.fileType == 'page' || item.downloadUrl!.contains('mod/page/view.php')) {
      final pageResp = await _fetchBytesWithCookie(item.downloadUrl!, moodleSession,);
      if (pageResp != null && pageResp.data != null && pageResp.data!.isNotEmpty) {
        final html = utf8.decode(pageResp.data!, allowMalformed: true);
        final md = htmlToMarkdown(html, title: item.name);
        final sanitizedTitle = item.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_',);
        return [_DownloadedFile(filename: '$sanitizedTitle.md', bytes: utf8.encode(md),),];
      }
    }

    // 2. Check local cache first (if not HTML)
    final cachedFile = await cacheService.getCachedFile(item.name,
      sourceUrl: item.downloadUrl,
      accountId: accountId,);
    if (cachedFile != null) {
      final cachedBytes = await cachedFile.readAsBytes();
      if (!isHtml(cachedBytes)) {
        return [_DownloadedFile(filename: item.name, bytes: cachedBytes)];
      }
    }

    // 3. Fetch the URL (following redirects with MoodleSession intact)
    final initialResp = await _fetchBytesWithCookie(item.downloadUrl!, moodleSession,);
    final initialBytes = initialResp?.data;
    if (initialBytes == null || initialBytes.isEmpty) {
      return [];
    }

    // If the response is ALREADY a valid binary file, return it directly!
    if (!isHtml(initialBytes)) {
      final ext = resolveExtension(initialBytes, originalName: item.name);
      String finalName = item.name;
      if (!finalName.toLowerCase().endsWith('.$ext')) {
        finalName = '${finalName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '')}.$ext';
      }
      await cacheService.saveFile(finalName, initialBytes,
        sourceUrl: item.downloadUrl,
        accountId: accountId,
        expectedGeneration: cacheGeneration,);
      return [_DownloadedFile(filename: finalName, bytes: initialBytes)];
    }

    // 4. Response IS HTML: parse Moodle page to extract real direct PPT or PDF stream
    final htmlString = utf8.decode(initialBytes, allowMalformed: true);
    final doc = html_parser.parse(htmlString);

    final uri = Uri.parse(item.downloadUrl!);
    final baseUrl = '${uri.scheme}://${uri.host}';

    String makeAbsolute(String relativeOrAbsolute) {
      if (relativeOrAbsolute.startsWith('http://') || relativeOrAbsolute.startsWith('https://')) {
        return relativeOrAbsolute;
      }
      if (relativeOrAbsolute.startsWith('/')) {
        return '$baseUrl$relativeOrAbsolute';
      }
      return '$baseUrl/$relativeOrAbsolute';
    }

    // Case A: Moodle Folder with multiple files (#folder_tree0 or .filemanager)
    final folderFiles = doc.querySelectorAll('#folder_tree0 .fp-filename a, .filemanager .fp-filename a, .box.generalbox .fp-filename a',);
    if (folderFiles.isNotEmpty) {
      final results = <_DownloadedFile>[];
      for (final node in folderFiles) {
        final href = node.attributes['href'];
        final text = node.text.trim();
        if (href != null && href.isNotEmpty && text.isNotEmpty) {
          final fileUrl = makeAbsolute(href);
          final fileResp = await _fetchBytesWithCookie(fileUrl, moodleSession);
          final bytes = fileResp?.data;
          if (bytes != null && !isHtml(bytes)) {
            final ext = resolveExtension(bytes, originalName: text);
            String name = text;
            if (!name.toLowerCase().endsWith('.$ext')) {
              name = '${name.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '')}.$ext';
            }
            results.add(_DownloadedFile(filename: name, bytes: bytes));
          }
        }
      }
      if (results.isNotEmpty) return results;
    }

    // Case B: Direct download link for PPT / PPTX / DOCX / PDF
    // Check download button or pluginfile links
    final downloadBtn = doc.querySelector('a.btn-primary[download], a.btn[download], a[download]',);
    String? directFileUrl = downloadBtn?.attributes['href'];

    if (directFileUrl == null || directFileUrl.isEmpty) {
      final pluginLinks = doc.querySelectorAll('a[href*="pluginfile.php"]');
      for (final link in pluginLinks) {
        final href = link.attributes['href'];
        if (href != null && href.isNotEmpty) {
          if (href.contains('.ppt') || href.contains('.pdf') || href.contains('.doc')) {
            directFileUrl = href;
            break;
          }
          directFileUrl ??= href;
        }
      }
    }

    if (directFileUrl == null || directFileUrl.isEmpty) {
      final workaroundLink = doc.querySelector('.resourceworkaround a, #resourceobject a, a.aalink[href*="pluginfile"]',);
      directFileUrl = workaroundLink?.attributes['href'];
    }

    if (directFileUrl != null && directFileUrl.isNotEmpty) {
      var absoluteDirectUrl = makeAbsolute(directFileUrl);
      if (absoluteDirectUrl.contains('pluginfile.php') && !absoluteDirectUrl.contains('forcedownload=1')) {
        final separator = absoluteDirectUrl.contains('?') ? '&' : '?';
        absoluteDirectUrl = '${absoluteDirectUrl}${separator}forcedownload=1';
      }

      final directResp = await _fetchBytesWithCookie(absoluteDirectUrl, moodleSession,);
      final directBytes = directResp?.data;
      if (directBytes != null && !isHtml(directBytes)) {
        // Prefer exact filename from download URL if available
        final urlName = extractFilenameFromUrl(absoluteDirectUrl);
        final officeName = doc.querySelector('.local-officeviewer-filename')?.text.trim();
        String resolvedName = urlName.isNotEmpty ? urlName : (officeName != null && officeName.isNotEmpty ? officeName : item.name);

        final ext = resolveExtension(directBytes, originalName: resolvedName);
        if (!resolvedName.toLowerCase().endsWith('.$ext')) {
          resolvedName = '${resolvedName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '')}.$ext';
        }

        await cacheService.saveFile(resolvedName, directBytes,
          sourceUrl: item.downloadUrl,
          accountId: accountId,
          expectedGeneration: cacheGeneration,);
        return [_DownloadedFile(filename: resolvedName, bytes: directBytes)];
      }
    }

    // Case C: OfficeViewer PDF stream fallback (when direct PPT download is blocked or unavailable)
    final viewerIframe = doc.querySelector('iframe#resourceobject, iframe[src*="officeviewer"]',);
    String? viewerUrl = viewerIframe?.attributes['src'];

    if (viewerUrl == null) {
      final objectViewer = doc.querySelector('object#resourceobject, object[data*="officeviewer"], object[data*="pdf"]',);
      viewerUrl = objectViewer?.attributes['data'];
    }

    if (viewerUrl != null && viewerUrl.isNotEmpty) {
      final absoluteViewerUrl = makeAbsolute(viewerUrl);
      final pdfResp = await _fetchBytesWithCookie(absoluteViewerUrl, moodleSession,);
      final pdfBytes = pdfResp?.data;

      if (pdfBytes != null && !isHtml(pdfBytes)) {
        final officeName = doc.querySelector('.local-officeviewer-filename')?.text.trim();
        String baseName = officeName != null && officeName.isNotEmpty ? officeName : item.name;

        // Change extension to .pdf since this is the converted PDF stream
        String pdfName = '${baseName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '')}.pdf';

        await cacheService.saveFile(pdfName, pdfBytes,
          sourceUrl: item.downloadUrl,
          accountId: accountId,
          expectedGeneration: cacheGeneration,);
        return [_DownloadedFile(filename: pdfName, bytes: pdfBytes)];
      }
    }

    // Case D: If it is a text document page, convert the HTML to clean Markdown
    final pageBody = doc.querySelector('.generalbox, #region-main .content, role=main',);
    if (pageBody != null) {
      final md = htmlToMarkdown(htmlString, title: item.name);
      final sanitizedTitle = item.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      return [_DownloadedFile(filename: '$sanitizedTitle.md', bytes: utf8.encode(md)),];
    }

    return [];
  }

  /// Exports unit materials either as a packed ZIP archive or directly as an uncompressed folder in Downloads/CULMS/*
  Future<MaterialExportResult> exportUnitMaterials({
    required String courseName,
    required String unitName,
    required List<LmsContentItem> items,
    required String moodleSession,
    String? accountId,
    MaterialExportFormat format = MaterialExportFormat.zip,
    ProgressCallback? onProgress,
    bool autoShare = true,
  }) async {
    final cacheGeneration = cacheService.generation;
    final validItems = items.where((item) => item.downloadUrl != null && item.downloadUrl!.isNotEmpty,).toList();
    if (validItems.isEmpty) {
      throw Exception('No downloadable files found in this unit.');
    }

    final sanitizedCourse = courseName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_',);
    final sanitizedUnit = unitName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final culmsDir = await _getCulmsDirectory();

    final total = validItems.length;
    final allDownloaded = <_DownloadedFile>[];

    for (int i = 0; i < total; i++) {
      final item = validItems[i];
      onProgress?.call(i + 1, total, 'Downloading ${item.name}...');

      final downloadedFiles = await _resolveAndDownloadItem(item, moodleSession,
        accountId,
        cacheGeneration,);
      allDownloaded.addAll(downloadedFiles);
    }

    if (allDownloaded.isEmpty) {
      throw Exception('Could not extract any binary files (PPT/PDF/DOCX/MD) from this unit.',);
    }

    if (format == MaterialExportFormat.folder) {
      // Export directly as an uncompressed folder inside Downloads/CULMS/Course_Unit
      onProgress?.call(total, total, 'Saving files into Downloads/CULMS/$sanitizedCourse/$sanitizedUnit...',);

      Directory targetFolder = Directory('${culmsDir.path}/$sanitizedCourse/$sanitizedUnit',);
      if (!await targetFolder.exists()) {
        try {
          await targetFolder.create(recursive: true);
        } catch (_) {
          targetFolder = Directory('${culmsDir.path}/${sanitizedCourse}_$sanitizedUnit',);
          await targetFolder.create(recursive: true);
        }
      }

      final savedFiles = <File>[];
      for (final df in allDownloaded) {
        final safeName = df.filename.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
        final file = File('${targetFolder.path}/$safeName');
        await file.writeAsBytes(df.bytes);
        savedFiles.add(file);
      }

      onProgress?.call(total, total, 'Files saved in Downloads/CULMS!');

      if (autoShare && savedFiles.isNotEmpty) {
        await SharePlus.instance.share(
          ShareParams(
            files: savedFiles.map((f) => XFile(f.path)).toList(),
            subject: '$courseName - $unitName Files',
            text: 'Exported course files for $unitName',
          ),
        );
      }

      return MaterialExportResult(
        isZip: false,
        folder: targetFolder,
        fileCount: savedFiles.length,
        path: targetFolder.path,
        files: savedFiles,
      );
    } else {
      // Export as packed ZIP archive in Downloads/CULMS/
      onProgress?.call(total, total, 'Compressing into ZIP archive...');

      final archive = Archive();
      for (final file in allDownloaded) {
        archive.addFile(ArchiveFile(
          file.filename,
          file.bytes.length,
          file.bytes),);
      }

      final zipEncoder = ZipEncoder();
      final zipBytes = zipEncoder.encode(archive);

      if (zipBytes.isEmpty) {
        throw Exception('Failed to generate ZIP archive.');
      }

      final zipFilename = '${sanitizedCourse}_$sanitizedUnit.zip';
      File? zipFile;

      try {
        final targetFile = File('${culmsDir.path}/$zipFilename');
        await targetFile.writeAsBytes(zipBytes);
        zipFile = targetFile;
      } catch (_) {
        try {
          final extDir = await getExternalStorageDirectory();
          if (extDir != null) {
            final fallbackDir = Directory('${extDir.path}/CULMS');
            if (!await fallbackDir.exists()) await fallbackDir.create(recursive: true);
            final fallbackFile = File('${fallbackDir.path}/$zipFilename');
            await fallbackFile.writeAsBytes(zipBytes);
            zipFile = fallbackFile;
          }
        } catch (_) {}
      }

      if (zipFile == null) {
        final tempDir = await getTemporaryDirectory();
        final fallbackFile = File('${tempDir.path}/$zipFilename');
        await fallbackFile.writeAsBytes(zipBytes);
        zipFile = fallbackFile;
      }

      onProgress?.call(total, total, 'ZIP archive saved in Downloads/CULMS!');

      if (autoShare) {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(zipFile.path)],
            subject: '$courseName - $unitName Files',
            text: 'Exported course files for $unitName',
          ),
        );
      }

      return MaterialExportResult(
        isZip: true,
        zipFile: zipFile,
        fileCount: allDownloaded.length,
        path: zipFile.path,
        files: [zipFile],
      );
    }
  }

  /// Legacy helper for backward compatibility
  Future<File?> exportUnitToZip({
    required String courseName,
    required String unitName,
    required List<LmsContentItem> items,
    required String moodleSession,
    String? accountId,
    ProgressCallback? onProgress,
    bool autoShare = true,
  }) async {
    final result = await exportUnitMaterials(
      courseName: courseName,
      unitName: unitName,
      items: items,
      moodleSession: moodleSession,
      accountId: accountId,
      format: MaterialExportFormat.zip,
      onProgress: onProgress,
      autoShare: autoShare,
    );
    return result.zipFile;
  }
}
