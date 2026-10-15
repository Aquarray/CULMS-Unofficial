import 'package:flutter/material.dart';
import '../../../../data/models/sso_progress.dart';

/// A creative, high-tech automation loader widget that visualizes live progress
/// of the CUIMS -> LMS SSO pipeline streamed via Server-Sent Events (SSE).
class SsoAutomationLoader extends StatefulWidget {
  final SsoProgress? progress;
  final String? fallbackMessage;
  final VoidCallback? onCancel;

  const SsoAutomationLoader({
    super.key,
    this.progress,
    this.fallbackMessage,
    this.onCancel,
  });

  @override
  State<SsoAutomationLoader> createState() => _SsoAutomationLoaderState();
}

class _SsoAutomationLoaderState extends State<SsoAutomationLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  static const List<_PipelineStep> _steps = [
    _PipelineStep(label: 'Connect', phase: 1, icon: Icons.cloud_outlined),
    _PipelineStep(label: 'Identity', phase: 1, icon: Icons.person_outline),
    _PipelineStep(label: 'CAPTCHA', phase: 2, icon: Icons.auto_awesome_outlined),
    _PipelineStep(label: 'Verify', phase: 3, icon: Icons.lock_outline),
    _PipelineStep(label: 'LMS Token', phase: 5, icon: Icons.key_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    final progress = widget.progress;
    final stageTitle = progress?.stageTitle ?? 'Automating Authentication';
    final stageIcon = progress?.stageIcon ?? Icons.smart_toy_outlined;
    final displayMessage = progress?.message ??
        widget.fallbackMessage ??
        'Establishing secure connection with SSO Gateway...';

    final currentPhase = progress?.phaseIndex ?? 0;
    final attempt = progress?.attempt;
    final maxAttempts = progress?.maxAttempts ?? 2;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161A22) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: primaryColor.withValues(alpha: isDark ? 0.35 : 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: isDark ? 0.15 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Header Bar: Status Badge, Attempt indicator, and Cancel
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: isDark ? 0.12 : 0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                // Live Blinking Automation Beacon
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF10B981),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withValues(
                              alpha: 0.3 + (_pulseAnimation.value * 0.7),
                            ),
                            blurRadius: 6 * _pulseAnimation.value,
                            spreadRadius: 2 * _pulseAnimation.value,
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                Text(
                  'SSO AUTOMATION',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                  ),
                ),
                const Spacer(),

                // Attempt Pill
                if (attempt != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: progress?.isRetry == true
                          ? Colors.orange.withValues(alpha: 0.2)
                          : primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: progress?.isRetry == true
                            ? Colors.orange.withValues(alpha: 0.5)
                            : primaryColor.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'Attempt $attempt of $maxAttempts',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: progress?.isRetry == true
                            ? (isDark ? const Color(0xFFFFB74D) : const Color(0xFFE65100))
                            : primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                // Cancel Button
                if (widget.onCancel != null)
                  InkWell(
                    onTap: widget.onCancel,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Column(
              children: [
                // Animated Stage Emblem
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    final scale = 1.0 + (_pulseAnimation.value * 0.05);
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              primaryColor,
                              primaryColor.withValues(alpha: 0.75),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withValues(
                                alpha: 0.25 + (_pulseAnimation.value * 0.25),
                              ),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            stageIcon,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),

                // Current Stage Title
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    stageTitle,
                    key: ValueKey(stageTitle),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Live Telemetry Console Message
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0D1117) : const Color(0xFFEDF2F7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '> ',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: primaryColor,
                        ),
                      ),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: Text(
                            displayMessage,
                            key: ValueKey(displayMessage),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              height: 1.35,
                              color: isDark ? const Color(0xFFE6EDF3) : const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Visual Step Progression Pipeline
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(_steps.length, (index) {
                    final step = _steps[index];
                    final isCompleted = currentPhase > step.phase;
                    final isCurrent = currentPhase == step.phase;

                    return Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isCompleted
                                  ? const Color(0xFF10B981)
                                  : isCurrent
                                      ? primaryColor
                                      : (isDark ? const Color(0xFF21262D) : const Color(0xFFE2E8F0)),
                              boxShadow: isCurrent
                                  ? [
                                      BoxShadow(
                                        color: primaryColor.withValues(alpha: 0.4),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Center(
                              child: isCompleted
                                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                                  : Icon(
                                      step.icon,
                                      size: 14,
                                      color: isCurrent
                                          ? Colors.white
                                          : (isDark ? Colors.white38 : Colors.black38),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            step.label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                              color: isCurrent
                                  ? primaryColor
                                  : isCompleted
                                      ? const Color(0xFF10B981)
                                      : (isDark ? Colors.white38 : Colors.black45),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PipelineStep {
  final String label;
  final int phase;
  final IconData icon;

  const _PipelineStep({
    required this.label,
    required this.phase,
    required this.icon,
  });
}
