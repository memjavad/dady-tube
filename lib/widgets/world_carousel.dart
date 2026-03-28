import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/tactile_widgets.dart';

class WorldCarousel extends StatefulWidget {
  final List<WorldItem> items;
  final Function(String) onWorldSelected;
  final String selectedWorld;

  const WorldCarousel({
    super.key,
    required this.items,
    required this.onWorldSelected,
    required this.selectedWorld,
  });

  @override
  State<WorldCarousel> createState() => _WorldCarouselState();
}

class _WorldCarouselState extends State<WorldCarousel> {
  late PageController _pageController;
  double _currentPage = 0.0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.6)
      ..addListener(() {
        setState(() {
          _currentPage = _pageController.page!;
        });
      });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 250,
      child: PageView.builder(
        controller: _pageController,
        itemCount: widget.items.length,
        itemBuilder: (context, index) {
          final item = widget.items[index];
          final isSelected = widget.selectedWorld == item.name;
          
          // Calculate 3D transformation
          double relativePosition = index - _currentPage;
          double scale = (1 - relativePosition.abs() * 0.2).clamp(0.8, 1.0);
          double opacity = (1 - relativePosition.abs() * 0.5).clamp(0.4, 1.0);
          double rotation = relativePosition * 0.2; // Perspective tilt

          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // Perspective
              ..scale(scale)
              ..rotateY(rotation),
            alignment: Alignment.center,
            child: Opacity(
              opacity: opacity,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: TactileButton(
                  onTap: () => widget.onWorldSelected(item.name),
                  child: TactileCard(
                    color: isSelected ? item.color.withOpacity(0.2) : Theme.of(context).cardTheme.color,
                    padding: const EdgeInsets.all(24),
                    borderRadius: 40,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: item.color.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: item.isMaterial 
                            ? Icon(item.icon as IconData, size: 56, color: item.color)
                            : Image.asset(item.icon as String, width: 80, height: 80),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          item.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class WorldItem {
  final String name;
  final dynamic icon;
  final Color color;
  final bool isMaterial;

  WorldItem({required this.name, required this.icon, required this.color, this.isMaterial = false});
}
