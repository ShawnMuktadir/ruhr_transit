import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/l10n/app_language.dart';
import 'package:ruhr_transit/features/language/presentation/locale_cubit.dart';

import '../../../helpers/fake_settings.dart';

void main() {
  final german = AppLanguages.byCode('de')!;
  final english = AppLanguages.byCode('en')!;

  late FakeLanguageRepository repository;

  setUp(() => repository = FakeLanguageRepository());

  test('follows the device until a language is chosen', () {
    expect(LocaleCubit(repository).state, isNull);
  });

  test('starts with the stored language', () {
    expect(LocaleCubit(repository, initial: english).state, english);
  });

  test('select applies and saves the language', () async {
    final cubit = LocaleCubit(repository)..select(english);
    await pumpEventQueue();

    expect(cubit.state, english);
    expect(repository.saved, 'en');
  });

  test('selecting the current language saves nothing', () async {
    final cubit = LocaleCubit(repository, initial: german)..select(german);
    await pumpEventQueue();

    expect(cubit.state, german);
    expect(repository.saveCount, 0);
  });

  test('refresh adopts a language set in Android settings', () async {
    final cubit = LocaleCubit(repository, initial: german);
    repository.saved = 'en';

    await cubit.refresh();

    expect(cubit.state, english);
  });

  test('refresh ignores unsupported or missing languages', () async {
    final cubit = LocaleCubit(repository, initial: german);

    repository.saved = 'fr';
    await cubit.refresh();
    expect(cubit.state, german);

    repository.saved = null;
    await cubit.refresh();
    expect(cubit.state, german);
  });
}
