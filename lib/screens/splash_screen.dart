import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/channel_provider.dart';
import '../core/app_localizations.dart';
import '../core/theme.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';
import '../providers/settings_provider.dart';

import '../widgets/particle_background.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutBack),
      ),
    );

    _controller.forward();
  }

  void _navigateToHome() {
    if (_isNavigating) return;
    _isNavigating = true;

        final settings = context.read<SettingsProvider>();
    final destination = settings.isFirstRun ? const OnboardingScreen() : const HomeScreen();

    Navigator.pushReplacement(

      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            destination,

        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = DadyTubeTheme.tokens(context);
    return Scaffold(
      body: ParticleBackground(
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 180,
                        height: 180,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Theme.of(context).colorScheme.surface,
                              tokens.accentSoft,
                            ],
                          ),
                          shape: BoxShape.circle,
                          // Zero-Line Policy: tonal shadow replaces Border.all
                          boxShadow: [
                            BoxShadow(
                              color: tokens.cardShadow.withValues(alpha: 0.7),
                              blurRadius: 36,
                              offset: const Offset(0, 18),
                            ),
                            BoxShadow(
                              color: tokens.cardBorder.withValues(alpha: 0.3),
                              blurRadius: 1,
                              spreadRadius: 0.5,
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(30),
                          child: Image.asset('assets/images/logo.png'),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'DadyTube',
                        style: Theme.of(context).textTheme.displayMedium
                            ?.copyWith(
                              color: DadyTubeTheme.primary,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        AppLocalizations.of(
                          context,
                        ).translate('author_credit'),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: DadyTubeTheme.primary.withValues(alpha: 0.75),
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 48),
                      // Tactile Progress Bar
                      Consumer<ChannelProvider>(
                        builder: (context, provider, child) {
                          // Check if initialized and at least 2 seconds passed for logo animation
                          if (provider.isInitialized &&
                              _controller.isCompleted) {
                            WidgetsBinding.instance.addPostFrameCallback(
                              (_) => _navigateToHome(),
                            );
                          }

                          return Column(
                            children: [
                              Container(
                                width: 240,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: tokens.accentSoft.withValues(alpha: 0.95),
                                  borderRadius: BorderRadius.circular(
                                    DadyTubeTheme.borderRadiusFull,
                                  ),
                                  // Zero-Line Policy: tonal shadow replaces Border.all
                                  boxShadow: [
                                    BoxShadow(
                                      color: tokens.cardBorder.withValues(alpha: 0.3),
                                      blurRadius: 1,
                                      spreadRadius: 0.5,
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  children: [
                                    AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      width: 240 * provider.initProgress,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            tokens.accentStrong,
                                            tokens.highlight,
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          DadyTubeTheme.borderRadiusFull,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: DadyTubeTheme.primary
                                                .withValues(alpha: 0.4),
                                            blurRadius: 10,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                style:
                                    Theme.of(
                                      context,
                                    ).textTheme.bodyMedium?.copyWith(
                                      color: DadyTubeTheme.primary.withValues(
                                        alpha: 0.7,
                                      ),
                                      fontWeight: FontWeight.w600,
                                    ) ??
                                    const TextStyle(),
                                child: Text(
                                  AppLocalizations.of(context).translate(
                                    provider.initStatusKey,
                                    args: provider.initStatusArg.isNotEmpty
                                        ? {'name': provider.initStatusArg}
                                        : null,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
