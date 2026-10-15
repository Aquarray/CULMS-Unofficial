import 'package:flutter/material.dart';

/// Represents a live progress update emitted by the CUIMS -> LMS SSO API over Server-Sent Events (SSE).
class SsoProgress {
  final String stage;
  final String message;
  final int? attempt;
  final int? maxAttempts;
  final DateTime timestamp;

  SsoProgress({
    required this.stage,
    required this.message,
    this.attempt,
    this.maxAttempts,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory SsoProgress.fromJson(Map<String, dynamic> json) {
    return SsoProgress(
      stage: json['stage'] as String? ?? 'unknown',
      message: json['message'] as String? ?? 'Processing...',
      attempt: (json['attempt'] as num?)?.toInt(),
      maxAttempts: (json['maxAttempts'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stage': stage,
      'message': message,
      if (attempt != null) 'attempt': attempt,
      if (maxAttempts != null) 'maxAttempts': maxAttempts,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// Whether this progress update indicates an attempt retry.
  bool get isRetry => stage == 'retrying' || (attempt != null && attempt! > 1 && stage == 'starting_login');

  /// Human-friendly display title for the current stage.
  String get stageTitle {
    switch (stage) {
      case 'starting_login':
        return 'Starting Automation';
      case 'retrying':
        return 'Retrying Authentication';
      case 'connecting_cuims':
        return 'Connecting to CUIMS';
      case 'resolving_identity':
        return 'Verifying Identity';
      case 'loading_captcha':
        return 'Fetching Security CAPTCHA';
      case 'solving_captcha':
        return 'AI OCR Solving CAPTCHA';
      case 'submitting_login':
        return 'Submitting Credentials';
      case 'waiting_cuims':
        return 'Awaiting Portal Verification';
      case 'opening_dashboard':
        return 'Opening Student Dashboard';
      case 'requesting_lms_sso':
        return 'Requesting LMS Bridge';
      case 'capturing_token':
        return 'Capturing Session Token';
      case 'manual_captcha_required':
        return 'Manual Verification Needed';
      default:
        return 'Processing SSO Login';
    }
  }

  /// Icon corresponding to the current stage.
  IconData get stageIcon {
    switch (stage) {
      case 'starting_login':
        return Icons.rocket_launch_rounded;
      case 'retrying':
        return Icons.replay_rounded;
      case 'connecting_cuims':
        return Icons.cloud_sync_rounded;
      case 'resolving_identity':
        return Icons.badge_outlined;
      case 'loading_captcha':
        return Icons.image_search_rounded;
      case 'solving_captcha':
        return Icons.auto_awesome_rounded;
      case 'submitting_login':
        return Icons.lock_open_rounded;
      case 'waiting_cuims':
        return Icons.hourglass_top_rounded;
      case 'opening_dashboard':
        return Icons.dashboard_customize_outlined;
      case 'requesting_lms_sso':
        return Icons.swap_horiz_rounded;
      case 'capturing_token':
        return Icons.key_rounded;
      case 'manual_captcha_required':
        return Icons.security_rounded;
      default:
        return Icons.smart_toy_outlined;
    }
  }

  /// Progress order/phase index for visual pipeline animation (1 to 5).
  int get phaseIndex {
    switch (stage) {
      case 'starting_login':
      case 'retrying':
      case 'connecting_cuims':
        return 1;
      case 'resolving_identity':
        return 2;
      case 'loading_captcha':
      case 'solving_captcha':
      case 'manual_captcha_required':
        return 3;
      case 'submitting_login':
      case 'waiting_cuims':
        return 4;
      case 'opening_dashboard':
      case 'requesting_lms_sso':
      case 'capturing_token':
        return 5;
      default:
        return 1;
    }
  }

  @override
  String toString() => 'SsoProgress(stage: $stage, message: $message, attempt: $attempt)';
}
