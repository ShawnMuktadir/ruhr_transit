import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/features/departures/domain/departure_board.dart';
import 'package:ruhr_transit/features/widget_sync/data/home_widget_sync.dart';
import 'package:ruhr_transit/features/widget_sync/data/widget_board_json.dart';

import '../../../helpers/fake_departure_repository.dart';
import '../../../helpers/fake_stop_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('home_widget');
  const sync = HomeWidgetSync();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// What the plugin stored, like its SharedPreferences on the device.
  late Map<String, Object?> stored;
  late List<MethodCall> calls;
  String? launchUri;
  var pinSupported = false;
  var installedWidgets = 0;

  setUp(() {
    stored = {};
    calls = [];
    launchUri = null;
    pinSupported = false;
    installedWidgets = 0;
    // Answers the plugin's platform channel in place of the Android side.
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      final args = call.arguments as Map<Object?, Object?>?;
      switch (call.method) {
        case 'saveWidgetData':
          stored[args!['id']! as String] = args['data'];
          return true;
        case 'getWidgetData':
          return stored[args!['id']];
        case 'updateWidget':
          return true;
        case 'initiallyLaunchedFromHomeWidget':
          return launchUri;
        case 'isRequestPinWidgetSupported':
          return pinSupported;
        case 'getInstalledWidgets':
          return [
            for (var i = 0; i < installedWidgets; i++)
              {'androidClassName': HomeWidgetSync.androidProvider},
          ];
        case 'requestPinWidget':
          return null;
      }
      throw MissingPluginException(call.method);
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  final board = DepartureBoard([delayedRe16], fetchedAt: boardTime);

  List<String> methods() => [for (final call in calls) call.method];

  test('showStop stores the stop and board, then redraws the widget', () async {
    await sync.showStop(bochumHbf, board: board);

    expect(stored[widgetBoardKey], encodeWidgetBoard(bochumHbf, board));
    expect(methods(), ['saveWidgetData', 'updateWidget']);
    expect(
      (calls.last.arguments as Map)['qualifiedAndroidName'],
      'de.muktadir.ruhrtransit.DepartureWidgetProvider',
    );
  });

  test('boardFetched updates only the widget stop', () async {
    await sync.showStop(bochumHbf);
    calls.clear();

    await sync.boardFetched(dortmundHbf.id, board);
    expect(methods(), ['getWidgetData']);
    expect(stored[widgetBoardKey], encodeWidgetBoard(bochumHbf, null));

    await sync.boardFetched(bochumHbf.id, board);
    expect(stored[widgetBoardKey], encodeWidgetBoard(bochumHbf, board));
    expect(methods().last, 'updateWidget');
  });

  test('boardFetched without a widget stop does nothing', () async {
    await sync.boardFetched(bochumHbf.id, board);

    expect(stored, isEmpty);
    expect(methods(), ['getWidgetData']);
  });

  test('launchedStop is the widget stop when the URI matches', () async {
    await sync.showStop(bochumHbf);

    expect(await sync.launchedStop(), isNull);

    launchUri = 'ruhrtransit://departures?stopId=de%3A05911%3A5194';
    expect(await sync.launchedStop(), bochumHbf);

    // A widget drawn for an earlier stop must not open the current one.
    launchUri = 'ruhrtransit://departures?stopId=de%3A05913%3A1';
    expect(await sync.launchedStop(), isNull);
  });

  test('offers to add the widget only if supported and not placed', () async {
    expect(await sync.canAddWidget(), isFalse);

    pinSupported = true;
    expect(await sync.canAddWidget(), isTrue);

    installedWidgets = 1;
    expect(await sync.canAddWidget(), isFalse);
  });

  test('addWidget asks the launcher to pin the provider', () async {
    await sync.addWidget();

    expect(methods(), ['requestPinWidget']);
    expect(
      (calls.single.arguments as Map)['qualifiedAndroidName'],
      HomeWidgetSync.androidProvider,
    );
  });

  test('platform errors are logged, not thrown', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) => throw PlatformException(code: 'boom'),
    );

    await sync.showStop(bochumHbf, board: board);
    await sync.boardFetched(bochumHbf.id, board);
    expect(await sync.launchedStop(), isNull);
    expect(await sync.canAddWidget(), isFalse);
  });
}
