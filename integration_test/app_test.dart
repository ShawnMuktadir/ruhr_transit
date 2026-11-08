// Starts the real app on a device or simulator and walks through the first
// screens, with screenshots into build/screenshots. Run it locally (CI
// takes its iOS screenshots with simctl instead, as flutter drive hung on
// GitHub's simulator):
//
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/app_test.dart -d <device>
//
// Expects a freshly installed app with the device in English.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ruhr_transit/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// The sky and the loader move all the time, so the screen never settles;
  /// this gives it a moment instead.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('starts, onboards and shows its main pages', (tester) async {
    // Android draws into a surface that screenshots cannot read otherwise.
    if (defaultTargetPlatform == TargetPlatform.android) {
      await binding.convertFlutterSurfaceToImage();
    }
    await app.main();
    await settle(tester);
    await binding.takeScreenshot('1_welcome');

    await tester.tap(find.text('Continue'));
    await settle(tester);
    await tester.tap(find.text('Get started'));
    await settle(tester);
    await binding.takeScreenshot('2_plan');

    await tester.tap(find.text('Settings'));
    await settle(tester);
    await binding.takeScreenshot('3_settings');

    await tester.scrollUntilVisible(
      find.text('Accessibility'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await settle(tester);
    await binding.takeScreenshot('4_accessibility');
    // The section names the settings as this platform calls them.
    expect(
      find.text(
        defaultTargetPlatform == TargetPlatform.iOS ? 'VoiceOver' : 'TalkBack',
      ),
      findsOneWidget,
    );
  });
}
