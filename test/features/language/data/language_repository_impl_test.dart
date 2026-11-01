import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/features/language/data/language_repository_impl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late SharedPreferencesAsync preferences;
  late LanguageRepositoryImpl repository;
  late List<MethodCall> calls;

  /// Android's per-app language, as MainActivity would answer.
  void androidAnswers(String? Function(MethodCall call) answer) {
    messenger.setMockMethodCallHandler(appLocaleChannel, (call) async {
      calls.add(call);
      return answer(call);
    });
  }

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    preferences = SharedPreferencesAsync();
    repository = LanguageRepositoryImpl(preferences);
    calls = [];
  });
  tearDown(() => messenger.setMockMethodCallHandler(appLocaleChannel, null));

  test('nothing chosen yet is null', () async {
    androidAnswers((_) => null);

    expect(await repository.load(), isNull);
  });

  test('saves the choice and tells Android', () async {
    androidAnswers((_) => null);

    await repository.save('en');

    expect(
      await preferences.getString(LanguageRepositoryImpl.storageKey),
      'en',
    );
    expect(calls.single.method, 'set');
    expect(calls.single.arguments, 'en');
  });

  test('without a per-app language the saved one counts', () async {
    // What MainActivity answers below Android 13, or when the app follows
    // the system language.
    await preferences.setString(LanguageRepositoryImpl.storageKey, 'en');
    androidAnswers((_) => null);

    expect(await repository.load(), 'en');
  });

  test('the per-app language from Android settings wins', () async {
    await preferences.setString(LanguageRepositoryImpl.storageKey, 'de');
    androidAnswers((call) => call.method == 'get' ? 'en-GB' : null);

    expect(await repository.load(), 'en-GB');
  });

  test('works when Android fails or is not there', () async {
    await preferences.setString(LanguageRepositoryImpl.storageKey, 'en');
    androidAnswers((_) => throw PlatformException(code: 'boom'));
    expect(await repository.load(), 'en');
    await repository.save('de');

    // No handler at all, as on other platforms.
    messenger.setMockMethodCallHandler(appLocaleChannel, null);
    expect(await repository.load(), 'de');
  });
}
