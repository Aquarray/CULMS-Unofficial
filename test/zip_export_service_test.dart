import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:cuims_unofficial2/core/services/zip_export_service.dart';

void main() {
  group('ZipExportService Tests', () {
    test('Correctly identifies binary magic numbers vs HTML', () {
      final pptxBytes = [0x50, 0x4B, 0x03, 0x04, 0x14, 0x00, 0x06, 0x00];
      final pdfBytes = [0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x35];
      final olePptBytes = [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1];
      final htmlBytes = utf8.encode('<!DOCTYPE html><html><head><title>Office Viewer</title></head><body><iframe id="resourceobject" src="pdf.php"></iframe></body></html>');

      expect(ZipExportService.isHtml(pptxBytes), false);
      expect(ZipExportService.isHtml(pdfBytes), false);
      expect(ZipExportService.isHtml(olePptBytes), false);
      expect(ZipExportService.isHtml(htmlBytes), true);
    });

    test('Determines correct filename extension based on binary magic bytes', () {
      final pptxBytes = [0x50, 0x4B, 0x03, 0x04, 0x14, 0x00, 0x06, 0x00];
      final pdfBytes = [0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x35];
      final olePptBytes = [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1];

      expect(ZipExportService.resolveExtension(pptxBytes, originalName: 'Lecture 1.pptx'), 'pptx');
      expect(ZipExportService.resolveExtension(pdfBytes, originalName: 'Lecture 1.pptx'), 'pdf');
      expect(ZipExportService.resolveExtension(olePptBytes, originalName: 'Lecture 1.ppt'), 'ppt');
    });

    test('extractFilenameFromUrl correctly decodes URL-encoded filenames', () {
      const url = 'https://lms.cuchd.in/pluginfile.php/4800849/mod_resource/content/1/Topic%202.1.1%20-%20Waterfall%20Model%20Overview.pptx?forcedownload=1';
      final filename = ZipExportService.extractFilenameFromUrl(url);
      expect(filename, 'Topic 2.1.1 - Waterfall Model Overview.pptx');
    });

    test('htmlToMarkdown converts Moodle HTML page content into clean Markdown', () {
      const sampleHtml = '''
        <div class="box generalbox">
          <h2>Overview of Software Engineering</h2>
          <p>Software engineering is the systematic approach to development.</p>
          <ul>
            <li>Waterfall Model</li>
            <li>Agile Methodology</li>
          </ul>
        </div>
      ''';

      final md = ZipExportService.htmlToMarkdown(sampleHtml, title: 'Lecture Notes');
      expect(md.contains('# Lecture Notes'), true);
      expect(md.contains('## Overview of Software Engineering'), true);
      expect(md.contains('Software engineering is the systematic approach'), true);
      expect(md.contains('- Waterfall Model'), true);
      expect(md.contains('- Agile Methodology'), true);
    });
  });
}
