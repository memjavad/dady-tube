import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../core/theme.dart';
import '../core/tactile_widgets.dart';

class ShimmerVideoCard extends StatelessWidget {
  const ShimmerVideoCard({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: colorScheme.surfaceContainerLow,
      highlightColor: colorScheme.surface.withOpacity(0.5),
      child: TactileCard(
        padding: EdgeInsets.zero,
        borderRadius: 32,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 20,
                    width: double.infinity,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 8),
                  Container(height: 20, width: 150, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
