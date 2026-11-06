import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/widgets/app_loader.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget loader, {
    bool disableAnimations = false,
    bool tickers = true,
  }) => tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: TickerMode(
          enabled: tickers,
          child: Scaffold(body: loader),
        ),
      ),
    ),
  );

  Finder paint(Type loader) => find.descendant(
    of: find.byType(loader),
    matching: find.byType(CustomPaint),
  );

  testWidgets('the default size is centered in its space', (tester) async {
    await pump(tester, const AppLoader());
    final area = tester.getSize(find.byType(Scaffold));
    expect(tester.getSize(paint(AppLoader)), const Size.square(56));
    expect(tester.getCenter(paint(AppLoader)), area.center(Offset.zero));
  });

  testWidgets('small is icon-sized and takes no more room', (tester) async {
    await pump(tester, const Row(children: [AppLoader.small()]));
    expect(tester.getSize(find.byType(AppLoader)), const Size.square(24));
  });

  testWidgets('keeps moving while it is shown', (tester) async {
    await pump(tester, const AppLoader());
    await tester.pump(const Duration(seconds: 5));
    expect(tester.binding.hasScheduledFrame, isTrue);
  });

  testWidgets('stands still when animations are removed', (tester) async {
    await pump(tester, const AppLoader(), disableAnimations: true);
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('starts moving when animations come back', (tester) async {
    await pump(tester, const AppLoader(), disableAnimations: true);
    await pump(tester, const AppLoader());
    expect(tester.binding.hasScheduledFrame, isTrue);
  });

  testWidgets('stands still in a hidden tab', (tester) async {
    await pump(tester, const AppLoader(), tickers: false);
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('stops when it is gone', (tester) async {
    await pump(tester, const AppLoader());
    await pump(tester, const SizedBox());
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
