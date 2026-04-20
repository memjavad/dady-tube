import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/usage_provider.dart';
import '../core/app_localizations.dart';
import '../core/theme.dart';
import '../core/tactile_widgets.dart';

class BreakTimerOverlay extends StatelessWidget {
  const BreakTimerOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final usage = context.watch<UsageProvider>();
    if (!usage.isBreakActive) return const SizedBox.shrink();

    final loc = AppLocalizations.of(context);
    final countdown = usage.breakCountdown;
    
    // Determine which activity image to show based on countdown
    // 30-21: Look Far, 20-11: Blink, 10-0: Stretch
    String activityImage = 'assets/images/eye_yoga_look_far.png';
    String activityTitle = 'activity_1_title';
    if (countdown <= 10) {
      activityImage = 'assets/images/eye_yoga_stretch.png';
      activityTitle = 'activity_3_title';
    } else if (countdown <= 20) {
      activityImage = 'assets/images/eye_yoga_blink.png';
      activityTitle = 'activity_2_title';
    }

    return PopScope(
      canPop: false, // MANDATORY: Non-skippable
      child: Material(
        color: Colors.white,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                const Color(0xFFFFF5F7), // Soft Blush Base
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   // Rabbit Icon / Logo
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: DadyTubeTheme.primary,
                    size: 48,
                  ),
                  const SizedBox(height: 24),
                  
                  Text(
                    loc.translate('blink_break_title'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: DadyTubeTheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Eye Yoga Activity Image
                  Expanded(
                    child: TactileCard(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Image.asset(
                          activityImage,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  Text(
                    loc.translate(activityTitle),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  
                  const SizedBox(height: 48),
                  
                  // Countdown UI
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: CircularProgressIndicator(
                          value: countdown / 30,
                          strokeWidth: 12,
                          backgroundColor: DadyTubeTheme.primary.withOpacity(0.1),
                          valueColor: const AlwaysStoppedAnimation(DadyTubeTheme.primary),
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "$countdown",
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: DadyTubeTheme.primary,
                            ),
                          ),
                          Text(
                            loc.translate('seconds'),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  
                  Text(
                    loc.translate('back_to_fun'),
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
