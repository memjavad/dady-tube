import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dadytube/providers/settings_provider.dart';
import 'package:flutter/widgets.dart';

void main() {
  setUp(() {
    WidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({
      'video_quality': VideoQuality.auto.index,
    });
  });

  test('setVideoQuality updates state and persists to SharedPreferences', () async {
    final provider = SettingsProvider();
    await Future.delayed(Duration.zero); // Wait for async init

    // Initial value
    expect(provider.videoQuality, VideoQuality.auto);

    // Track notifyListeners call
    bool notified = false;
    provider.addListener(() {
      notified = true;
    });

    // Update quality
    await provider.setVideoQuality(VideoQuality.p720);

    // Verify state updated
    expect(provider.videoQuality, VideoQuality.p720);

    // Verify notifyListeners was called
    expect(notified, true);

    // Verify persisted to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('video_quality'), VideoQuality.p720.index);
  });
}
