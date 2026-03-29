// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dadytube/main.dart';
import 'package:provider/provider.dart';
import 'package:dadytube/providers/settings_provider.dart';
import 'package:dadytube/providers/channel_provider.dart';
import 'package:dadytube/providers/download_provider.dart';
import 'package:dadytube/providers/usage_provider.dart';

void main() {
  testWidgets('App should build successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider(create: (_) => ChannelProvider()),
          ChangeNotifierProvider(create: (_) => DownloadProvider()),
          ChangeNotifierProvider(create: (_) => UsageProvider()),
        ],
        child: const DadyTubeApp(),
      ),
    );

    // Since it's a media app with complex animations, just verify it builds the initial frame.
    await tester.pump();
  });
}
