import 'dart:convert';
import 'package:archive/archive.dart';

/// Common data types supported for signature/header analysis.
enum CommonFileType {
  pdf('pdf', 'application/pdf'),
  pptx('pptx', 'application/vnd.openxmlformats-officedocument.presentationml.presentation'),
  docx('docx', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'),
  zip('zip', 'application/zip'),
  unknown('', 'application/octet-stream');

  final String extension;
  final String mimeType;
  const CommonFileType(this.extension, this.mimeType);

  bool get isPdf => this == CommonFileType.pdf;
  bool get isPptx => this == CommonFileType.pptx;
  bool get isDocx => this == CommonFileType.docx;
  bool get isZip => this == CommonFileType.zip;
  bool get isKnown => this != CommonFileType.unknown;
}

/// Service positioned between file download and file saving to analyze
/// magic bytes / file signatures / headers and guarantee correct file extensions.
class FileExtensionService {
  const FileExtensionService();

  /// Analyzes file headers / magic signatures of [bytes] to detect the common file type.
  ///
  /// Supported types:
  /// - `pdf`: %PDF magic bytes (`0x25 0x50 0x44 0x46`)
  /// - `zip`: PK zip header (`0x50 0x4B 0x03 0x04`) without Office XML markers
  /// - `docx`: PK zip header containing Word processing XML structures (`word/`)
  /// - `pptx`: PK zip header containing PowerPoint presentation XML structures (`ppt/`)
  ///
  /// Returns [CommonFileType.unknown] if [bytes] does not match any of the common data types.
  CommonFileType detectFileType(List<int> bytes, {String? filenameHint}) {
    if (bytes.length < 4) {
      return CommonFileType.unknown;
    }

    // 1. PDF Signature Check: %PDF- (0x25 0x50 0x44 0x46)
    if (_isPdfHeader(bytes)) {
      return CommonFileType.pdf;
    }

    // 2. PK Zip Archive Check: (0x50 0x4B 0x03 0x04) or (0x50 0x4B 0x05 0x06) or (0x50 0x4B 0x07 0x08)
    if (_isPkZipHeader(bytes)) {
      return _disambiguateZipType(bytes, filenameHint: filenameHint);
    }

    return CommonFileType.unknown;
  }

  /// Resolves the file extension string (e.g. 'pdf', 'pptx', 'docx', 'zip')
  /// by analyzing [bytes] signatures.
  ///
  /// If the file matches a common type, returns its canonical extension.
  /// If [bytes] does not match a common type, falls back to [originalFilename]'s
  /// existing extension (if any) or [fallback].
  String resolveExtension(
    List<int> bytes, {
    String? originalFilename,
    String fallback = 'bin',
  }) {
    final detected = detectFileType(bytes, filenameHint: originalFilename);
    if (detected.isKnown) {
      return detected.extension;
    }

    // Legacy OLE2 Compound File Check (\xD0\xCF\x11\xE0) for legacy Office compatibility
    if (bytes.length >= 4 &&
        bytes[0] == 0xD0 &&
        bytes[1] == 0xCF &&
        bytes[2] == 0x11 &&
        bytes[3] == 0xE0) {
      if (originalFilename != null && originalFilename.toLowerCase().endsWith('.doc')) {
        return 'doc';
      }
      return 'ppt';
    }

    // Fallback to original filename extension if present
    if (originalFilename != null) {
      final dotIndex = originalFilename.lastIndexOf('.');
      if (dotIndex != -1 && dotIndex < originalFilename.length - 1) {
        final ext = originalFilename.substring(dotIndex + 1).toLowerCase();
        // Ignore generic web query extensions or server scripts
        if (ext != 'php' && ext != 'cgi' && ext != 'aspx' && ext != 'jsp') {
          return ext;
        }
      }
    }

    return fallback;
  }

  /// Core helper placed directly between download and saving:
  /// Updates [filename] with the correct file extension determined from [bytes].
  ///
  /// If [bytes] is detected as a common type (pdf, pptx, docx, zip), [filename]
  /// will have its extension replaced or appended with the detected extension.
  String fixFilenameExtension(
    String filename,
    List<int> bytes, {
    String fallback = 'bin',
  }) {
    final ext = resolveExtension(bytes, originalFilename: filename, fallback: fallback);
    final dotIndex = filename.lastIndexOf('.');

    if (dotIndex != -1 && dotIndex > 0) {
      final currentExt = filename.substring(dotIndex + 1).toLowerCase();
      if (currentExt == ext) {
        return filename;
      }
      // Replace existing extension with detected extension
      return '${filename.substring(0, dotIndex)}.$ext';
    }

    // No extension exists on filename -> append detected extension
    return '$filename.$ext';
  }

  /// Whether [bytes] matches one of the common data types (pdf, pptx, docx, zip).
  bool isCommonType(List<int> bytes) => detectFileType(bytes).isKnown;

  /// Checks if [bytes] matches PDF header signature.
  bool isPdf(List<int> bytes) => detectFileType(bytes) == CommonFileType.pdf;

  /// Checks if [bytes] matches PPTX header/structure.
  bool isPptx(List<int> bytes) => detectFileType(bytes) == CommonFileType.pptx;

