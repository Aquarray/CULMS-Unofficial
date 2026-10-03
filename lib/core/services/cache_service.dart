import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CacheItem<T> {
  final T data;
  final DateTime timestamp;
  final Duration ttl;

  CacheItem({
    required this.data,
    required this.timestamp,
    required this.ttl,
  });

  bool get isExpired => DateTime.now().difference(timestamp) > ttl;
}

class CacheService {
  static const String _metadataPrefix = 'cache_meta_';

  // In-memory cache for ultra-fast access
  final Map<String, CacheItem<dynamic>> _memoryCache = {};

  Future<Directory> _getCacheDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${appDir.path}/lms_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  Future<void> putJson(String key, dynamic data, {Duration ttl = const Duration(hours: 12)}) async {
    final now = DateTime.now();
    _memoryCache[key] = CacheItem(data: data, timestamp: now, ttl: ttl);

    try {
      final cacheDir = await _getCacheDirectory();
      final sanitizedKey = key.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final file = File('${cacheDir.path}/$sanitizedKey.json');
      await file.writeAsString(json.encode({
        'timestamp': now.toIso8601String(),
        'ttlMinutes': ttl.inMinutes,
        'data': data,
      }));

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_metadataPrefix$sanitizedKey', now.toIso8601String());
    } catch (_) {}
  }

  Future<T?> getJson<T>(String key, {bool ignoreExpiration = false}) async {
    // 1. Check memory cache
    if (_memoryCache.containsKey(key)) {
      final item = _memoryCache[key]!;
      if (ignoreExpiration || !item.isExpired) {
        return item.data as T?;
      }
    }

    // 2. Check disk cache
    try {
      final cacheDir = await _getCacheDirectory();
      final sanitizedKey = key.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final file = File('${cacheDir.path}/$sanitizedKey.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final decoded = json.decode(content) as Map<String, dynamic>;
        final timestamp = DateTime.parse(decoded['timestamp'] as String);
        final ttlMinutes = decoded['ttlMinutes'] as int? ?? 720;
        final ttl = Duration(minutes: ttlMinutes);

        final item = CacheItem(
          data: decoded['data'],
          timestamp: timestamp,
          ttl: ttl,
        );

        _memoryCache[key] = item;

        if (ignoreExpiration || !item.isExpired) {
          return item.data as T?;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Store binary file (PDF, PPTX, image) locally to avoid repeated downloads
  Future<File> saveFile(String filename, List<int> bytes) async {
    final cacheDir = await _getCacheDirectory();
    final sanitizedName = filename.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
    final file = File('${cacheDir.path}/files/$sanitizedName');
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    return await file.writeAsBytes(bytes);
  }

  /// Check if binary file is already cached
  Future<File?> getCachedFile(String filename) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final sanitizedName = filename.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
      final file = File('${cacheDir.path}/files/$sanitizedName');
      if (await file.exists() && await file.length() > 0) {
        return file;
      }
    } catch (_) {}
    return null;
  }

  /// Get total cache size in Megabytes
  Future<double> getCacheSizeMb() async {
    try {
      final cacheDir = await _getCacheDirectory();
      int totalBytes = 0;
      if (await cacheDir.exists()) {
        await for (final file in cacheDir.list(recursive: true, followLinks: false)) {
          if (file is File) {
            totalBytes += await file.length();
          }
        }
      }
      return totalBytes / (1024 * 1024);
    } catch (_) {
      return 0.0;
    }
  }

  /// Remove a specific cache key from memory and disk
  Future<void> remove(String key) async {
    _memoryCache.remove(key);
    try {
      final cacheDir = await _getCacheDirectory();
      final sanitizedKey = key.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final file = File('${cacheDir.path}/$sanitizedKey.json');
      if (await file.exists()) {
        await file.delete();
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_metadataPrefix$sanitizedKey');
    } catch (_) {}
  }

  /// Clear all cached JSON and downloaded files
  Future<void> clearCache() async {
    _memoryCache.clear();
    try {
      final cacheDir = await _getCacheDirectory();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        await cacheDir.create();
      }

      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(_metadataPrefix)).toList();
      for (final k in keys) {
        await prefs.remove(k);
      }
    } catch (_) {}
  }
}
