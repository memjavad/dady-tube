import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class FallingStarsBackground extends StatefulWidget {
  final Widget child;
  const FallingStarsBackground({super.key, required this.child});

  @override
  State<FallingStarsBackground> createState() => _FallingStarsBackgroundState();
}

class _FallingStarsBackgroundState extends State<FallingStarsBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<TwinklingStar> _twinklingStars = [];
  final List<ShootingStar> _shootingStars = [];
  final Random _random = Random();
  double _lastSpawnTime = 0.0;

  @override
  void initState() {
    super.initState();
    
    // Generate background stars
    for (int i = 0; i < 45; i++) {
      _twinklingStars.add(TwinklingStar(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: _random.nextDouble() * 2.0 + 0.8,
        twinkleSpeed: _random.nextDouble() * 1.5 + 0.4,
        twinkleOffset: _random.nextDouble() * pi * 2,
      ));
    }

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateParticles() {
    final currentTime = _controller.value * 10.0; // 0 to 10 seconds
    double timeDiff = currentTime - _lastSpawnTime;
    if (timeDiff < 0) timeDiff += 10.0;

    // Spawn a shooting star occasionally
    if (timeDiff > 2.0 && _shootingStars.length < 2 && _random.nextDouble() < 0.02) {
      _lastSpawnTime = currentTime;
      _shootingStars.add(ShootingStar(
        startX: _random.nextDouble() * 0.7, // spawn left half
        startY: _random.nextDouble() * 0.35, // spawn top portion
        length: _random.nextDouble() * 100 + 70,
        speed: _random.nextDouble() * 8 + 10,
        angle: (20 + _random.nextDouble() * 20) * pi / 180, // diagonal angle
      ));
    }

    // Update existing shooting stars
    for (int i = _shootingStars.length - 1; i >= 0; i--) {
      final star = _shootingStars[i];
      star.update();
      if (star.opacity <= 0.0) {
        _shootingStars.removeAt(i);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        _updateParticles();
        return RepaintBoundary(
          child: CustomPaint(
            painter: StarFieldPainter(
              twinklingStars: _twinklingStars,
              shootingStars: List.from(_shootingStars),
              animationValue: _controller.value,
            ),
            child: widget.child,
          ),
        );
      },
    );
  }
}

class TwinklingStar {
  final double x;
  final double y;
  final double size;
  final double twinkleSpeed;
  final double twinkleOffset;

  TwinklingStar({
    required this.x,
    required this.y,
    required this.size,
    required this.twinkleSpeed,
    required this.twinkleOffset,
  });

  double getOpacity(double animValue) {
    final waveValue = sin(animValue * pi * 2 * twinkleSpeed + twinkleOffset);
    return 0.25 + (waveValue + 1.0) / 2.0 * 0.75;
  }
}

class ShootingStar {
  double currentX;
  double currentY;
  final double speed;
  final double angle;
  final double length;
  double opacity = 1.0;
  final List<Offset> path = [];

  ShootingStar({
    required double startX,
    required double startY,
    required this.speed,
    required this.angle,
    required this.length,
  })  : currentX = startX,
        currentY = startY {
    path.add(Offset(currentX, currentY));
  }

  void update() {
    final dx = cos(angle) * speed;
    final dy = sin(angle) * speed;
    
    currentX += dx / 800.0;
    currentY += dy / 800.0;

    path.add(Offset(currentX, currentY));
    if (path.length > 7) {
      path.removeAt(0);
    }

    opacity -= 0.038; // fade out speed
    if (opacity < 0.0) opacity = 0.0;
  }
}

class StarFieldPainter extends CustomPainter {
  final List<TwinklingStar> twinklingStars;
  final List<ShootingStar> shootingStars;
  final double animationValue;

  StarFieldPainter({
    required this.twinklingStars,
    required this.shootingStars,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final starPaint = Paint()..style = PaintingStyle.fill;

    // 1. Draw twinkling stars
    for (var star in twinklingStars) {
      final opacity = star.getOpacity(animationValue);
      starPaint.color = Colors.white.withValues(alpha: opacity);
      
      final dx = star.x * size.width;
      final dy = star.y * size.height;
      canvas.drawCircle(Offset(dx, dy), star.size, starPaint);
    }

    // 2. Draw shooting stars with trailing lines
    for (var star in shootingStars) {
      if (star.path.length < 2) continue;

      final startOffset = Offset(star.path.first.dx * size.width, star.path.first.dy * size.height);
      final endOffset = Offset(star.currentX * size.width, star.currentY * size.height);

      final trailPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..shader = ui.Gradient.linear(
          startOffset,
          endOffset,
          [
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: star.opacity * 0.35),
            Colors.white.withValues(alpha: star.opacity),
          ],
          [0.0, 0.6, 1.0],
        );

      canvas.drawLine(startOffset, endOffset, trailPaint);

      // Star head glow aura
      final auraPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.white.withValues(alpha: star.opacity * 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawCircle(endOffset, 6.0, auraPaint);

      // Bright star head
      final headPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.white.withValues(alpha: star.opacity);
      canvas.drawCircle(endOffset, 2.5, headPaint);
    }
  }

  @override
  bool shouldRepaint(covariant StarFieldPainter oldDelegate) => true;
}
