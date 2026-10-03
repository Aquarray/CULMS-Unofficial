import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Custom bottom navigation bar featuring a scooped curved notch / cradle
/// and an elevated floating circular button for the center Dashboard item.
class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  // Layout constants
  static const double barHeight = 62.0;
  static const double topProtrusion = 26.0;
  static const double buttonDiameter = 62.0;
  static const double notchMargin = 7.5;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final navBg = isDark
        ? (theme.scaffoldBackgroundColor == Colors.black
            ? const Color(0xFF101010)
            : const Color(0xFF1B1E22))
        : Colors.white;

    final borderColor = isDark
        ? const Color(0xFF2A2E35)
        : const Color(0xFFE2E8F0);

    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final totalHeight = topProtrusion + barHeight + bottomPadding;

    return SizedBox(
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. Notched background with soft shadow and top contour border
          Positioned.fill(
            child: CustomPaint(
              painter: _NotchedNavPainter(
                navBgColor: navBg,
                borderColor: borderColor,
                shadowColor: isDark
                    ? Colors.black.withOpacity(0.5)
                    : const Color(0xFF0F172A).withOpacity(0.08),
                barTop: topProtrusion,
                notchCenterY: topProtrusion + 6.0,
                guestRadius: (buttonDiameter / 2) + notchMargin,
              ),
            ),
          ),

          // 2. Navigation items: My Courses (Left) and Settings (Right)
          Positioned(
            top: topProtrusion,
            left: 0,
            right: 0,
            height: barHeight,
            child: Row(
              children: [
                // Left Tab: My Courses
                Expanded(
                  child: Center(
                    child: _NavItem(
                      icon: Icons.school_outlined,
                      activeIcon: Icons.school_rounded,
                      label: 'My Courses',
                      isSelected: currentIndex == 0,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onTabSelected(0);
                      },
                    ),
                  ),
                ),

                // Center gap to let the notch and floating button breathe
                const SizedBox(width: 94),

                // Right Tab: Settings
                Expanded(
                  child: Center(
                    child: _NavItem(
                      icon: Icons.tune_outlined,
                      activeIcon: Icons.tune_rounded,
                      label: 'Settings',
                      isSelected: currentIndex == 2,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onTabSelected(2);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Floating Center Dashboard Button nestled inside the scooped notch
          Positioned(
            top: 2.0,
            left: 0,
            right: 0,
            child: Center(
              child: _FloatingCenterButton(
                diameter: buttonDiameter,
                isSelected: currentIndex == 1,
                onTap: () {
                  HapticFeedback.lightImpact();
                  onTabSelected(1);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter that creates the smooth scooped notch using CircularNotchedRectangle
/// and renders realistic elevation shadow, surface fill, and sleek contour stroke.
class _NotchedNavPainter extends CustomPainter {
  final Color navBgColor;
  final Color borderColor;
  final Color shadowColor;
  final double barTop;
  final double notchCenterY;
  final double guestRadius;

  const _NotchedNavPainter({
    required this.navBgColor,
    required this.borderColor,
    required this.shadowColor,
    required this.barTop,
    required this.notchCenterY,
    required this.guestRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final host = Rect.fromLTWH(0, barTop, size.width, size.height - barTop);
    final guest = Rect.fromCircle(
      center: Offset(size.width / 2, notchCenterY),
      radius: guestRadius,
    );

    // Compute scooped notch path
    final notchedPath = const CircularNotchedRectangle().getOuterPath(host, guest);

    // Optional rounded top corners (18px) for modern pill-card look
    final roundedRect = Path()
      ..addRRect(RRect.fromRectAndCorners(
        host,
        topLeft: const Radius.circular(18),
        topRight: const Radius.circular(18),
      ));
    final finalPath = Path.combine(PathOperation.intersect, notchedPath, roundedRect);

    // 1. Draw smooth elevation shadow following the scooped curve
    canvas.drawShadow(finalPath, shadowColor, 10.0, true);

    // 2. Draw solid surface background
    final fillPaint = Paint()
      ..color = navBgColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(finalPath, fillPaint);

    // 3. Draw subtle border outline along the notched contour
    final strokePaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(finalPath, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _NotchedNavPainter oldDelegate) {
    return oldDelegate.navBgColor != navBgColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.shadowColor != shadowColor ||
        oldDelegate.barTop != barTop ||
        oldDelegate.notchCenterY != notchCenterY ||
        oldDelegate.guestRadius != guestRadius;
  }
}

/// Raised circular button with micro-animations, elevation, and active glow.
class _FloatingCenterButton extends StatefulWidget {
  final double diameter;
  final bool isSelected;
  final VoidCallback onTap;

  const _FloatingCenterButton({
    required this.diameter,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_FloatingCenterButton> createState() => _FloatingCenterButtonState();
}

class _FloatingCenterButtonState extends State<_FloatingCenterButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;

    final buttonBg = isDark
        ? (widget.isSelected ? const Color(0xFF252A32) : const Color(0xFF1E2228))
        : Colors.white;

    final iconColor = widget.isSelected
        ? primaryColor
        : (isDark ? Colors.white70 : const Color(0xFF64748B));

    final rimColor = widget.isSelected
        ? primaryColor.withOpacity(0.25)
        : (isDark ? const Color(0xFF333943) : const Color(0xFFE2E8F0));

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _isPressed ? 0.92 : (widget.isSelected ? 1.04 : 1.0),
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: Container(
          width: widget.diameter,
          height: widget.diameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: buttonBg,
            border: Border.all(color: rimColor, width: 1.5),
            boxShadow: [
              // Primary ambient drop shadow
              BoxShadow(
                color: widget.isSelected
                    ? primaryColor.withOpacity(isDark ? 0.35 : 0.28)
                    : Colors.black.withOpacity(isDark ? 0.45 : 0.12),
                blurRadius: widget.isSelected ? 14 : 10,
                offset: const Offset(0, 5),
              ),
              // Subtle sharp bottom rim shadow for 3D raised elevation
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
              child: Icon(
                Icons.dashboard_rounded,
                key: ValueKey<bool>(widget.isSelected),
                color: iconColor,
                size: widget.isSelected ? 30 : 28,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Navigation item for left/right tabs with subtle micro-interactions.
class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;

    final itemColor = isSelected
        ? primaryColor
        : (isDark ? Colors.white60 : const Color(0xFF64748B));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      splashColor: primaryColor.withOpacity(0.08),
      highlightColor: primaryColor.withOpacity(0.04),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.08 : 1.0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutBack,
              child: Icon(
                isSelected ? activeIcon : icon,
                color: itemColor,
                size: 23,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: itemColor,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
