/// Who is signed in. There are no accounts yet; this is the seam where a
/// real backend plugs in later, without changes to the UI.
sealed class AuthState {
  const AuthState();
}

final class SignedOut extends AuthState {
  const SignedOut();
}

final class SignedIn extends AuthState {
  const SignedIn(this.user);

  final AuthUser user;
}

class AuthUser {
  const AuthUser({required this.id, required this.displayName});

  final String id;

  /// What the profile shows, e.g. an e-mail address.
  final String displayName;
}

abstract interface class AuthRepository {
  /// The current state first, then every change.
  Stream<AuthState> watch();

  Future<void> signOut();
}
