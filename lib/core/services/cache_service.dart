import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CacheItem<T> {
  final T data;
  final DateTime timestamp;
  final Duration ttl;

  CacheItem({required this.data, required this.timestamp, required this.ttl});

  bool get isExpired => DateTime.now().difference(timestamp) >= ttl;
}

class CacheService {
  CacheService({
    bool Function()? isEnabled,
    Duration Function()? defaultTtl,
    Future<Directory> Function()? directory,
    Future<Directory> Function()? temporaryDirectory,
    DateTime Function()? now,
  }) : _isEnabled = isEnabled ?? (() => true),
       _defaultTtl = defaultTtl ?? (() => const Duration(hours: 12)),
       _directory = directory ?? _defaultDirectory,
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
       _now = now ?? DateTime.now;

  final bool Function() _isEnabled;
  final Duration Function() _defaultTtl;
  final Future<Directory> Function() _directory;
  final Future<Directory> Function() _temporaryDirectory;
  final DateTime Function() _now;
  final Map<String, CacheItem<dynamic>> _memoryCache = {};
  Future<void> _pending = Future<void>.value();
  int _generation = 0;

  /// Capture before a network request to prevent a late response from restoring
  /// data invalidated by Clear Cache, a refresh, or a cache-policy change.
  int get generation => _generation;

  void invalidatePendingWrites() {
    _generation++;
    _memoryCache.clear();
  }

