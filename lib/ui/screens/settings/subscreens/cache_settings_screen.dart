import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/app_providers.dart';
import '../../../../providers/cache_provider.dart';
import '../../../../providers/settings_provider.dart';

class CacheSettingsScreen extends ConsumerStatefulWidget {
  const CacheSettingsScreen({super.key});

  @override
  ConsumerState<CacheSettingsScreen> createState() =>
      _CacheSettingsScreenState();
}

class _CacheSettingsScreenState extends ConsumerState<CacheSettingsScreen> {
  double _cacheSizeMb = 0.0;
  bool _isLoadingCacheSize = false;
  bool _isClearing = false;

  @override
  void initState() {
    super.initState();
    _refreshCacheSize();
  }

  Future<void> _refreshCacheSize() async {
    setState(() => _isLoadingCacheSize = true);
    final cacheService = ref.read(cacheServiceProvider);
    final size = await cacheService.getCacheSizeMb();
    if (mounted) {
      setState(() {
        _cacheSizeMb = size;
        _isLoadingCacheSize = false;
      });
    }
  }

  Future<void> _clearCache() async {
    if (_isClearing) return;
    setState(() => _isClearing = true);
    try {
      await ref.read(clearAppCacheProvider)();
      if (!mounted) return;
      await _refreshCacheSize();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offline cache cleared successfully')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not clear the cache. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isClearing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Offline Cache & Storage')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          Card(
            child: Column(
              children: [
                // Settings with switch: good title, description, and switch
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  title: const Text(
                    'Offline Content Caching',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Saves courses and study materials locally to speed up browsing and reduce repeated network requests.',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: settings.enableOfflineCache,
                  onChanged: (val) => settingsNotifier.updateOfflineCache(val),
                ),
                const Divider(height: 1),

                // Setting without switch: simplified title, button placed beneath title
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Local Cache',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            _isLoadingCacheSize
                                ? 'Calculating...'
                                : '${_cacheSizeMb.toStringAsFixed(2)} MB stored',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isClearing ? null : _clearCache,
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                          ),
                          label: Text(
                            _isClearing ? 'Clearing...' : 'Clear Cache',
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
