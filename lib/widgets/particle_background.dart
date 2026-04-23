import 'dart:math';
import 'package:flutter/material.dart';

class ParticleBackground extends StatefulWidget {
  final Widget child;
  final Color? overrideColor;
  const ParticleBackground({
    super.key,
    required this.child,
    this.overrideColor,
  });

  @override
  State<ParticleBackground> createState() => _ParticleBackgroundState();
}

class _ParticleBackgroundState extends State<ParticleBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Particle> _particles = List.generate(6, (index) => Particle());

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final targetColor = widget.overrideColor ?? theme.colorScheme.primary;

    // ⚡ Bolt: Pass down child to prevent unnecessary rebuilds inside animations
    return Container(
      color: theme.scaffoldBackgroundColor,
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: targetColor),
        duration: const Duration(milliseconds: 800),
        child: widget.child,
        builder: (context, color, tweenChild) {
          return AnimatedBuilder(
            animation: _controller,
            child: tweenChild,
            builder: (context, animChild) {
              for (var particle in _particles) {
                particle.update();
              }
              return RepaintBoundary(
                child: CustomPaint(
                  painter: ParticlePainter(
                    _particles,
                    color ?? theme.colorScheme.primary,
                  ),
                  child: animChild,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class Particle {
  double x = Random().nextDouble();
  double y = Random().nextDouble();
  double size = Random().nextDouble() * 40 + 20;
  double speed = Random().nextDouble() * 0.001 + 0.0005;
  double opacity = Random().nextDouble() * 0.1 + 0.05;

  void update() {
    y -= speed;
    if (y < -0.1) {
      y = 1.1;
      x = Random().nextDouble();
    }
  }
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final Color particleColor;
  ParticlePainter(this.particles, this.particleColor);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var particle in particles) {
      paint.color = particleColor.withOpacity(particle.opacity);
      canvas.drawCircle(
        Offset(particle.x * size.width, particle.y * size.height),
        particle.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
