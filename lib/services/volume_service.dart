import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:flutter/foundation.dart';
import '../providers/settings_provider.dart';

class VolumeService {
  static final VolumeService _instance = VolumeService._internal();
  factory VolumeService() => _instance;
  VolumeService._internal();

  bool _isInitialized = false;

  void initialize(SettingsProvider settings) {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      FlutterVolumeController.addListener((volume) {
        if (settings.safeVolumeEnabled && volume > settings.maxVolumeLevel) {
          // Gently enforce the limit
          FlutterVolumeController.setVolume(settings.maxVolumeLevel);
          debugPrint('Safe Ears: Volume capped at ${settings.maxVolumeLevel}');
        }
      });
    } catch (e) {
      debugPrint('Error initializing VolumeService: $e');
    }
  }

  void dispose() {
    FlutterVolumeController.removeListener();
    _isInitialized = false;
  }
}
