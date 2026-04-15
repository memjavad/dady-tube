import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/tactile_widgets.dart';
import '../core/theme.dart';
import '../providers/usage_provider.dart';
import '../core/app_localizations.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final usage = context.watch<UsageProvider>();
    final currentMonth = DateTime.now().month;
    final monthName = _getMonthName(currentMonth, loc);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, loc, monthName),
              const SizedBox(height: 24),
              // Small summary for parents
              Center(
                child: Text(
                  '${usage.monthlyStars} ${loc.translate('magic_stars')}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(
                color: Colors.pinkAccent,
                thickness: 1,
                indent: 40,
                endIndent: 40,
              ),
              const SizedBox(height: 16),
              Expanded(child: _buildStarField(context, usage.monthlyStars)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AppLocalizations loc,
    String monthName,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          loc.translate('achievements'),
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            color: DadyTubeTheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${loc.translate('monthly_collection')} - $monthName',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildStarField(BuildContext context, int stars) {
    if (stars == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              size: 80,
              color: Colors.grey.withOpacity(0.2),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).translate('no_stars_yet'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 80),
      child: Center(
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: List.generate(stars, (index) {
            return _StarSlot(index: index + 1);
          }),
        ),
      ),
    );
  }

  String _getMonthName(int month, AppLocalizations loc) {
    return loc.translate('month_$month');
  }
}

class _StarSlot extends StatefulWidget {
  final int index;

  const _StarSlot({required this.index});

  @override
  State<_StarSlot> createState() => _StarSlotState();
}

class _StarSlotState extends State<_StarSlot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isTapped = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTap() {
    setState(() => _isTapped = true);
    _controller.forward().then((_) => _controller.reverse());
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    return TactileButton(
      onTap: _onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(_isTapped ? 0.3 : 0.2),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(Icons.stars_rounded, color: Colors.amber, size: 48),
              Positioned(
                bottom: 8,
                child: Text(
                  '${widget.index}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
