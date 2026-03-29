import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/usage_provider.dart';
import '../core/theme.dart';

class PlaytimeBucket extends StatelessWidget {
  final double size;
  const PlaytimeBucket({super.key, this.size = 80});

  @override
  Widget build(BuildContext context) {
    return Consumer<UsageProvider>(
      builder: (context, usage, child) {
        final progress = usage.progress; // 0.0 (full) to 1.0 (empty)
        final activeBars = (12 * (1.0 - progress)).ceil().clamp(0, 12);

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
        ].reversed.toList(); // Reverse so Blue is at top (full)

        return SizedBox(
          width: size * 0.8,
          height: size * 2.5,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: List.generate(12, (index) {
              // Index 0 is at bottom of Column due to mainAxisAlignment: end
              // But we want Index 0 to be the first to disappear (bottom) or last (top)?
              // Let's say index 0 is top (last to disappear).
              final barIndex = 11 - index; // 11 at top, 0 at bottom
              final isActive = barIndex < activeBars;
              final color = barColors[barIndex % barColors.length];

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.elasticOut,
                    width: isActive ? (size * 0.8) : 12,
                    decoration: BoxDecoration(
                      color: isActive ? color : color.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(size * 0.2),
                      gradient: isActive
                          ? LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                color.withOpacity(0.8),
                                color,
                                color.withOpacity(0.9),
                              ],
                            )
                          : null,
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: color.withOpacity(0.4),
                                blurRadius: 6,
                                offset: const Offset(2, 2),
                              ),
                            ]
                          : [],
                    ),
                    child: isActive
                        ? Container(
                            margin: const EdgeInsets.all(3),
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          )
                        : null,
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
