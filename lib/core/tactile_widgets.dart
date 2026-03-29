import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';

class TactileButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleOnPress;
  final String? semanticLabel;

  const TactileButton({
    Key? key,
    required this.child,
    this.onTap,
    this.scaleOnPress = 0.95,
    this.semanticLabel,
  }) : super(key: key);

  @override
  _TactileButtonState createState() => _TactileButtonState();
}

class _TactileButtonState extends State<TactileButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scaleOnPress).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap != null) {
      HapticFeedback.mediumImpact();
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onTap != null) {
      _controller.reverse();
      widget.onTap?.call();
    }
  }

  void _onTapCancel() {
    if (widget.onTap != null) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}

class TactileCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? color;
  final double? borderRadius;
  final ShapeBorder? shape;

  const TactileCard({
    Key? key,
    required this.child,
    this.padding,
    this.color,
    this.borderRadius,
    this.shape,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).cardColor;
    final effectiveShadow = [
      BoxShadow(
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
        blurRadius: 40,
        offset: const Offset(0, 4),
      ),
    ];

    return Container(
      padding: padding,
      decoration: shape != null 
          ? ShapeDecoration(
              color: effectiveColor,
              shape: shape!,
              shadows: effectiveShadow,
            )
          : BoxDecoration(
              color: effectiveColor,
              borderRadius: BorderRadius.circular(borderRadius ?? 32.0),
              boxShadow: effectiveShadow,
            ),
      child: child,
    );
  }
}

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final BorderRadius? borderRadius;

  const GlassContainer({
    Key? key,
    required this.child,
    this.blur = 12.0,
    this.opacity = 0.7,
    this.borderRadius,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glassColor = isDark ? Colors.black.withOpacity(opacity) : Colors.white.withOpacity(opacity);

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(32.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: glassColor,
            borderRadius: borderRadius ?? BorderRadius.circular(32.0),
            boxShadow: [
              BoxShadow(
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                blurRadius: 1,
                spreadRadius: 0,
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
