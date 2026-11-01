import 'package:ruhr_transit/features/profile/domain/auth_repository.dart';

/// Until there is a backend: nobody can sign in, so nobody is signed in.
/// Replace the registration in `injection.dart` with a real implementation
/// to add accounts; the profile page and settings follow [watch].
class SignedOutAuthRepository implements AuthRepository {
  const SignedOutAuthRepository();

  @override
  Stream<AuthState> watch() => Stream.value(const SignedOut());

  @override
  Future<void> signOut() async {}
}
