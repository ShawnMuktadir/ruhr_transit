import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/features/profile/data/profile_repository_impl.dart';
import 'package:ruhr_transit/features/profile/data/signed_out_auth_repository.dart';
import 'package:ruhr_transit/features/profile/domain/auth_repository.dart';
import 'package:ruhr_transit/features/profile/presentation/profile_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../helpers/fake_settings.dart';

void main() {
  group('ProfileRepositoryImpl', () {
    late ProfileRepositoryImpl repository;

    setUp(() {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      repository = ProfileRepositoryImpl(SharedPreferencesAsync());
    });

    test('no name until one is saved; saved names are trimmed', () async {
      expect(await repository.loadDisplayName(), isNull);

      await repository.saveDisplayName('  Kim ');

      expect(await repository.loadDisplayName(), 'Kim');
    });

    test('a blank name removes it', () async {
      await repository.saveDisplayName('Kim');
      await repository.saveDisplayName('   ');

      expect(await repository.loadDisplayName(), isNull);
    });
  });

  group('SignedOutAuthRepository', () {
    test('nobody is signed in, and signing out changes nothing', () async {
      const repository = SignedOutAuthRepository();

      expect(await repository.watch().first, isA<SignedOut>());
      await repository.signOut();
      expect(await repository.watch().first, isA<SignedOut>());
    });
  });

  group('ProfileCubit', () {
    test('loads the stored name', () async {
      final cubit = ProfileCubit(
        FakeProfileRepository('Kim'),
        FakeAuthRepository(),
      );
      expect(cubit.state.isLoading, isTrue);

      await pumpEventQueue();

      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.displayName, 'Kim');
      expect(cubit.state.auth, isA<SignedOut>());
      await cubit.close();
    });

    test('saves a trimmed name; blank clears it', () async {
      final profile = FakeProfileRepository();
      final cubit = ProfileCubit(profile, FakeAuthRepository());
      await pumpEventQueue();

      expect(await cubit.saveDisplayName(' Kim '), isTrue);
      expect(cubit.state.displayName, 'Kim');
      expect(profile.name, 'Kim');

      expect(await cubit.saveDisplayName(''), isTrue);
      expect(cubit.state.displayName, isNull);
      await cubit.close();
    });

    test('a failed save keeps the old name and says so', () async {
      final profile = FakeProfileRepository('Kim')
        ..saveError = Exception('disk full');
      final cubit = ProfileCubit(profile, FakeAuthRepository());
      await pumpEventQueue();

      expect(await cubit.saveDisplayName('Alex'), isFalse);
      expect(cubit.state.displayName, 'Kim');
      expect(cubit.state.saveFailed, isTrue);
      await cubit.close();
    });

    test('follows the sign-in state and signs out', () async {
      final auth = FakeAuthRepository(
        const SignedIn(AuthUser(id: '1', displayName: 'kim@example.com')),
      );
      final cubit = ProfileCubit(FakeProfileRepository(), auth);
      await pumpEventQueue();
      expect(cubit.state.auth, isA<SignedIn>());

      await cubit.signOut();
      await pumpEventQueue();

      expect(auth.signOutCalls, 1);
      expect(cubit.state.auth, isA<SignedOut>());
      await cubit.close();
    });
  });
}
