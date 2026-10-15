import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cuims_unofficial2/core/services/cache_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late DateTime now;
  late bool enabled;
  late Duration retention;
  late CacheService cache;

  CacheService createCache() => CacheService(
    isEnabled: () => enabled,
    defaultTtl: () => retention,
    directory: () async => Directory('${root.path}/cache'),
    temporaryDirectory: () async => root,
    now: () => now,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('culms_cache_test_');
    now = DateTime(2026, 10, 15);
    enabled = true;
    retention = const Duration(hours: 2);
    cache = createCache();
  });
  tearDown(() async => root.delete(recursive: true));

  test(
    'JSON survives service recreation and expires at the configured TTL',
    () async {
      await cache.putJson('courses', ['math'], accountId: 'student1');
      expect(
        await createCache().getJson<List<dynamic>>(
          'courses',
          accountId: 'student1',
        ),
        ['math'],
      );
      now = now.add(retention);
      expect(await cache.getJson('courses', accountId: 'student1'), isNull);
      expect(
        await createCache().getJson('courses', accountId: 'student1'),
        isNull,
      );
    },
  );

  test(
    'short explicit TTL survives disk round trip without rounding to minutes',
    () async {
      await cache.putJson('short', 'value', ttl: const Duration(seconds: 5));
      now = now.add(const Duration(seconds: 4));
      expect(await createCache().getJson<String>('short'), 'value');
      now = now.add(const Duration(seconds: 1));
      expect(await createCache().getJson('short'), isNull);
    },
  );

  test(
    'reducing retention expires existing entries in memory and on disk',
    () async {
      await cache.putJson('courses', 'old');
      now = now.add(const Duration(hours: 1));
      retention = const Duration(minutes: 30);
      expect(await cache.getJson('courses'), isNull);
      expect(await createCache().getJson('courses'), isNull);
    },
  );

  test(
    'disabled cache bypasses memory/disk and does not persist new JSON',
    () async {
      await cache.putJson('old', 'cached');
      enabled = false;
      expect(await cache.getJson('old'), isNull);
      expect(await cache.getJson('old', ignoreExpiration: true), isNull);
      await cache.putJson('new', 'network');
      enabled = true;
      expect(await createCache().getJson('new'), isNull);
    },
  );

  test('account and original key identities cannot collide', () async {
    await cache.putJson('a/b', 'first', accountId: 'one');
    await cache.putJson('a?b', 'second', accountId: 'one');
    await cache.putJson('a/b', 'other student', accountId: 'two');
    final disk = createCache();
    expect(await disk.getJson<String>('a/b', accountId: 'one'), 'first');
    expect(await disk.getJson<String>('a?b', accountId: 'one'), 'second');
    expect(
      await disk.getJson<String>('a/b', accountId: 'two'),
      'other student',
    );
    expect(await disk.getJson('a/b', accountId: 'three'), isNull);
    await cache.remove('a/b', accountId: 'one');
    expect(await cache.getJson('a/b', accountId: 'one'), isNull);
    expect(
      await cache.getJson<String>('a/b', accountId: 'two'),
      'other student',
    );
  });

  test(
    'files with the same name are isolated by source URL and account',
    () async {
      await cache.saveFile(
        'notes.pdf',
        [1],
        sourceUrl: 'https://lms/a',
        accountId: 'one',
      );
      await cache.saveFile(
        'notes.pdf',
        [2],
        sourceUrl: 'https://lms/b',
        accountId: 'one',
      );
      await cache.saveFile(
        'notes.pdf',
        [3],
        sourceUrl: 'https://lms/a',
        accountId: 'two',
      );
      for (final (url, account, bytes) in [
        ('https://lms/a', 'one', [1]),
        ('https://lms/b', 'one', [2]),
        ('https://lms/a', 'two', [3]),
      ]) {
        final file = await createCache().getCachedFile(
          'notes.pdf',
          sourceUrl: url,
          accountId: account,
        );
        expect(await file!.readAsBytes(), bytes);
      }
    },
  );

  test(
    'resolved download filenames still reuse the same source URL cache',
    () async {
      await cache.saveFile('actual-slides.pptx', [
        1,
        2,
      ], sourceUrl: 'https://lms/resource?id=1');
      final file = await cache.getCachedFile(
        'Lecture slides',
        sourceUrl: 'https://lms/resource?id=1',
      );
      expect(await file!.readAsBytes(), [1, 2]);
      expect(file.path.endsWith('actual-slides.pptx'), isTrue);
    },
  );

  test(
    'binary cache expires at retention and disabled downloads remain usable',
    () async {
      await cache.saveFile('file.pdf', [1, 2, 3]);
      now = now.add(retention);
      expect(await cache.getCachedFile('file.pdf'), isNull);
      enabled = false;
      final file = await cache.saveFile('file.pdf', [4, 5]);
      expect(await file.readAsBytes(), [4, 5]);
      expect(file.path.contains('/cache/'), isFalse);
      enabled = true;
      expect(await cache.getCachedFile('file.pdf'), isNull);
    },
  );

  test(
    'clear removes disk, memory, binary files and legacy metadata only',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cache_meta_old', 'legacy');
      await prefs.setString('saved_user_uid', 'keep');
      await cache.putJson('key', 'value');
      await cache.saveFile('notes.pdf', [1]);
      expect(await cache.getCacheSizeMb(), greaterThan(0));
      await cache.clearCache();
      expect(await cache.getJson('key'), isNull);
      expect(await createCache().getJson('key'), isNull);
      expect(await cache.getCachedFile('notes.pdf'), isNull);
      expect(await cache.getCacheSizeMb(), 0);
      expect(prefs.getString('cache_meta_old'), isNull);
      expect(prefs.getString('saved_user_uid'), 'keep');
    },
  );

  test('late network writes cannot repopulate a cleared cache', () async {
    final generation = cache.generation;
    await cache.clearCache();
    await cache.putJson('late', 'response', expectedGeneration: generation);
    final downloaded = await cache.saveFile('late.pdf', [
      1,
    ], expectedGeneration: generation);
    expect(await downloaded.readAsBytes(), [1]);
    expect(await cache.getJson('late'), isNull);
    expect(await cache.getCachedFile('late.pdf'), isNull);
    expect(await cache.getCacheSizeMb(), 0);
  });

  test(
    'clear waits for pending storage work without resurrecting memory',
    () async {
      await cache.putJson('key', 'value');
      final entered = Completer<void>();
      final release = Completer<void>();
      var first = true;
      final delayed = CacheService(
        directory: () async {
          if (first) {
            first = false;
            entered.complete();
            await release.future;
          }
          return Directory('${root.path}/cache');
        },
        now: () => now,
      );
      final read = delayed.getJson<String>('key');
      await entered.future;
      final clear = delayed.clearCache();
      release.complete();
      expect(await read, isNull);
      await clear;
      expect(await delayed.getJson('key'), isNull);
    },
  );

  test(
    'corrupt disk entries and wrong memory types are cache misses',
    () async {
      await cache.putJson('key', 123);
      expect(await cache.getJson<List<dynamic>>('key'), isNull);
      final file = (await Directory(
        '${root.path}/cache',
      ).list().toList()).whereType<File>().single;
      await file.writeAsString('invalid json');
      expect(await createCache().getJson('key'), isNull);
    },
  );

  test('clear errors propagate instead of being reported as success', () async {
    final broken = CacheService(
      directory: () async => throw const FileSystemException('unavailable'),
    );
    await expectLater(broken.clearCache(), throwsA(isA<FileSystemException>()));
  });
}
