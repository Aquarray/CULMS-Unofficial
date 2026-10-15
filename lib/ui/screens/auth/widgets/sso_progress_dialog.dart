import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../providers/auth_provider.dart';

/// Modal dialog that visualizes live SSO authentication progress:
/// - 5-tick segmented progress bar on top
/// - Clean spinning progress indicator
/// - Live dynamic status message
/// - One-tap Cancel button
class SsoProgressDialog extends ConsumerWidget {
  const SsoProgressDialog({super.key, this.onCancel});

  final VoidCallback? onCancel;

  static bool _isShowing = false;
  static BuildContext? _dialogContext;
  static bool _isProgrammaticDismiss = false;

  /// Shows the dialog if not already visible.
  static Future<void> show(BuildContext context) async {
    if (_isShowing) return;
    _isShowing = true;
    _isProgrammaticDismiss = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        _dialogContext = ctx;
        return const SsoProgressDialog();
      },
    );

    _isShowing = false;
    _dialogContext = null;
    _isProgrammaticDismiss = false;
  }

  /// Dismisses the dialog safely if it is currently displayed.
  static void dismiss(BuildContext context) {
    if (_isShowing && _dialogContext != null) {
      final ctx = _dialogContext!;
      _isProgrammaticDismiss = true;
      _isShowing = false;
      _dialogContext = null;
      if (Navigator.canPop(ctx)) {
        Navigator.pop(ctx);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    final authState = ref.watch(authProvider);
    final progress = authState.progress;
    final currentPhase = progress?.phaseIndex ?? 1;
    final attempt = progress?.attempt;
    final maxAttempts = progress?.maxAttempts ?? 2;

    final displayMessage = progress?.message ??
        authState.statusMessage ??
        'Connecting to Cloud SSO Gateway...';

    final isRetrying = progress?.isRetry == true;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && !_isProgrammaticDismiss) {
          if (onCancel != null) {
            onCancel!();
          } else {
            ref.read(authProvider.notifier).cancelLogin();
          }
        }
      },
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? const Color(0xFF1E222A) : Colors.white,
        elevation: 10,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 5-Tick Progress Bar on Top
                Row(
                  children: List.generate(5, (index) {
                    final tick = index + 1;
                    final isCompleted = tick < currentPhase;
                    final isCurrent = tick == currentPhase;

                    return Expanded(
                      child: Container(
                        height: 4.5,
                        margin: EdgeInsets.only(
                          right: index < 4 ? 5.0 : 0.0,
                        ),
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? const Color(0xFF10B981)
                              : isCurrent
                                  ? primaryColor
                                  : (isDark ? Colors.white12 : Colors.black12),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 10),

                // Top Attempt / Step indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Step $currentPhase of 5',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      ),
                    ),
                    if (attempt != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: isRetrying
                              ? Colors.orange.withValues(alpha: 0.2)
                              : primaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Attempt $attempt of $maxAttempts',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isRetrying
                                ? (isDark ? const Color(0xFFFFB74D) : const Color(0xFFE65100))
                                : primaryColor,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 22),

                // Clean Progress Indicator (No Bot Icon)
                SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 16),

                // Title: "Logging in..."
                Text(
                  isRetrying ? 'Retrying Authentication...' : 'Logging In...',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 8),

                // Live Dynamic Progress Message
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    displayMessage,
                    key: ValueKey(displayMessage),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Cancel Button
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      _isProgrammaticDismiss = true;
                      if (onCancel != null) {
                        onCancel!();
                      } else {
                        ref.read(authProvider.notifier).cancelLogin();
                      }
                      Navigator.of(context).pop();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: isDark ? Colors.white70 : const Color(0xFF64748B),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: isDark ? Colors.white12 : Colors.black12,
                        ),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
