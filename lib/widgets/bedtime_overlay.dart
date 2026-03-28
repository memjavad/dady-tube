import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'animated_bedtime_moon.dart';
import '../providers/usage_provider.dart';
import '../core/tactile_widgets.dart';
import '../core/theme.dart';
import '../screens/parental_gate.dart';
import '../core/app_localizations.dart';

class BedtimeOverlay extends StatelessWidget {
  final Widget child;
  const BedtimeOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final usage = context.watch<UsageProvider>();

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor, // Fundamental opaque background for the stack
      child: Stack(
        children: [
          // Standard app content
          AnimatedOpacity(
            opacity: usage.isBedtime ? 0.3 : 1.0,
            duration: const Duration(seconds: 2),
            child: IgnorePointer(
              ignoring: usage.isBedtime,
              child: child,
            ),
          ),

          // Bedtime Screen
          if (usage.isBedtime)
            _buildBedtimeContent(context, usage),
        ],
      ),
    );
  }

  Widget _buildBedtimeContent(BuildContext context, UsageProvider usage) {
    final loc = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF4A148C).withOpacity(0.9), // Deep Purple
            const Color(0xFFE91E63).withOpacity(0.8), // Elegant Pink
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             _buildAnimatedMoon(),
            const SizedBox(height: 32),
            Text(
              loc.translate('bedtime_title'),
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                loc.translate('bedtime_msg'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 18),
              ),
            ),
            const SizedBox(height: 64),
            TactileButton(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ParentalGate(
                      destination: _ExtraTimeDialog(usage: usage),
                    ),
                  ),
                );
              },
              child: TactileCard(
                color: Colors.white.withOpacity(0.2),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Icon(Icons.vpn_key_rounded, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedMoon() {
    return const AnimatedBedtimeMoon();
  }
}

class _ExtraTimeDialog extends StatelessWidget {
  final UsageProvider usage;
  const _ExtraTimeDialog({required this.usage});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(loc.translate('add_playtime'))),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(loc.translate('grant_extra_time'), style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTimeButton(context, 5, loc),
                const SizedBox(width: 16),
                _buildTimeButton(context, 15, loc),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeButton(BuildContext context, int mins, AppLocalizations loc) {
    return TactileButton(
      onTap: () {
        usage.grantExtraTime(mins);
        Navigator.pop(context);
      },
      child: TactileCard(
        color: Theme.of(context).colorScheme.primary,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          child: Text(
            loc.translate('plus_mins', args: {'min': mins.toString()}),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
