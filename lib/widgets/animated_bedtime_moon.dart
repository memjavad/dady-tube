import 'dart:math';
import 'package:flutter/material.dart';

class AnimatedBedtimeMoon extends StatefulWidget {
  const AnimatedBedtimeMoon({super.key});

  @override
  State<AnimatedBedtimeMoon> createState() => _AnimatedBedtimeMoonState();
}

class _AnimatedBedtimeMoonState extends State<AnimatedBedtimeMoon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: sin(_controller.value * pi * 2) * 0.1,
          child: CustomPaint(
            size: const Size(120, 120),
            painter: MoonPainter(_controller.value),
          ),
        );
      },
    );
  }
}

class MoonPainter extends CustomPainter {
  final double animationValue;
  MoonPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2.5;

    final paint = Paint()
      ..color = Colors.yellow.shade200
      ..style = PaintingStyle.fill;

    // The Moon
    canvas.drawCircle(center, radius, paint);

    // The "Crescent" cut-out (animated slightly)
    final shadowPaint = Paint()
      ..color = const Color(0xFF2D1B4E) // Matches Bedtime Background
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(center.dx + radius * 0.4 + sin(animationValue * pi) * 2, center.dy - radius * 0.2),
      radius,
      shadowPaint,
    );

    // Sleepy eyes
    final eyePaint = Paint()
      ..color = Colors.black26
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final eyeLeft = Offset(center.dx - 10, center.dy);
    final eyeRight = Offset(center.dx + 5, center.dy + 5);

    canvas.drawArc(
      Rect.fromCenter(center: eyeLeft, width: 10, height: 10),
      0,
      pi,
      false,
      eyePaint,
    );

    canvas.drawArc(
      Rect.fromCenter(center: eyeRight, width: 10, height: 10),
      0,
      pi,
      false,
      eyePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
