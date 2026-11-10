import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/widgets/centered_message.dart';
import 'package:ruhr_transit/core/widgets/optional_provider.dart';
import 'package:ruhr_transit/core/widgets/show_message.dart';

Widget _app(Widget home) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: home),
);

void main() {
  testWidgets('CenteredMessage.retry shows the text and a try-again button', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      _app(CenteredMessage.retry('No connection', onRetry: () => retries++)),
    );
    await tester.pump();

    expect(find.text('No connection'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(retries, 1);
  });

  testWidgets('showMessage replaces the snack bar shown', (tester) async {
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () {
              final messenger = ScaffoldMessenger.of(context);
              messenger.showMessage('First');
              messenger.showMessage(
                'Second',
                action: SnackBarAction(label: 'Undo', onPressed: () {}),
              );
            },
            child: const Text('Go'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();
    expect(find.text('First'), findsNothing);
    expect(find.text('Second'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
  });

  group('showMessage closes by itself', () {
    Future<void> showWithUndo(
      WidgetTester tester, {
      bool screenReader = false,
    }) async {
      if (screenReader) {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(accessibleNavigation: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
      }
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => ScaffoldMessenger.of(context).showMessage(
                'Removed',
                action: SnackBarAction(label: 'Undo', onPressed: () {}),
              ),
              child: const Text('Go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();
    }

    testWidgets('a message with a button, after 8 seconds', (tester) async {
      await showWithUndo(tester);

      await tester.pump(const Duration(seconds: 7));
      expect(find.text('Removed'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Removed'), findsNothing);
    });

    testWidgets('but not with a screen reader on', (tester) async {
      await showWithUndo(tester, screenReader: true);

      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(find.text('Removed'), findsOneWidget);
    });
  });

  testWidgets('maybeRead and maybeWatch: the cubit or null', (tester) async {
    int? read;
    int? watched;
    Widget probe() => Builder(
      builder: (context) {
        read = context.maybeRead<Cubit<int>>()?.state;
        watched = context.maybeWatch<Cubit<int>>()?.state;
        return const SizedBox();
      },
    );

    await tester.pumpWidget(_app(probe()));
    expect(read, isNull);
    expect(watched, isNull);

    await tester.pumpWidget(
      _app(BlocProvider<Cubit<int>>(create: (_) => _Number(), child: probe())),
    );
    expect(read, 7);
    expect(watched, 7);
  });
}

class _Number extends Cubit<int> {
  _Number() : super(7);
}
