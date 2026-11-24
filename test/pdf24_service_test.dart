import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cuims_unofficial2/core/services/pdf24_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Pdf24Service Rate Limiter & Unlimited Mode Tests', () {
    late SharedPreferences prefs;
    late Pdf24Service service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      service = Pdf24Service(prefs: prefs);
    });

    test('Initial quota is 10 merges with 0 used', () async {
      expect(await service.getRecentMergeCount(), 0);
      expect(await service.getRemainingQuota(), 10);
      expect(await service.getTimeUntilReset(), null);
      expect(await service.isUnlimitedMode(), false);
    });

    test('Recording merge transactions decreases remaining quota', () async {
      await service.recordMergeTransaction();
      expect(await service.getRecentMergeCount(), 1);
      expect(await service.getRemainingQuota(), 9);

      await service.recordMergeTransaction();
      await service.recordMergeTransaction();
      expect(await service.getRecentMergeCount(), 3);
      expect(await service.getRemainingQuota(), 7);
    });

    test('Exceeding 10 merges per 2 hr throws Pdf24RateLimitException', () async {
      for (var i = 0; i < 10; i++) {
        await service.recordMergeTransaction();
      }
      expect(await service.getRemainingQuota(), 0);

      // Attempting 1 more merge when 0 remaining should throw
      expect(
        () => service.checkRateLimit(1),
        throwsA(isA<Pdf24RateLimitException>()),
      );
    });

    test('Prunes timestamps older than 2 hours', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final threeHoursAgo = now - const Duration(hours: 3).inMilliseconds;
      final thirtyMinutesAgo = now - const Duration(minutes: 30).inMilliseconds;

      await prefs.setStringList('pdf24_merge_timestamps', [
        threeHoursAgo.toString(),
        thirtyMinutesAgo.toString(),
      ]);

      // Three hours ago is pruned, thirty minutes ago is kept
      expect(await service.getRecentMergeCount(), 1);
      expect(await service.getRemainingQuota(), 9);
    });

    test('unlockUnlimitedWithPassword rejects wrong password', () async {
      final unlocked = await service.unlockUnlimitedWithPassword('wrong_password');
      expect(unlocked, false);
      expect(await service.isUnlimitedMode(), false);
      expect(await service.getRemainingQuota(), 10);
    });

    test('unlockUnlimitedWithPassword succeeds with un-break-able@1029 and enables unlimited mode', () async {
      final unlocked = await service.unlockUnlimitedWithPassword('un-break-able@1029');
      expect(unlocked, true);
      expect(await service.isUnlimitedMode(), true);
      expect(await service.getRemainingQuota(), -1); // -1 signifies infinity (∞)

      // Even with 20 merges recorded, checkRateLimit must NOT throw in unlimited mode
      for (var i = 0; i < 20; i++) {
        await service.recordMergeTransaction();
      }
      expect(await service.getRecentMergeCount(), 20);
      await expectLater(service.checkRateLimit(1), completes);

      // Time until reset is null in unlimited mode
      expect(await service.getTimeUntilReset(), null);
    });

    test('setUnlimitedMode(false) restores standard rate limiting', () async {
      await service.unlockUnlimitedWithPassword('un-break-able@1029');
      expect(await service.isUnlimitedMode(), true);

      await service.setUnlimitedMode(false);
      expect(await service.isUnlimitedMode(), false);
      expect(await service.getRemainingQuota(), 10);
    });
  });

  group('Pdf24Service File Filtering & ZIP Extraction Tests', () {
    late Pdf24Service service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      service = Pdf24Service();
    });

    List<int> createZip(Map<String, List<int>> entries) {
      final archive = Archive();
      entries.forEach((name, bytes) {
        archive.addFile(ArchiveFile(name, bytes.length, bytes));
      });
      return ZipEncoder().encode(archive);
    }

    test('isKnownDocument accepts supported types and rejects unknown files', () {
      final pdfBytes = utf8.encode('%PDF-1.4\n...');
      final txtBytes = utf8.encode('Hello plain text');
      final unknownBinary = [0x01, 0x02, 0x03, 0x04];
      final htmlBytes = utf8.encode('<!DOCTYPE html><html><body>Error</body></html>');

      expect(service.isKnownDocument('sample.pdf', pdfBytes), true);
      expect(service.isKnownDocument('notes.txt', txtBytes), true);
      expect(service.isKnownDocument('doc.md', txtBytes), true);
      expect(service.isKnownDocument('unknown.bin', unknownBinary), false);
      expect(service.isKnownDocument('virus.exe', unknownBinary), false);
      expect(service.isKnownDocument('page.html', htmlBytes), false);
    });

    test('prepareFilesForUpload extracts ZIP and discards unknown files', () {
      final pdfBytes = utf8.encode('%PDF-1.4\n...');
      final txtBytes = utf8.encode('Course outline');
      final scriptBytes = utf8.encode('print("hello")');
      final unknownBytes = [0xDE, 0xAD, 0xBE, 0xEF];

      final zipData = createZip({
        'Unit1/lecture.pdf': pdfBytes,
        'Unit1/notes.txt': txtBytes,
        'Unit1/script.py': scriptBytes,
        'Unit1/unknown.bin': unknownBytes,
        '__MACOSX/._lecture.pdf': [0x00],
      });

      final rawFiles = [
        (filename: 'Unit1_Materials.zip', bytes: zipData),
        (filename: 'standalone.pdf', bytes: pdfBytes),
        (filename: 'standalone.bin', bytes: unknownBytes),
      ];

      final uploadItems = service.prepareFilesForUpload(rawFiles);

      // Only lecture.pdf, notes.txt, and standalone.pdf should be present
      expect(uploadItems.length, 3);
      final names = uploadItems.map((e) => e.name).toList();
      expect(names.contains('lecture.pdf'), true);
      expect(names.contains('notes.txt'), true);
      expect(names.contains('standalone.pdf'), true);

      // Unknown and OS metadata files are omitted
      expect(names.any((n) => n.contains('.py')), false);
      expect(names.any((n) => n.contains('.bin')), false);
      expect(names.any((n) => n.contains('__MACOSX')), false);
    });
  });

  group('Pdf24Service End-to-End Pipeline with Mock Dio', () {
    test('mergeAndDownload completes full workflow and records 1 transaction', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final uri = options.uri.toString();
            if (uri.contains('action=upload')) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: [
                    {
                      'file': 'upload_test123.pdf',
                      'size': 100,
                      'ctime': 123456,
                      'host': 'filetools1.pdf24.org',
                      'name': 'test.pdf',
                    }
                  ],
                ),
              );
            }
            if (uri.contains('action=joinPdf')) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {'jobId': 'job_123'},
                ),
              );
            }
            if (uri.contains('action=getStatus')) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'status': 'done',
                    'job': {
                      'state': '3',
                      'out.file': 'merged.pdf',
                      'out.name': 'merged.pdf',
                      'out.size': 120,
                    },
                  },
                ),
              );
            }
            if (uri.contains('action=createResultAccessToken')) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {'token': 'tok_abc'},
                ),
              );
            }
            if (uri.contains('action=downloadJobResult')) {
              final pdfBytes = utf8.encode('%PDF-1.4\n1 0 obj<<>>endobj\ntrailer<<>>\n%%EOF');
              return handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: pdfBytes,
                ),
              );
            }
            return handler.next(options);
          },
        ),
      );

      final service = Pdf24Service(dio: dio, prefs: prefs);

      final tempDir = await Directory.systemTemp.createTemp('pdf24_test_');
      final targetFile = File('${tempDir.path}/test_merged.pdf');

      final items = [
        Pdf24UploadItem(
          name: 'test.pdf',
          bytes: utf8.encode('%PDF-1.4\n...'),
        ),
        Pdf24UploadItem(
          name: 'test2.pdf',
          bytes: utf8.encode('%PDF-1.4\n...'),
        ),
      ];

      final result = await service.mergeAndDownload(
        items: items,
        targetFile: targetFile,
      );

      expect(await result.exists(), true);
      final resultBytes = await result.readAsBytes();
      expect(resultBytes.take(4).toList(), [0x25, 0x50, 0x44, 0x46]); // %PDF

      // Verified that 1 merge transaction was recorded (not 2 files)
      expect(await service.getRecentMergeCount(), 1);
      expect(await service.getRemainingQuota(), 9);

      await tempDir.delete(recursive: true);
    });
  });
}
