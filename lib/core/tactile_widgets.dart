import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';

class TactileButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onTapDown;
  final double scaleOnPress;
  final String? semanticLabel;

  const TactileButton({
    Key? key,
    required this.child,
    this.onTap,
    this.onTapDown,
    this.scaleOnPress = 0.95,
    this.semanticLabel,
  }) : super(key: key);

  @override
  _TactileButtonState createState() => _TactileButtonState();
}

class _TactileButtonState extends State<TactileButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleOnPress,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap != null || widget.onTapDown != null) {
      HapticFeedback.mediumImpact();
      _controller.forward();
      widget.onTapDown?.call();
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
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      enabled: widget.onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final scale = _scaleAnimation.value;
            final pressProgress = _controller.value;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateX(-0.05 * pressProgress)
                ..scale(scale),
              child: child,
            );
          },
          child: widget.child,
        ),
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

class GlassContainer extends StatefulWidget {
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
  State<GlassContainer> createState() => _GlassContainerState();
}

class _GlassContainerState extends State<GlassContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _sheenController;

  @override
  void initState() {
    super.initState();
    _sheenController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _sheenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.black : Colors.white;
    final glassColor = baseColor.withValues(alpha: widget.opacity);
    final sheenColor = baseColor.withValues(
      alpha: 0.1,
    ); // Increased slightly for visibility

    return ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.circular(32.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: widget.blur, sigmaY: widget.blur),
        child: AnimatedBuilder(
          animation: _sheenController,
          builder: (context, child) {
            // Animate the alignment for the aurora sheen sweeping effect
            final beginAlignment = AlignmentTween(
              begin: const Alignment(-2.0, -2.0),
              end: const Alignment(2.0, 2.0),
            ).evaluate(_sheenController);

            final endAlignment = AlignmentTween(
              begin: const Alignment(-1.0, -1.0),
              end: const Alignment(3.0, 3.0),
            ).evaluate(_sheenController);

            return Container(
              decoration: BoxDecoration(
                color: glassColor,
                borderRadius:
                    widget.borderRadius ?? BorderRadius.circular(32.0),
                boxShadow: [
                  BoxShadow(
                    color: (isDark ? Colors.white : Colors.black).withValues(
                      alpha: 0.05,
                    ),
                    blurRadius: 1,
                    spreadRadius: 0,
                  ),
                ],
                gradient: LinearGradient(
                  begin: beginAlignment,
                  end: endAlignment,
                  colors: [Colors.transparent, sheenColor, Colors.transparent],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
              child: child,
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}
