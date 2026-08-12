import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result.dart';
import '../data/auth_repository.dart';
import '../data/session_store.dart';
import '../domain/auth_user.dart';

/// Session state for the whole app.
///
/// A [ChangeNotifier] rather than the [StateNotifier] used elsewhere because
/// go_router's `refreshListenable` wants a [Listenable] — this way the router
/// re-evaluates its redirect the moment someone signs in or out, with no
/// bridging object in between.
class AuthController extends ChangeNotifier {
  AuthController(this._repository);

  final AuthRepository _repository;

  AuthStatus _status = AuthStatus.unknown;
  AuthUser? _user;
  bool _busy = false;

  AuthStatus get status => _status;
  AuthUser? get user => _user;

  /// True while a sign-in or sign-up call is in flight, so the forms can
  /// disable themselves rather than let an impatient second tap fire a second
  /// request.
  bool get busy => _busy;

  bool get isSignedIn => _status == AuthStatus.signedIn;

  /// Reads any stored session. Called once at startup; until it finishes the
  /// app sits on [AuthStatus.unknown] and the router holds at the splash.
  Future<void> restore() async {
    final session = await _repository.restore();
    _user = session?.user;
    _status = session == null ? AuthStatus.signedOut : AuthStatus.signedIn;
    notifyListeners();
  }

  Future<Failure?> signIn({
    required String email,
    required String password,
  }) => _run(() => _repository.signIn(email: email, password: password));

  Future<Failure?> signUp({
    required String name,
    required String email,
    required String employeeId,
    required String branch,
    required String password,
  }) => _run(
    () => _repository.signUp(
      name: name,
      email: email,
      employeeId: employeeId,
      branch: branch,
      password: password,
    ),
  );

  Future<void> signOut() async {
    await _repository.signOut();
    _user = null;
    _status = AuthStatus.signedOut;
    notifyListeners();
  }

  /// Runs an auth call, holding [busy] across it and publishing the session on
  /// success. Returns the [Failure] for the form to show, or null on success —
  /// the form needs the message, but the *session* is this class's business.
  Future<Failure?> _run(Future<Result<AuthUser>> Function() call) async {
    if (_busy) return null;
    _busy = true;
    notifyListeners();

    final result = await call();
    _busy = false;

    return result.fold(
      ok: (user) {
        _user = user;
        _status = AuthStatus.signedIn;
        notifyListeners();
        return null;
      },
      err: (failure) {
        notifyListeners();
        return failure;
      },
    );
  }
}

/// Overridden in tests with an [InMemorySessionStore] so the auth flow runs
/// without a platform channel behind it.
final sessionStoreProvider = Provider<SessionStore>(
  (ref) => SecureSessionStore(),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(sessionStoreProvider)),
);

final authControllerProvider = ChangeNotifierProvider<AuthController>(
  (ref) => AuthController(ref.watch(authRepositoryProvider)),
);

/// Who the Estate Ops screens should render for.
///
/// Falls back to the seeded staff member when there is no session, which is
/// what the widget tests and the design preview run against — those drive the
/// screens directly rather than through the sign-in gate.
final currentStaffProvider = Provider<AuthUser>((ref) {
  return ref.watch(authControllerProvider).user ?? _seedStaff;
});

const _seedStaff = AuthUser(
  name: 'Sara Khan',
  email: 'sara.khan@abergroup.ae',
  role: 'Senior Agent',
  branch: 'Business Bay',
  employeeId: 'ABR-2041',
);
