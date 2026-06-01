import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'theme.dart';

class TactileButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onTapDown;
  final double scaleOnPress;
  final String? semanticLabel;

  const TactileButton({
    super.key,
    required this.child,
    this.onTap,
    this.onTapDown,
    this.scaleOnPress = 0.95,
    this.semanticLabel,
  });

  @override
  State<TactileButton> createState() => _TactileButtonState();
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
                ..scaleByDouble(scale, scale, 1.0, 1.0),
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
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.borderRadius,
    this.shape,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).cardColor;
    final tokens = DadyTubeTheme.tokens(context);
    // Zero-Line Policy: Use tonal shadow layering instead of Border.all
    final effectiveShadow = [
      BoxShadow(
        color: tokens.cardShadow,
        blurRadius: 28,
        offset: const Offset(0, 10),
      ),
      // Subtle inner-edge glow replaces the old border line
      BoxShadow(
        color: tokens.cardBorder.withValues(alpha: 0.18),
        blurRadius: 1,
        spreadRadius: 0.5,
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
              // Zero-Line Policy: No Border.all — tonal shadow replaces border
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
    super.key,
    required this.child,
    this.blur = 12.0,
    this.opacity = 0.7,
    this.borderRadius,
  });

  @override
  State<GlassContainer> createState() => _GlassContainerState();
}

class _GlassContainerState extends State<GlassContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _sheenController;

  @override
  void initState() {
    super.initState();
    // Dynamic Aurora Sheen: Continuously sweeps the reflection gradient
    _sheenController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
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
    final tokens = DadyTubeTheme.tokens(context);
    final baseColor = isDark ? Colors.black : Colors.white;
    final glassColor = Color.lerp(
      baseColor,
      tokens.glassTint,
      0.75,
    )!.withValues(alpha: widget.opacity);
    final sheenColor = baseColor.withValues(alpha: 0.08);

    return ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.circular(32.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: widget.blur, sigmaY: widget.blur),
        child: AnimatedBuilder(
          animation: _sheenController,
          child: widget.child,
          builder: (context, animChild) {
            // Dynamic sweep: sheen moves from top-left to bottom-right
            final sweepValue = _sheenController.value;
            final startX = -1.0 + (sweepValue * 3.0);
            final startY = -1.0 + (sweepValue * 3.0);
            final endX = startX + 1.0;
            final endY = startY + 1.0;

            return Container(
              decoration: BoxDecoration(
                color: glassColor,
                borderRadius:
                    widget.borderRadius ?? BorderRadius.circular(32.0),
                // Zero-Line Policy: No Border.all — tonal shadow replaces border
                boxShadow: [
                  BoxShadow(
                    color: tokens.cardShadow
                        .withValues(alpha: isDark ? 0.55 : 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                  // Subtle edge glow replacing old Border.all
                  BoxShadow(
                    color: tokens.cardBorder
                        .withValues(alpha: isDark ? 0.25 : 0.35),
                    blurRadius: 1,
                    spreadRadius: 0.5,
                  ),
                ],
                gradient: LinearGradient(
                  begin: Alignment(startX.clamp(-1.0, 1.0), startY.clamp(-1.0, 1.0)),
                  end: Alignment(endX.clamp(-1.0, 1.0), endY.clamp(-1.0, 1.0)),
                  colors: [
                    Colors.transparent,
                    sheenColor,
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
              child: animChild,
            );
          },
        ),
      ),
    );
  }
}
