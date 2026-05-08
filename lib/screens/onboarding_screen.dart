import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../core/app_localizations.dart';
import '../core/tactile_widgets.dart';
import '../core/theme.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = DadyTubeTheme.tokens(context);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: DadyTubeTheme.background,
      body: Stack(
        children: [
          // Background Gradient blobs
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: DadyTubeTheme.primary.withValues(alpha: 0.1),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tokens.accentStrong.withValues(alpha: 0.1),
              ),
            ),
          ),

          PageView(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index),
            children: [
              _buildWelcomeSlide(l10n, tokens, textTheme),
              _buildFeaturesSlide(l10n, tokens, textTheme),
              _buildSettingsSlide(l10n, tokens, textTheme),
            ],
          ),

          // Bottom Navigation
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) => _buildDot(index, tokens)),
                ),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TactileButton(
                    onTap: _onNext,
                    child: Container(
                      height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: DadyTubeTheme.primary,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: DadyTubeTheme.primary.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Text(
                        _currentPage == 2 ? l10n.translate('onboarding_start') : l10n.translate('play'),
                        style: textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onNext() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutQuart,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _finishOnboarding() async {
    await context.read<SettingsProvider>().completeOnboarding();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  Widget _buildDot(int index, DadyTubeThemeTokens tokens) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: _currentPage == index ? 24 : 10,
      height: 10,
      decoration: BoxDecoration(
        color: _currentPage == index ? DadyTubeTheme.primary : DadyTubeTheme.primary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(5),
      ),
    );
  }

  Widget _buildWelcomeSlide(AppLocalizations l10n, DadyTubeThemeTokens tokens, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Hero(
            tag: 'logo',
            child: Image.asset(
              'assets/images/logo.png',
              height: 180,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.play_circle_fill, size: 100, color: DadyTubeTheme.primary),
            ),
          ),
          const SizedBox(height: 40),
          Text(
            l10n.translate('onboarding_welcome'),
            textAlign: TextAlign.center,
            style: textTheme.displaySmall?.copyWith(fontSize: 32),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.translate('onboarding_author'),
            textAlign: TextAlign.center,
            style: textTheme.bodyLarge?.copyWith(
              color: DadyTubeTheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesSlide(AppLocalizations l10n, DadyTubeThemeTokens tokens, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildIconCard('assets/images/animals_icon_3d.png', tokens),
              const SizedBox(width: 16),
              _buildIconCard('assets/images/music_icon_3d.png', tokens),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildIconCard('assets/images/toys_icon_3d.png', tokens),
              const SizedBox(width: 16),
              _buildIconCard('assets/images/learning_icon_3d.png', tokens),
            ],
          ),
          const SizedBox(height: 40),
          Text(
            l10n.translate('onboarding_features_title'),
            textAlign: TextAlign.center,
            style: textTheme.displaySmall?.copyWith(fontSize: 28),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.translate('onboarding_features_desc'),
            textAlign: TextAlign.center,
            style: textTheme.bodyLarge?.copyWith(fontSize: 18, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSlide(AppLocalizations l10n, DadyTubeThemeTokens tokens, TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Icon(
              Icons.security_rounded,
              size: 100,
              color: DadyTubeTheme.primary,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            l10n.translate('onboarding_settings_title'),
            textAlign: TextAlign.center,
            style: textTheme.displaySmall?.copyWith(fontSize: 28),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.translate('onboarding_settings_desc'),
            textAlign: TextAlign.center,
            style: textTheme.bodyLarge?.copyWith(fontSize: 18, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildIconCard(String asset, DadyTubeThemeTokens tokens) {
    return Container(
      width: 100,
      height: 100,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Image.asset(
        asset,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.star, size: 40, color: Colors.amber),
      ),
    );
  }
}
