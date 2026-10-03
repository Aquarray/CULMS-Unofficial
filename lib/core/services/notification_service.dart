import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_constants.dart';

class NotificationService {
  Future<bool> isPermissionGranted() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return true; // Not applicable on desktop/web directly
    }
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  Future<bool> requestNotificationPermission() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyNotificationPromptShown, true);

    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return true;
    }

    final status = await Permission.notification.request();
    return status.isGranted;
  }

  Future<bool> hasPromptedBefore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.keyNotificationPromptShown) ?? false;
  }
}
