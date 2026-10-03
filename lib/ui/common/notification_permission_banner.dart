import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';

class NotificationPermissionBanner extends ConsumerStatefulWidget {
  const NotificationPermissionBanner({super.key});

  @override
  ConsumerState<NotificationPermissionBanner> createState() => _NotificationPermissionBannerState();
}

class _NotificationPermissionBannerState extends ConsumerState<NotificationPermissionBanner> {
  bool _isGranted = true;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final service = ref.read(notificationServiceProvider);
    final granted = await service.isPermissionGranted();
    if (mounted) {
      setState(() {
        _isGranted = granted;
      });
    }
  }

  Future<void> _requestPermission() async {
    final service = ref.read(notificationServiceProvider);
    final granted = await service.requestNotificationPermission();
    if (mounted) {
      setState(() {
        _isGranted = granted;
        if (granted) _dismissed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isGranted || _dismissed) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF221F1B) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF423824) : const Color(0xFFFDE68A),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_active_outlined,
              color: Color(0xFFD97706),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enable Course Notifications',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Receive instant reminders for upcoming assignment deadlines, quiz attempts, and class notices.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    FilledButton(
                      onPressed: _requestPermission,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Allow Alerts', style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _dismissed = true;
                        });
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: isDark ? Colors.white60 : Colors.black54,
                      ),
                      child: const Text('Later', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
