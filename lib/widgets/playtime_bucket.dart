import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/usage_provider.dart';
import '../core/theme.dart';

class PlaytimeBucket extends StatefulWidget {
  final double size;
  final Axis axis;
  const PlaytimeBucket({super.key, this.size = 80, this.axis = Axis.horizontal});

  @override
  State<PlaytimeBucket> createState() => _PlaytimeBucketState();
}

class _PlaytimeBucketState extends State<PlaytimeBucket> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
       vsync: this,
       duration: const Duration(seconds: 1),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UsageProvider>(
      builder: (context, usage, child) {
        final progress = usage.progress; // 0.0 (full) to 1.0 (empty)
        final activeBars = (12 * (1.0 - progress)).ceil().clamp(0, 12);
        
        // Pulse when getting low (3 or fewer bars, but not 0)
        if (activeBars > 0 && activeBars <= 3) {
           if (!_pulseController.isAnimating) _pulseController.repeat(reverse: true);
        } else {
           if (_pulseController.isAnimating) {
               _pulseController.stop();
               _pulseController.value = 0.0;
           }
        }

        final List<Color> barColors = [
          const Color(0xFFF44336), // Red
          const Color(0xFFFF5722), // Deep Orange
          const Color(0xFFFF9800), // Orange
          const Color(0xFFFFC107), // Amber
          const Color(0xFFFFEB3B), // Yellow
          const Color(0xFFCDDC39), // Lime
          const Color(0xFF8BC34A), // Light Green
          const Color(0xFF4CAF50), // Green
          const Color(0xFF009688), // Teal
          const Color(0xFF00BCD4), // Cyan
          const Color(0xFF03A9F4), // Light Blue
          const Color(0xFF2196F3), // Blue
        ].reversed.toList();

        final isVertical = widget.axis == Axis.vertical;

        return AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final scaleStr = 1.0 + (_pulseController.value * 0.05); // Bounce up to 5% larger
            return Transform.scale(
              scale: scaleStr,
              child: SizedBox(
                width: isVertical ? widget.size * 0.8 : double.infinity,
                height: isVertical ? widget.size * 2.5 : widget.size * 0.5,
                child: Flex(
                  direction: widget.axis,
                  mainAxisAlignment: isVertical ? MainAxisAlignment.end : MainAxisAlignment.start,
                  children: List.generate(12, (index) {
                    final barIndex = isVertical ? (11 - index) : index;
                    final isActive = barIndex < activeBars;
                    final color = barColors[barIndex % barColors.length];
                    
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: isVertical ? 2 : 3,
                          horizontal: isVertical ? 3 : 2,
                        ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.elasticOut,
                          width: isVertical ? (isActive ? (widget.size * 0.8) : 12) : double.infinity,
                          height: !isVertical ? (widget.size * 0.4) : (isActive ? (widget.size * 0.8) : 12),
                          decoration: BoxDecoration(
                            color: isActive ? color : color.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(widget.size * 0.1),
                            gradient: isActive ? LinearGradient(
                              begin: isVertical ? Alignment.centerLeft : Alignment.topCenter,
                              end: isVertical ? Alignment.centerRight : Alignment.bottomCenter,
                              colors: [
                                color.withOpacity(0.8),
                                color,
                                color.withOpacity(0.9),
                              ],
                            ) : null,
                            boxShadow: isActive ? [
                              BoxShadow(
                                color: color.withOpacity(0.4 + (_pulseController.value * 0.3)), // Shadow pulses too
                                blurRadius: 6 + (_pulseController.value * 6),
                                offset: const Offset(1, 1),
                              ),
                            ] : [],
                          ),
                          child: isActive ? Container(
                            margin: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ) : null,
                        ),
                      ),
                    );
                  }),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
