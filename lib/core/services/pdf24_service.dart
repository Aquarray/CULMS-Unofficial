import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'file_extension_service.dart';

/// Exception thrown when a PDF24 merge or pipeline operation fails.
class Pdf24Exception implements Exception {
  final String message;
  final dynamic details;

  Pdf24Exception(this.message, [this.details]);

  @override
  String toString() => details != null ? 'Pdf24Exception: $message ($details)' : 'Pdf24Exception: $message';
}

/// Specific exception when the user exceeds the rate limit (10 files per 2 hours).
class Pdf24RateLimitException extends Pdf24Exception {
  final int used;
  final int remaining;
  final int attempted;
  final Duration? timeUntilReset;

  Pdf24RateLimitException({
    required this.used,
    required this.remaining,
    required this.attempted,
    this.timeUntilReset,
  }) : super(
          'PDF24 rate limit reached: Maximum 10 files per 2 hours allowed to avoid service abuse. '
          '($used/10 used, $remaining remaining). Attempted to upload $attempted files.'
          '${timeUntilReset != null ? " Next slot available in ${timeUntilReset.inMinutes + 1} minutes." : ""}',
        );
}

/// Represents an individual file to be uploaded to PDF24.
class Pdf24UploadItem {
  final String name;
  final List<int> bytes;
  final String mimeType;

  Pdf24UploadItem({
    required this.name,
    required this.bytes,
    String? mimeType,
  }) : mimeType = mimeType ?? guessMimeType(name);

  static String guessMimeType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.pptx')) return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    if (lower.endsWith('.docx')) return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    if (lower.endsWith('.ppt')) return 'application/vnd.ms-powerpoint';
    if (lower.endsWith('.doc')) return 'application/msword';
    if (lower.endsWith('.txt')) return 'text/plain';
    if (lower.endsWith('.md')) return 'text/markdown';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    return 'application/octet-stream';
  }
}

/// Service implementing the PDF24 document merge pipeline with rate-limiting,
/// ZIP archive extraction, and filtering of unknown file types.
class Pdf24Service {
  final Dio _dio;
  final FileExtensionService _fileExtensionService;
  final String host;
  final SharedPreferences? _prefs;

  static const String defaultHost = 'filetools1.pdf24.org';
  static const String origin = 'https://tools.pdf24.org';
  static const String referer = 'https://tools.pdf24.org/';
  static const String _rateLimitPrefsKey = 'pdf24_upload_timestamps';
  static const int maxUploadsPerWindow = 10;
  static const Duration rateLimitWindow = Duration(hours: 2);

  String _sid;

