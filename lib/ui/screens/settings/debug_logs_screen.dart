import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/log_service.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/settings_provider.dart';

class DebugLogsScreen extends ConsumerStatefulWidget {
  const DebugLogsScreen({super.key});

  @override
  ConsumerState<DebugLogsScreen> createState() => _DebugLogsScreenState();
}

class _DebugLogsScreenState extends ConsumerState<DebugLogsScreen> {
  String _selectedFilter = 'all'; // all, http, error, info
  String _searchQuery = '';
  bool _isTesting = false;

  Future<void> _runQuickTest(String testType) async {
    setState(() => _isTesting = true);
    final logService = ref.read(logServiceProvider);
    final apiClient = ref.read(lmsApiClientProvider);
    final auth = ref.read(authProvider);

    logService.info('DIAGNOSTIC', '=== Starting Test: $testType ===');

    try {
      if (testType == 'sso') {
        final cookieService = ref.read(cookieServiceProvider);
        final settings = ref.read(settingsProvider);
        final savedCreds = await cookieService.getSavedCredentials();
        final uid = savedCreds?.uid ?? auth.session?.uid;
        final password = savedCreds?.password ?? auth.session?.password;

        if (uid == null || uid.isEmpty || password == null || password.isEmpty) {
          logService.warning(
            'DIAGNOSTIC',
            'Cannot test SSO: no user credentials saved on device. Please log in first.',
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No saved user credentials found. Please sign in first.'),
              ),
            );
          }
          return;
        }

        logService.info('DIAGNOSTIC', 'Testing SSO Gateway with user credentials: $uid');
        final resp = await apiClient.loginSso(
          uid: uid,
          password: password,
          apiToken: settings.ssoApiToken.isNotEmpty ? settings.ssoApiToken : 'dont_use_please',
          gatewayUrl: settings.ssoGatewayUrl,
          onStatusUpdate: (msg) {
            logService.info('DIAGNOSTIC', 'SSO Status: $msg');
          },
        );
        logService.info(
          'DIAGNOSTIC',
          'SSO Response Success: ${resp.success}, URL: ${resp.lmsLoginUrl}, Error: ${resp.error}',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                resp.success
                    ? 'SSO API test successful for $uid!'
                    : 'SSO API test failed: ${resp.error ?? "Unknown error"}',
              ),
            ),
          );
        }
      } else if (testType == 'courses') {
        if (!auth.isAuthenticated || auth.session == null) {
          logService.warning('DIAGNOSTIC', 'Cannot test courses: user is not authenticated.');
        } else {
          logService.info('DIAGNOSTIC', 'Testing getEnrolledCourses for session: ${auth.session!.uid}');
          final courses = await apiClient.getEnrolledCourses(auth.session!, forceRefresh: true);
          logService.info('DIAGNOSTIC', 'Fetched ${courses.length} courses successfully.');
        }
      } else if (testType == 'events') {
        if (!auth.isAuthenticated || auth.session == null) {
          logService.warning('DIAGNOSTIC', 'Cannot test events: user is not authenticated.');
        } else {
          logService.info('DIAGNOSTIC', 'Testing getTimelineEvents for session: ${auth.session!.uid}');
          final events = await apiClient.getTimelineEvents(auth.session!, forceRefresh: true);
          logService.info('DIAGNOSTIC', 'Fetched ${events.length} calendar events successfully.');
        }
      }
    } catch (e, st) {
      logService.error('DIAGNOSTIC', 'Test failed: $e', st.toString());
    } finally {
      if (mounted) {
        setState(() => _isTesting = false);
      }
    }
  }

  void _copyAllLogs() {
    final logService = ref.read(logServiceProvider);
    final text = logService.getAllLogsAsText();
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All logs copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logService = ref.watch(logServiceProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Logs & API Console'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Copy All Logs',
            onPressed: logService.logs.isNotEmpty ? _copyAllLogs : null,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: 'Clear Logs',
            onPressed: logService.logs.isNotEmpty ? () => logService.clear() : null,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: logService,
        builder: (context, _) {
          final filteredLogs = logService.logs.where((entry) {
            if (_selectedFilter == 'http' && entry.level != LogLevel.http) return false;
            if (_selectedFilter == 'error' && entry.level != LogLevel.error) return false;
            if (_selectedFilter == 'info' && entry.level != LogLevel.info) return false;

            if (_searchQuery.isNotEmpty) {
              final query = _searchQuery.toLowerCase();
              final matches = entry.tag.toLowerCase().contains(query) ||
                  entry.message.toLowerCase().contains(query) ||
                  (entry.details?.toLowerCase().contains(query) ?? false);
              if (!matches) return false;
            }

            return true;
          }).toList();

          return Column(
            children: [
          // Diagnostics quick action bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: isDark ? const Color(0xFF1B1E22) : const Color(0xFFF1F5F9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Live Backend Diagnostics',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    if (_isTesting)
                      const SizedBox(
                        height: 14,
                        width: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.vpn_key_outlined, size: 14),
                        label: const Text('Test SSO API', style: TextStyle(fontSize: 12)),
                        onPressed: _isTesting ? null : () => _runQuickTest('sso'),
                      ),
                      const SizedBox(width: 8),
                      ActionChip(
                        avatar: const Icon(Icons.school_outlined, size: 14),
                        label: const Text('Test Courses API', style: TextStyle(fontSize: 12)),
                        onPressed: _isTesting ? null : () => _runQuickTest('courses'),
                      ),
                      const SizedBox(width: 8),
                      ActionChip(
                        avatar: const Icon(Icons.event_outlined, size: 14),
                        label: const Text('Test Events API', style: TextStyle(fontSize: 12)),
                        onPressed: _isTesting ? null : () => _runQuickTest('events'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Search & Filter controls
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                TextField(
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  decoration: InputDecoration(
                    hintText: 'Search logs (URL, sesskey, error...)',
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1A1D21) : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterTab(
                        label: 'All (${logService.logs.length})',
                        isSelected: _selectedFilter == 'all',
                        onTap: () => setState(() => _selectedFilter = 'all'),
                      ),
                      const SizedBox(width: 6),
                      _FilterTab(
                        label: 'HTTP Network',
                        isSelected: _selectedFilter == 'http',
                        color: Colors.blue,
                        onTap: () => setState(() => _selectedFilter = 'http'),
                      ),
                      const SizedBox(width: 6),
                      _FilterTab(
                        label: 'Errors',
                        isSelected: _selectedFilter == 'error',
                        color: Colors.red,
                        onTap: () => setState(() => _selectedFilter = 'error'),
                      ),
                      const SizedBox(width: 6),
                      _FilterTab(
                        label: 'Info',
                        isSelected: _selectedFilter == 'info',
                        color: Colors.green,
                        onTap: () => setState(() => _selectedFilter = 'info'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Log Entries List
          Expanded(
            child: filteredLogs.isEmpty
                ? Center(
                    child: Text(
                      logService.logs.isEmpty
                          ? 'No logs recorded yet.\nPerform an action or run a test.'
                          : 'No logs match filter.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    itemCount: filteredLogs.length,
                    itemBuilder: (context, idx) {
                      final entry = filteredLogs[idx];
                      return _LogCard(entry: entry);
                    },
                  ),
          ),
        ],
          );
        },
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterTab({
    required this.label,
    required this.isSelected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = color ?? theme.primaryColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.15) : null,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? activeColor : Colors.grey.withValues(alpha: 0.3),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? activeColor : null,
          ),
        ),
      ),
    );
  }
}

class _LogCard extends StatefulWidget {
  final LogEntry entry;

  const _LogCard({required this.entry});

  @override
  State<_LogCard> createState() => _LogCardState();
}

class _LogCardState extends State<_LogCard> {
  bool _expanded = false;

  Color _getLevelColor(LogLevel level) {
    switch (level) {
      case LogLevel.http:
        return Colors.blue;
      case LogLevel.error:
        return Colors.red;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.info:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final levelColor = _getLevelColor(widget.entry.level);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: levelColor.withValues(alpha: 0.25), width: 1),
      ),
      child: InkWell(
        onTap: () {
          if (widget.entry.details != null && widget.entry.details!.isNotEmpty) {
            setState(() => _expanded = !_expanded);
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: levelColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      widget.entry.level.name.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: levelColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.entry.tag,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Text(
                    widget.entry.formattedTime,
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                widget.entry.message,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
              if (_expanded && widget.entry.details != null) ...[
                const Divider(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F1113) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: SelectableText(
                    widget.entry.details!,
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
