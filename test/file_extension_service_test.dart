import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cuims_unofficial2/core/services/file_extension_service.dart';

void main() {
  group('FileExtensionService Tests', () {
    const service = FileExtensionService();

    List<int> createZipWithFiles(Map<String, String> files) {
      final archive = Archive();
      files.forEach((name, content) {
        final bytes = utf8.encode(content);
        archive.addFile(ArchiveFile(name, bytes.length, bytes));
      });
      return ZipEncoder().encode(archive);
    }

    test('Identifies PDF signatures and headers correctly', () {
      final standardPdf = utf8.encode('%PDF-1.7\n1 0 obj\n<<>>\nendobj');
      final bomPdf = [0xEF, 0xBB, 0xBF, ...utf8.encode('%PDF-1.4')];

      expect(service.detectFileType(standardPdf), CommonFileType.pdf);
      expect(service.detectFileType(bomPdf), CommonFileType.pdf);
      expect(service.isPdf(standardPdf), true);
      expect(service.isCommonType(standardPdf), true);
      expect(service.resolveExtension(standardPdf), 'pdf');
      expect(service.fixFilenameExtension('Lecture Notes', standardPdf), 'Lecture Notes.pdf');
      expect(service.fixFilenameExtension('Wrong.pptx', standardPdf), 'Wrong.pdf');
    });

    test('Identifies DOCX packages from internal word/ structures', () {
      final docxBytes = createZipWithFiles({
        'word/document.xml': '<w:document><w:body><w:p/></w:body></w:document>',
        '[Content_Types].xml': '<Types><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>',
      });

      expect(service.detectFileType(docxBytes), CommonFileType.docx);
      expect(service.isDocx(docxBytes), true);
      expect(service.isCommonType(docxBytes), true);
      expect(service.resolveExtension(docxBytes), 'docx');
      expect(service.fixFilenameExtension('Assignment_1', docxBytes), 'Assignment_1.docx');
      expect(service.fixFilenameExtension('download.php', docxBytes), 'download.docx');
    });

    test('Identifies PPTX packages from internal ppt/ structures', () {
      final pptxBytes = createZipWithFiles({
        'ppt/presentation.xml': '<p:presentation/>',
        '[Content_Types].xml': '<Types><Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/></Types>',
      });

      expect(service.detectFileType(pptxBytes), CommonFileType.pptx);
      expect(service.isPptx(pptxBytes), true);
      expect(service.isCommonType(pptxBytes), true);
      expect(service.resolveExtension(pptxBytes), 'pptx');
      expect(service.fixFilenameExtension('Unit_2_Slides', pptxBytes), 'Unit_2_Slides.pptx');
      expect(service.fixFilenameExtension('view.bin', pptxBytes), 'view.pptx');
    });

    test('Identifies generic ZIP archives when Office XML markers are absent', () {
      final zipBytes = createZipWithFiles({
        'code/main.py': 'print("Hello World")',
        'data/readme.txt': 'Project archive',
      });

      expect(service.detectFileType(zipBytes), CommonFileType.zip);
      expect(service.isZip(zipBytes), true);
      expect(service.isCommonType(zipBytes), true);
      expect(service.resolveExtension(zipBytes), 'zip');
      expect(service.fixFilenameExtension('SourceCode', zipBytes), 'SourceCode.zip');
    });

    test('Empty and truncated ZIP buffers are handled safely', () {
      // Empty zip central directory header (PK\x05\x06)
      final emptyZip = [0x50, 0x4B, 0x05, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00];
      expect(service.detectFileType(emptyZip), CommonFileType.zip);

      // Truncated raw bytes with hint
      final truncatedPptx = [0x50, 0x4B, 0x03, 0x04, 0x14, 0x00, 0x06, 0x00];
      expect(service.detectFileType(truncatedPptx, filenameHint: 'lecture.pptx'), CommonFileType.pptx);
      expect(service.detectFileType(truncatedPptx, filenameHint: 'notes.docx'), CommonFileType.docx);
      expect(service.detectFileType(truncatedPptx, filenameHint: 'archive.zip'), CommonFileType.zip);
      expect(service.detectFileType(truncatedPptx), CommonFileType.zip);
    });

    test('Correctly rejects non-common types and unknown signatures', () {
      final htmlBytes = utf8.encode('<!DOCTYPE html><html><body>Error</body></html>');
      final randomBinary = [0x01, 0x02, 0x03, 0x04, 0x05];
      final tinyBytes = [0x25, 0x50];

      expect(service.detectFileType(htmlBytes), CommonFileType.unknown);
      expect(service.detectFileType(randomBinary), CommonFileType.unknown);
      expect(service.detectFileType(tinyBytes), CommonFileType.unknown);

      expect(service.isCommonType(htmlBytes), false);
      expect(service.isCommonType(randomBinary), false);

      expect(service.resolveExtension(htmlBytes, originalFilename: 'page.html'), 'html');
      expect(service.resolveExtension(randomBinary, fallback: 'dat'), 'dat');
    });

    test('Supports legacy OLE2 Compound File (ppt/doc) fallback', () {
      final oleBytes = [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1];
      expect(service.resolveExtension(oleBytes, originalFilename: 'Old.doc'), 'doc');
      expect(service.resolveExtension(oleBytes, originalFilename: 'Old.ppt'), 'ppt');
      expect(service.resolveExtension(oleBytes), 'ppt');
    });

    test('fixFilenameExtension seamlessly fixes mismatched extensions', () {
      final pdfBytes = utf8.encode('%PDF-1.4\n...');
      // Downloaded as PPTX filename from Moodle, but Moodle OfficeViewer converted it to PDF
      final correctedName = service.fixFilenameExtension('Topic 1.1 Slides.pptx', pdfBytes);
      expect(correctedName, 'Topic 1.1 Slides.pdf');

      // Filename already matches
      expect(service.fixFilenameExtension('Topic 1.1 Slides.pdf', pdfBytes), 'Topic 1.1 Slides.pdf');
    });
  });
}

