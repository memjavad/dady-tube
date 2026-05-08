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
    final tokens = DadyTubeTheme.tokens(context);
    final effectiveShadow = [
      BoxShadow(
        color: tokens.cardShadow,
        blurRadius: 28,
        offset: const Offset(0, 10),
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
              border: Border.all(color: tokens.cardBorder.withOpacity(0.8)),
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
    final tokens = DadyTubeTheme.tokens(context);
    final baseColor = isDark ? Colors.black : Colors.white;
    final glassColor = Color.lerp(
      baseColor,
      tokens.glassTint,
      0.75,
    )!.withValues(alpha: opacity);
    final sheenColor = baseColor.withValues(
      alpha: 0.05,
    ); // Very subtle static reflection

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(32.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: glassColor,
            borderRadius: borderRadius ?? BorderRadius.circular(32.0),
            border: Border.all(
              color: tokens.cardBorder.withValues(alpha: isDark ? 0.55 : 0.8),
            ),
            boxShadow: [
              BoxShadow(
                color: tokens.cardShadow.withValues(alpha: isDark ? 0.55 : 0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [sheenColor, Colors.transparent, sheenColor],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
