import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dadytube/services/volume_service.dart';
import 'package:dadytube/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VolumeService Tests', () {
    late VolumeService volumeService;
    late SettingsProvider settingsProvider;
    final List<MethodCall> methodLog = <MethodCall>[];

    // Controller to mock EventChannel
    late StreamController<dynamic> eventController;
    bool listenerCanceled = false;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'safeVolumeEnabled': true,
        'maxVolumeLevel': 0.6,
      });

      settingsProvider = SettingsProvider();

      // Wait for SettingsProvider to finish loading from SharedPreferences
      await Future.delayed(Duration.zero);

      volumeService = VolumeService();

      methodLog.clear();
      eventController = StreamController<dynamic>.broadcast();
      listenerCanceled = false;

      // Mock MethodChannel for setVolume etc.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(
              'com.yosemiteyss.flutter_volume_controller/method',
            ),
            (MethodCall methodCall) async {
              methodLog.add(methodCall);
              return null;
            },
          );

      // Mock EventChannel for addListener
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(
            const EventChannel(
              'com.yosemiteyss.flutter_volume_controller/event',
            ),
            MockStreamHandler.inline(
              onListen: (dynamic arguments, MockStreamHandlerEventSink events) {
                eventController.stream.listen((event) {
                  events.success(event);
                });
              },
              onCancel: (dynamic arguments) {
                listenerCanceled = true;
              },
            ),
          );
    });

    tearDown(() {
      volumeService.dispose();
      eventController.close();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(
              'com.yosemiteyss.flutter_volume_controller/method',
            ),
            null,
          );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(
            const EventChannel(
              'com.yosemiteyss.flutter_volume_controller/event',
            ),
            null,
          );
    });

    test(
      'initialize does not set volume if volume is below max limit',
      () async {
        volumeService.initialize(settingsProvider);

        // Wait a tick for addListener to be fully processed
        await Future.delayed(Duration.zero);

        // Simulate a volume change that is safe
        eventController.add(
          '0.5',
        ); // The flutter_volume_controller receives strings
        await Future.delayed(const Duration(milliseconds: 50));

        expect(
          methodLog.where((m) => m.method == 'setVolume'),
          isEmpty,
          reason: 'setVolume should not be called when volume is safe',
        );
      },
    );

    test('initialize enforces safe volume by capping at max limit', () async {
      volumeService.initialize(settingsProvider);

      await Future.delayed(Duration.zero);

      // Simulate a volume change that exceeds the limit
      eventController.add('0.8');
      // wait for microtasks or streams to process
      await Future.delayed(const Duration(milliseconds: 50));

      final setVolumeCalls = methodLog.where((m) => m.method == 'setVolume');
      expect(
        setVolumeCalls,
        isNotEmpty,
        reason: 'setVolume should be called to enforce safe volume',
      );

      final call = setVolumeCalls.first;
      expect(call.arguments['volume'], 0.6); // Should enforce max limit
    });

    test('does not enforce safe volume if disabled', () async {
      SharedPreferences.setMockInitialValues({
        'safeVolumeEnabled': false,
        'maxVolumeLevel': 0.6,
      });
      settingsProvider = SettingsProvider();
      await Future.delayed(Duration.zero);

      volumeService.initialize(settingsProvider);
      await Future.delayed(Duration.zero);

      // Simulate a volume change that exceeds the limit
      eventController.add('0.8');
      await Future.delayed(Duration.zero);

      expect(
        methodLog.where((m) => m.method == 'setVolume'),
        isEmpty,
        reason: 'setVolume should not be called when safe volume is disabled',
      );
    });

    test('initialize does not run twice', () async {
      volumeService.initialize(settingsProvider);
      volumeService.initialize(settingsProvider);
      // If it throws or registers twice, it might cause issues, but we test it doesn't fail.
    });

    test('dispose cancels volume listener', () async {
      volumeService.initialize(settingsProvider);
      await Future.delayed(Duration.zero);

      volumeService.dispose();
      await Future.delayed(Duration.zero);

      expect(
        listenerCanceled,
        isTrue,
        reason: 'Volume listener should be canceled upon dispose',
      );
    });
  });
}
