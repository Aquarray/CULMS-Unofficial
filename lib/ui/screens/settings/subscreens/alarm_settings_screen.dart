import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/app_providers.dart';
import '../../../../providers/dashboard_provider.dart';
import '../../../../providers/settings_provider.dart';

class AlarmSettingsScreen extends ConsumerWidget {
  const AlarmSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminders & Alarms'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Main Switch Setting
                SwitchListTile(
                  secondary: const Icon(Icons.alarm_on_rounded, color: Colors.amber),
                  title: const Text(
                    'Deadline & Quiz Alarms',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Schedule high-priority alarms for academic events.',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: settings.enableDeadlineAlarms,
                  onChanged: (val) {
                    settingsNotifier.updateEnableDeadlineAlarms(val);
                    final events = ref.read(dashboardProvider).events;
                    ref.read(alarmServiceProvider).refreshAlarms(
                      events: events,
                      settings: settings.copyWith(enableDeadlineAlarms: val),
                    );
                  },
                ),
                if (settings.enableDeadlineAlarms) ...[
                  const Divider(height: 1),
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                    title: const Text(
                      '24 Hours Before (Quiz Alert)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    subtitle: const Text(
                      'Notify 1 day ahead for quizzes and tests.',
                      style: TextStyle(fontSize: 11),
                    ),
                    value: settings.alarm24HoursBefore,
                    onChanged: (val) {
                      settingsNotifier.updateAlarm24HoursBefore(val);
                      final events = ref.read(dashboardProvider).events;
                      ref.read(alarmServiceProvider).refreshAlarms(
                        events: events,
                        settings: settings.copyWith(alarm24HoursBefore: val),
                      );
                    },
                  ),
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                    title: const Text(
                      '1 Hour Before (Urgent Reminder)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    subtitle: const Text(
                      'Alert 60 minutes before assignment deadlines & quiz start.',
                      style: TextStyle(fontSize: 11),
                    ),
                    value: settings.alarm1HourBefore,
                    onChanged: (val) {
                      settingsNotifier.updateAlarm1HourBefore(val);
                      final events = ref.read(dashboardProvider).events;
                      ref.read(alarmServiceProvider).refreshAlarms(
                        events: events,
                        settings: settings.copyWith(alarm1HourBefore: val),
                      );
                    },
                  ),
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                    title: const Text(
                      'On the Time (Exact Deadline / Start)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    subtitle: const Text(
                      'Ring alarm at the exact moment event starts or ends.',
                      style: TextStyle(fontSize: 11),
                    ),
                    value: settings.alarmAtExactTime,
                    onChanged: (val) {
                      settingsNotifier.updateAlarmAtExactTime(val);
                      final events = ref.read(dashboardProvider).events;
                      ref.read(alarmServiceProvider).refreshAlarms(
                        events: events,
                        settings: settings.copyWith(alarmAtExactTime: val),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Actions without switches: simplified titles with action buttons at bottom of title
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Alarm Preview',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.volume_up_outlined, size: 18),
                      label: const Text('Test Loud Alarm Notification'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        await ref.read(alarmServiceProvider).showTestAlarm();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Test alarm triggered with sound and vibration!')),
                          );
                        }
                      },
                    ),
                  ),
                  const Divider(height: 28),
                  const Text(
                    'System Permissions',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.security_outlined, size: 18),
                      label: const Text('Request Notification Permission'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final granted = await ref
                            .read(notificationServiceProvider)
                            .requestNotificationPermission();
                        if (context.mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                granted ? 'Notification permission active' : 'Permission declined',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