  /// Checks if [bytes] matches DOCX header/structure.
  bool isDocx(List<int> bytes) => detectFileType(bytes) == CommonFileType.docx;

  /// Checks if [bytes] matches generic ZIP archive.
  bool isZip(List<int> bytes) => detectFileType(bytes) == CommonFileType.zip;

  // --- Internal Signature / Header Analyzers ---

  bool _isPdfHeader(List<int> bytes) {
    // Standard %PDF (0x25 0x50 0x44 0x46) at offset 0
    if (bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46) {
      return true;
    }

    // Some web servers or proxies emit leading BOM or comments within first 1024 bytes
    final checkLength = bytes.length < 1024 ? bytes.length : 1024;
    for (var i = 0; i <= checkLength - 4; i++) {
      if (bytes[i] == 0x25 &&
          bytes[i + 1] == 0x50 &&
          bytes[i + 2] == 0x44 &&
          bytes[i + 3] == 0x46) {
        return true;
      }
    }
    return false;
  }

  bool _isPkZipHeader(List<int> bytes) {
    if (bytes[0] != 0x50 || bytes[1] != 0x4B) return false;
    // Standard local file header PK\x03\x04
    if (bytes[2] == 0x03 && bytes[3] == 0x04) return true;
    // Empty zip PK\x05\x06
    if (bytes[2] == 0x05 && bytes[3] == 0x06) return true;
    // Spanned zip PK\x07\x08
    if (bytes[2] == 0x07 && bytes[3] == 0x08) return true;
    return false;
  }

  /// Distinguishes DOCX vs PPTX vs generic ZIP by inspecting internal archive structures.
  CommonFileType _disambiguateZipType(List<int> bytes, {String? filenameHint}) {
    // 1. Try decoding the ZIP directory headers using Archive package
    try {
      final archive = ZipDecoder().decodeBytes(bytes, verify: false);

      var hasWord = false;
      var hasPpt = false;

      for (final file in archive.files) {
        final path = file.name.toLowerCase();
        if (path.startsWith('word/') || path.contains('/word/')) {
          hasWord = true;
          break;
        }
        if (path.startsWith('ppt/') || path.contains('/ppt/')) {
          hasPpt = true;
          break;
        }
      }

      if (hasWord) return CommonFileType.docx;
      if (hasPpt) return CommonFileType.pptx;

      // Check [Content_Types].xml if present
      final contentTypesFile = archive.findFile('[Content_Types].xml');
      if (contentTypesFile != null) {
        final dynamic rawContent = contentTypesFile.content;
        String contentString = '';
        if (rawContent is List<int>) {
          contentString = utf8.decode(rawContent, allowMalformed: true).toLowerCase();
        } else if (rawContent != null) {
          contentString = rawContent.toString().toLowerCase();
        }

        if (contentString.contains('wordprocessingml')) return CommonFileType.docx;
        if (contentString.contains('presentationml')) return CommonFileType.pptx;
      }

      // If filename hint specifies docx or pptx, respect it when archive doesn't contradict it
      if (filenameHint != null) {
        final lower = filenameHint.toLowerCase();
        if (lower.endsWith('.pptx')) return CommonFileType.pptx;
        if (lower.endsWith('.docx')) return CommonFileType.docx;
        if (lower.endsWith('.zip')) return CommonFileType.zip;
      }

      // If no Office XML markers were found inside the valid zip, it's a generic zip archive
      return CommonFileType.zip;
    } catch (_) {
      // 2. Fallback: Fast raw byte scan for truncated or corrupted zip buffers
      return _disambiguateZipByByteScan(bytes, filenameHint: filenameHint);
    }
  }

  CommonFileType _disambiguateZipByByteScan(List<int> bytes, {String? filenameHint}) {
    // Scan up to the first 64KB or full length for uncompressed path signatures in headers
    final scanLength = bytes.length < 65536 ? bytes.length : 65536;
    final latin1String = latin1.decode(bytes.sublist(0, scanLength), allowInvalid: true).toLowerCase();

    if (latin1String.contains('word/') || latin1String.contains('wordprocessingml')) {
      return CommonFileType.docx;
    }
    if (latin1String.contains('ppt/') || latin1String.contains('presentationml')) {
      return CommonFileType.pptx;
    }

    // 3. Fallback to filename hint if provided
    if (filenameHint != null) {
      final lower = filenameHint.toLowerCase();
      if (lower.endsWith('.docx')) return CommonFileType.docx;
      if (lower.endsWith('.pptx')) return CommonFileType.pptx;
      if (lower.endsWith('.zip')) return CommonFileType.zip;
    }

    // Default for PK header is generic zip
    return CommonFileType.zip;
  }

  // --- Static Convenience Methods ---

  static const FileExtensionService instance = FileExtensionService();

  static CommonFileType detect(List<int> bytes, {String? filenameHint}) =>
      instance.detectFileType(bytes, filenameHint: filenameHint);

  static String resolve(
    List<int> bytes, {
    String? originalFilename,
    String fallback = 'bin',
  }) =>
      instance.resolveExtension(bytes, originalFilename: originalFilename, fallback: fallback);

  static String fixExtension(
    String filename,
    List<int> bytes, {
    String fallback = 'bin',
  }) =>
      instance.fixFilenameExtension(filename, bytes, fallback: fallback);
}