  static Future<Directory> _defaultDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    return Directory('${appDir.path}/lms_cache');
  }

  // Hash the full identity instead of sanitizing names (which can collide).
  // Legacy unscoped cache paths are deliberately never read.
  String _identity(String key, String? accountId) =>
      sha256.convert(utf8.encode(json.encode([accountId, key]))).toString();

  Future<Directory> _cacheDirectory() async {
    final dir = await _directory();
    await dir.create(recursive: true);
    return dir;
  }

  // Serialize disk work so clearing/removal cannot race a file write.
  Future<T> _withStorage<T>(Future<T> Function() action) {
    final result = _pending.then((_) => action());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  bool _canWrite(int generation) => _isEnabled() && generation == _generation;

  bool _expired(DateTime timestamp, Duration ttl) {
    // A reduced retention setting also applies to existing entries.
    final currentTtl = _defaultTtl();
    final effectiveTtl = ttl < currentTtl ? ttl : currentTtl;
    return _now().difference(timestamp) >= effectiveTtl;
  }

  Future<void> putJson(
    String key,
    dynamic data, {
    Duration? ttl,
    String? accountId,
    int? expectedGeneration,
  }) {
    final generation = expectedGeneration ?? _generation;
    return _withStorage(() async {
      if (!_canWrite(generation)) return;
      final id = _identity(key, accountId);
      final timestamp = _now();
      final retention = ttl ?? _defaultTtl();
      if (retention <= Duration.zero) return;
      _memoryCache[id] = CacheItem(
        data: data,
        timestamp: timestamp,
        ttl: retention,
      );
      try {
        final dir = await _cacheDirectory();
        if (!_canWrite(generation)) return;
        await File('${dir.path}/$id.json').writeAsString(
          json.encode({
            'timestamp': timestamp.toIso8601String(),
            'ttlMicroseconds': retention.inMicroseconds,
            'data': data,
          }),
        );
      } catch (_) {
        // Cache persistence must not fail a successful LMS request.
      }
    });
  }

  Future<T?> getJson<T>(
    String key, {
    bool ignoreExpiration = false,
    String? accountId,
  }) {
    final readGeneration = _generation;
    return _withStorage(() async {
      if (!_isEnabled() || readGeneration != _generation) return null;
      final id = _identity(key, accountId);
      try {
        final memory = _memoryCache[id];
        if (memory != null &&
            (ignoreExpiration || !_expired(memory.timestamp, memory.ttl))) {
          return memory.data as T?;
        }
        _memoryCache.remove(id);
        final dir = await _cacheDirectory();
        final file = File('${dir.path}/$id.json');
        if (!await file.exists()) return null;
        final decoded =
            json.decode(await file.readAsString()) as Map<String, dynamic>;
        final timestamp = DateTime.parse(decoded['timestamp'] as String);
        final ttl = Duration(microseconds: decoded['ttlMicroseconds'] as int);
        if (!_isEnabled() ||
            readGeneration != _generation ||
            (!ignoreExpiration && _expired(timestamp, ttl))) {
          return null;
        }
        final data = decoded['data'] as T?;
        _memoryCache[id] = CacheItem(
          data: data,
          timestamp: timestamp,
          ttl: ttl,
        );
        return data;
      } catch (_) {
        // Corrupt files and incompatible types are misses, not app errors.
        _memoryCache.remove(id);
        return null;
      }
    });
  }

  /// The viewer still needs a local file when caching is off. In that case use
  /// a temporary, never-reused file rather than the persistent cache directory.
  Future<File> saveFile(
    String filename,
    List<int> bytes, {
    String? sourceUrl,
    String? accountId,
    int? expectedGeneration,
  }) {
    final generation = expectedGeneration ?? _generation;
    return _withStorage(() async {
      final cacheable = _canWrite(generation) && _defaultTtl() > Duration.zero;
      final dir = cacheable
          ? await _cacheDirectory()
          : await _temporaryDirectory();
      // Recheck after awaiting platform directory lookup.
      if (cacheable && !_canWrite(generation)) {
        final temp = await _temporaryDirectory();
        return _writeTemporary(temp, filename, bytes);
      }
      if (!cacheable) return _writeTemporary(dir, filename, bytes);
      final fileDir = Directory(
        '${dir.path}/files/${_identity(sourceUrl ?? filename, accountId)}',
      );
      if (await fileDir.exists()) await fileDir.delete(recursive: true);
      await fileDir.create(recursive: true);
      final safeName = filename.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
      final file = File(
        '${fileDir.path}/${safeName.isEmpty ? 'document' : safeName}',
      );
      await file.writeAsBytes(bytes);
      await file.setLastModified(_now());
      if (!_canWrite(generation)) {
        return _writeTemporary(await _temporaryDirectory(), filename, bytes);
      }
      return file;
    });
  }

  Future<File> _writeTemporary(
    Directory dir,
    String filename,
    List<int> bytes,
  ) async {
    final temp = await dir.createTemp('lms_document_');
    final safeName = filename.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
    return File('${temp.path}/${safeName.isEmpty ? 'document' : safeName}')
        .writeAsBytes(bytes);
  }

  Future<File?> getCachedFile(
    String filename, {
    String? sourceUrl,
    String? accountId,
  }) {
    final readGeneration = _generation;
    return _withStorage(() async {
      if (!_isEnabled() || readGeneration != _generation) return null;
      try {
        final dir = await _cacheDirectory();
        final fileDir = Directory(
          '${dir.path}/files/${_identity(sourceUrl ?? filename, accountId)}',
        );
        if (!await fileDir.exists()) return null;
        final files = await fileDir.list().where((e) => e is File).toList();
        if (files.isEmpty) return null;
        final file = files.first as File;
        if (await file.exists() &&
            await file.length() > 0 &&
            !_expired(await file.lastModified(), _defaultTtl()) &&
            _isEnabled() &&
            readGeneration == _generation) {
          return file;
        }
      } catch (_) {}
      return null;
    });
  }

  Future<double> getCacheSizeMb() => _withStorage(() async {
    try {
      final dir = await _cacheDirectory();
      var totalBytes = 0;
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) totalBytes += await entity.length();
      }
      return totalBytes / (1024 * 1024);
    } catch (_) {
      return 0.0;
    }
  });

  Future<void> remove(String key, {String? accountId}) {
    invalidatePendingWrites();
    final id = _identity(key, accountId);
    return _withStorage(() async {
      final dir = await _cacheDirectory();
      final file = File('${dir.path}/$id.json');
      if (await file.exists()) await file.delete();
    });
  }

  /// Unlike best-effort cache writes, cleanup errors propagate so the UI cannot
  /// report success when storage was not cleared.
  Future<void> clearCache() {
    invalidatePendingWrites();
    return _withStorage(() async {
      _memoryCache.clear();
      final dir = await _directory();
      if (await dir.exists()) await dir.delete(recursive: true);
      await dir.create(recursive: true);
      // Remove metadata left by the old cache implementation as well.
      final prefs = await SharedPreferences.getInstance();
      for (final key
          in prefs
              .getKeys()
              .where((k) => k.startsWith('cache_meta_'))
              .toList()) {
        await prefs.remove(key);
      }
    });
  }
}
