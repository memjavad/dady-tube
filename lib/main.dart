import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/app_localizations.dart';
import 'core/theme.dart';
import 'providers/channel_provider.dart';
import 'providers/usage_provider.dart';
import 'providers/download_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/splash_screen.dart';
import 'widgets/eye_protection_overlay.dart';
import 'widgets/break_timer_overlay.dart';

import 'package:audio_service/audio_service.dart';
import 'services/background_audio_service.dart';
import 'services/volume_service.dart';

late AudioHandler audioHandler;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Providers (Load only essential local data first)
  final channelProvider = ChannelProvider();
  final downloadProvider = DownloadProvider();
  final settingsProvider = SettingsProvider();

  // Initialize Safety Services
  VolumeService().initialize(settingsProvider);

  // Initialize Audio Service in background to avoid blocking the first frame
  final audioHandlerFuture = AudioService.init(
    builder: () => BackgroundAudioService(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.dadytube.dadytube.channel.audio',
      androidNotificationChannelName: 'Audio Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: channelProvider),
        ChangeNotifierProvider.value(value: downloadProvider),
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProvider(create: (_) => UsageProvider()),
        // Provide the AudioHandler via a FutureProvider or just wait for it
        ProxyProvider0<Future<AudioHandler>>(
          update: (_, __) => audioHandlerFuture,
        ),
      ],
      child: const DadyTubeApp(),
    ),
  );
}

class DadyTubeApp extends StatelessWidget {
  const DadyTubeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return MaterialApp(
          title: 'DadyTube',
          debugShowCheckedModeBanner: false,
          theme: DadyTubeTheme.getTheme(settings.themeLevel),
          supportedLocales: const [Locale('en', 'US'), Locale('ar', 'IQ')],
          locale: settings.locale,
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            return Stack(
              children: [
                EyeProtectionOverlay(child: child ?? const SizedBox.shrink()),
                // Mandatory Periodic Break Overlay (highest priority)
                const BreakTimerOverlay(),
              ],
            );
          },
          home: const SplashScreen(),
        );
      },
    );
  }
}
