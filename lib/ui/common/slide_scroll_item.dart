import 'package:flutter/material.dart';

enum SlideDirection {
  up,
  down,
  left,
  right,
}

/// A smooth, high-performance slide, fade, and micro-scale animation wrapper
/// that animates items as they appear and scroll into view.
class SlideScrollItem extends StatefulWidget {
  final Widget child;
  final int index;
  final SlideDirection direction;
  final Duration duration;
  final double slideOffset;
  final bool enableScale;
  final Curve curve;

  const SlideScrollItem({
    super.key,
    required this.child,
    this.index = 0,
    this.direction = SlideDirection.up,
    this.duration = const Duration(milliseconds: 340),
    this.slideOffset = 24.0,
    this.enableScale = true,
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<SlideScrollItem> createState() => _SlideScrollItemState();
}

class _SlideScrollItemState extends State<SlideScrollItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    Offset startOffset;
    switch (widget.direction) {
      case SlideDirection.up:
        startOffset = Offset(0, widget.slideOffset / 100);
        break;
      case SlideDirection.down:
        startOffset = Offset(0, -widget.slideOffset / 100);
        break;
      case SlideDirection.left:
        startOffset = Offset(widget.slideOffset / 100, 0);
        break;
      case SlideDirection.right:
        startOffset = Offset(-widget.slideOffset / 100, 0);
        break;
    }

    final curved = CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    );

    _slideAnimation = Tween<Offset>(
      begin: startOffset,
      end: Offset.zero,
    ).animate(curved);

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.75, curve: Curves.easeOut),
    ));

    _scaleAnimation = Tween<double>(
      begin: widget.enableScale ? 0.96 : 1.0,
      end: 1.0,
    ).animate(curved);

    // Stagger initial items slightly so they cascade smoothly.
    // For items scrolled in later, animate immediately without delay.
    final delayMs = widget.index <= 5 ? (widget.index * 30) : 0;
    if (delayMs > 0) {
      Future.delayed(Duration(milliseconds: delayMs), () {
        if (mounted) {
          _controller.forward();
        }
      });
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: widget.child,
        ),
      ),
    );
  }
}