  Pdf24Service({
    Dio? dio,
    FileExtensionService? fileExtensionService,
    String? host,
    String? initialSid,
    SharedPreferences? prefs,
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 40),
                receiveTimeout: const Duration(seconds: 120),
                headers: {
                  'Origin': origin,
                  'Referer': referer,
                  'User-Agent': 'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
                },
              ),
            ),
        _fileExtensionService = fileExtensionService ?? const FileExtensionService(),
        host = host ?? defaultHost,
        _sid = initialSid ?? _generateSid(),
        _prefs = prefs;

  String get activeSid => _sid;

  static String _generateSid() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rnd = Random();
    return List.generate(26, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  void _updateSidFromHeaders(Headers headers) {
    final cookies = headers['set-cookie'];
    if (cookies != null) {
      for (final cookie in cookies) {
        final match = RegExp(r'pdf24FtSid=([^;]+)').firstMatch(cookie);
        if (match != null) {
          _sid = match.group(1)!;
        }
      }
    }
  }

  // --- Rate Limiting (10 files per 2 hours) ---

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ?? await SharedPreferences.getInstance();
  }

  /// Returns recent upload timestamps within the rolling 2-hour window, pruning older ones.
  Future<List<int>> getRecentUploadTimestamps() async {
    final prefs = await _getPrefs();
    final raw = prefs.getStringList(_rateLimitPrefsKey) ?? [];
    final now = DateTime.now().millisecondsSinceEpoch;
    final cutoff = now - rateLimitWindow.inMilliseconds;

    final valid = <int>[];
    for (final item in raw) {
      final ts = int.tryParse(item);
      if (ts != null && ts > cutoff) {
        valid.add(ts);
      }
    }

    if (valid.length != raw.length) {
      await prefs.setStringList(
        _rateLimitPrefsKey,
        valid.map((e) => e.toString()).toList(),
      );
    }
    return valid;
  }

  /// Returns how many files have been uploaded in the current 2-hour window.
  Future<int> getRecentUploadCount() async {
    final timestamps = await getRecentUploadTimestamps();
    return timestamps.length;
  }

  /// Returns the number of files the user can still upload in the current window.
  Future<int> getRemainingQuota() async {
    final used = await getRecentUploadCount();
    return max(0, maxUploadsPerWindow - used);
  }

  /// If quota is exhausted or exceeded, returns the Duration until the earliest upload expires.
  Future<Duration?> getTimeUntilReset() async {
    final timestamps = await getRecentUploadTimestamps();
    if (timestamps.isEmpty) return null;
    timestamps.sort();
    final oldest = timestamps.first;
    final expiresAt = oldest + rateLimitWindow.inMilliseconds;
    final diff = expiresAt - DateTime.now().millisecondsSinceEpoch;
    return diff > 0 ? Duration(milliseconds: diff) : Duration.zero;
  }

  /// Checks if [count] files can be uploaded without exceeding the 10 files / 2 hr limit.
  /// Throws [Pdf24RateLimitException] if limit is exceeded.
  Future<void> checkRateLimit(int count) async {
    final used = await getRecentUploadCount();
    final remaining = max(0, maxUploadsPerWindow - used);
    if (used + count > maxUploadsPerWindow) {
      final timeUntilReset = await getTimeUntilReset();
      throw Pdf24RateLimitException(
        used: used,
        remaining: remaining,
        attempted: count,
        timeUntilReset: timeUntilReset,
      );
    }
  }

  /// Records [count] newly uploaded files into the rate limit store.
  Future<void> recordUploads(int count) async {
    if (count <= 0) return;
    final prefs = await _getPrefs();
    final timestamps = await getRecentUploadTimestamps();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < count; i++) {
      timestamps.add(now);
    }
    await prefs.setStringList(
      _rateLimitPrefsKey,
      timestamps.map((e) => e.toString()).toList(),
    );
  }

  // --- Filtering & ZIP Extraction ---

  /// Allowed extensions for PDF24 document conversion/merge.
  static const Set<String> allowedExtensions = {
    'pdf',
    'pptx',
    'docx',
    'ppt',
    'doc',
    'txt',
    'md',
    'png',
    'jpg',
    'jpeg',
  };

  /// Checks whether a file is a known document/presentation supported for merging.
  /// Rejects unknown binary files, HTML, executables, scripts, and generic bins.
  bool isKnownDocument(String filename, List<int> bytes) {
    if (bytes.isEmpty) return false;

    // Detect common signatures
    final type = _fileExtensionService.detectFileType(bytes, filenameHint: filename);
    if (type == CommonFileType.pdf ||
        type == CommonFileType.pptx ||
        type == CommonFileType.docx) {
      return true;
    }

    // Check extension against allowed list
    final dotIndex = filename.lastIndexOf('.');
    if (dotIndex != -1 && dotIndex < filename.length - 1) {
      final ext = filename.substring(dotIndex + 1).toLowerCase();
      if (allowedExtensions.contains(ext)) {
        // Double check not HTML
        if (bytes.length >= 4 &&
            bytes[0] == 0x3C && // '<'
            utf8.decode(bytes.take(20).toList(), allowMalformed: true).toLowerCase().contains('<html')) {
          return false;
        }
        return true;
      }
    }

    // OLE Compound (legacy ppt/doc)
    if (bytes.length >= 4 &&
        bytes[0] == 0xD0 &&
        bytes[1] == 0xCF &&
        bytes[2] == 0x11 &&
        bytes[3] == 0xE0) {
      return true;
    }

    return false;
  }

  /// Prepares and filters files for PDF24 upload:
  /// 1. Extracts contents of any ZIP archives.
  /// 2. Filters out unknown and unsupported files.
  /// 3. Normalizes filenames with correct extensions.
  List<Pdf24UploadItem> prepareFilesForUpload(List<({String filename, List<int> bytes})> rawFiles) {
    final result = <Pdf24UploadItem>[];

    for (final item in rawFiles) {
      final bytes = item.bytes;
      final name = item.filename;

      // Check if it's a ZIP archive
      if (_fileExtensionService.isZip(bytes) || name.toLowerCase().endsWith('.zip')) {
        try {
          final archive = ZipDecoder().decodeBytes(bytes, verify: false);
          for (final entry in archive.files) {
            if (!entry.isFile || entry.size == 0) continue;
            final innerName = entry.name.split('/').last.split('\\').last;
            if (innerName.startsWith('.') || innerName.startsWith('__MACOSX')) continue;

            final dynamic rawContent = entry.content;
            final List<int> innerBytes = rawContent is List<int>
                ? rawContent
                : (rawContent is Iterable<int> ? rawContent.toList() : <int>[]);
            if (innerBytes.isEmpty) continue;

            if (isKnownDocument(innerName, innerBytes)) {
              final corrected = _fileExtensionService.fixFilenameExtension(innerName, innerBytes);
              result.add(Pdf24UploadItem(name: corrected, bytes: innerBytes));
            }
          }
        } catch (_) {
          // If zip decoding fails, check if the raw file itself is a known document
          if (isKnownDocument(name, bytes)) {
            final corrected = _fileExtensionService.fixFilenameExtension(name, bytes);
            result.add(Pdf24UploadItem(name: corrected, bytes: bytes));
          }
        }
      } else {
        // Standalone file: only add if it's a known document
        if (isKnownDocument(name, bytes)) {
          final corrected = _fileExtensionService.fixFilenameExtension(name, bytes);
          result.add(Pdf24UploadItem(name: corrected, bytes: bytes));
        }
      }
    }

    return result;
  }

  // --- PDF24 API Endpoints ---

  /// Uploads a single file to the PDF24 worker.
  Future<Map<String, dynamic>> uploadFile(Pdf24UploadItem item) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        item.bytes,
        filename: item.name,
      ),
    });

    final response = await _dio.post<dynamic>(
      'https://$host/client.php?action=upload',
      data: formData,
      options: Options(
        headers: {
          'Accept': 'application/json',
          'Cookie': 'pdf24FtSid=$_sid',
        },
      ),
    );

    _updateSidFromHeaders(response.headers);

    final payload = response.data;
    if (payload is! List || payload.isEmpty) {
      throw Pdf24Exception('Upload response must be a single-element JSON array', payload);
    }
    final descriptor = payload[0];
    if (descriptor is! Map<String, dynamic>) {
      throw Pdf24Exception('Upload descriptor must be a JSON object', payload);
    }

    return descriptor;
  }

  /// Initiates the PDF24 joinPdf merge job.
  Future<String> startMerge(List<Map<String, dynamic>> fileDescriptors) async {
    final payload = {
      'files': fileDescriptors,
      'createBookmarks': false,
      'addBlankPages': 'none',
      'addCoverPages': false,
      'addTableOfContents': false,
      'language': 'en-US',
    };

    final response = await _dio.post<dynamic>(
      'https://$host/client.php?action=joinPdf&lng=en&srcPageId=mergePdf',
      data: json.encode(payload),
      options: Options(
        headers: {
          'Accept': '*/*',
          'Content-Type': 'application/json; charset=utf-8',
          'Cookie': 'pdf24FtSid=$_sid',
        },
      ),
    );

    _updateSidFromHeaders(response.headers);

    final result = response.data;
    if (result is! Map || result['jobId'] is! String) {
      throw Pdf24Exception('joinPdf response did not contain a valid string jobId', result);
    }
    return result['jobId'] as String;
  }

  /// Polls the status of the merge job until it completes or times out.
  Future<Map<String, dynamic>> waitForJob(
    String jobId, {
    Duration pollInterval = const Duration(milliseconds: 1500),
    Duration timeout = const Duration(seconds: 300),
    void Function(String status)? onPoll,
  }) async {
    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      final response = await _dio.post<dynamic>(
        'https://$host/client.php?action=getStatus&lng=en',
        data: 'jobId=${Uri.encodeQueryComponent(jobId)}',
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            'Accept': '*/*',
            'Cookie': 'pdf24FtSid=$_sid',
          },
        ),
      );

      _updateSidFromHeaders(response.headers);

      final payload = response.data;
      if (payload is! Map<String, dynamic>) {
        throw Pdf24Exception('getStatus response must be a JSON object', payload);
      }

      final status = payload['status'];
      onPoll?.call(status?.toString() ?? 'pending');

      if (status == 'pending') {
        await Future<void>.delayed(pollInterval);
        continue;
      }

      if (status != 'done') {
        throw Pdf24Exception('PDF24 job failed with status $status', payload);
      }

      final job = payload['job'];
      if (job is! Map<String, dynamic>) {
        throw Pdf24Exception('Completed getStatus response missing job object', payload);
      }

      return payload;
    }

    throw Pdf24Exception('Timed out waiting for PDF24 merge job to complete');
  }

  /// Generates a result access token for downloading the completed merged PDF.
  Future<String> createResultAccessToken(String jobId) async {
    final response = await _dio.post<dynamic>(
      'https://$host/client.php?action=createResultAccessToken&lng=en&srcPageId=jobMonitor',
      data: json.encode({'jobId': jobId}),
      options: Options(
        headers: {
          'Accept': '*/*',
          'Content-Type': 'application/json; charset=utf-8',
          'Cookie': 'pdf24FtSid=$_sid',
        },
      ),
    );

    _updateSidFromHeaders(response.headers);

    final result = response.data;
    if (result is! Map || result['token'] is! String) {
      throw Pdf24Exception('createResultAccessToken response did not contain a valid token', result);
    }
    return result['token'] as String;
  }

  /// Downloads the final merged PDF from PDF24.
  Future<List<int>> downloadResult(String jobId, Map<String, dynamic> jobOutput) async {
    final token = await createResultAccessToken(jobId);
    final displayName = jobOutput['out.name']?.toString() ?? 'merged.pdf';
    final encodedName = Uri.encodeComponent(displayName);
    final url = 'https://$host/client.php/$encodedName'
        '?mode=download&jobResultAccessToken=${Uri.encodeComponent(token)}'
        '&action=downloadJobResult&jobId=${Uri.encodeComponent(jobId)}';

    final response = await _dio.get<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        headers: {
          'Accept': 'application/pdf,*/*',
          'Cookie': 'pdf24FtSid=$_sid',
        },
      ),
    );

    _updateSidFromHeaders(response.headers);

    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      throw Pdf24Exception('Downloaded empty response from PDF24');
    }

    if (!_fileExtensionService.isPdf(bytes)) {
      throw Pdf24Exception('Downloaded response does not match PDF signature');
    }

    return bytes;
  }

  /// Full end-to-end merge pipeline:
  /// 1. Checks rate limit against [items.length].
  /// 2. Uploads items to PDF24.
  /// 3. Records uploads toward rate limiter.
  /// 4. Merges and polls status.
  /// 5. Downloads and saves the final PDF to [targetFile].
  Future<File> mergeAndDownload({
    required List<Pdf24UploadItem> items,
    required File targetFile,
    void Function(int current, int total, String status)? onProgress,
  }) async {
    if (items.isEmpty) {
      throw Pdf24Exception('No files provided for PDF24 merge');
    }

    // 1. Enforce 10 files per 2 hr rate limit
    await checkRateLimit(items.length);

    // 2. Upload each file to the pinned worker
    final descriptors = <Map<String, dynamic>>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      onProgress?.call(
        i,
        items.length,
        'Uploading ${item.name} (${i + 1}/${items.length}) to PDF24...',
      );
      final desc = await uploadFile(item);
      descriptors.add(desc);
    }

    // 3. Record successful uploads against rate limiter
    await recordUploads(items.length);

    // 4. Trigger merge
    onProgress?.call(items.length, items.length, 'Starting PDF24 merge job...');
    final jobId = await startMerge(descriptors);

    // 5. Poll for completion
    final statusPayload = await waitForJob(
      jobId,
      onPoll: (st) {
        onProgress?.call(items.length, items.length, 'Merging documents on PDF24 ($st)...');
      },
    );

    final job = statusPayload['job'] as Map<String, dynamic>;

    // 6. Download the result
    onProgress?.call(items.length, items.length, 'Downloading merged PDF...');
    final pdfBytes = await downloadResult(jobId, job);

    await targetFile.parent.create(recursive: true);
    await targetFile.writeAsBytes(pdfBytes);

    return targetFile;
  }
}
