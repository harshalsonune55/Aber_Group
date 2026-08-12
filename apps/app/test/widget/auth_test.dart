import 'package:aber_app/core/router.dart';
import 'package:aber_app/features/auth/data/session_store.dart';
import 'package:aber_app/features/auth/domain/auth_user.dart';
import 'package:aber_app/features/auth/state/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Drives the real sign-in gate: the real router redirect, the real
/// [AuthController], and the real repository — only the session *store* is
/// swapped for memory, because secure storage has no implementation behind a
/// test binding.
///
/// The point of these is the gate itself. A form that validates but lets an
/// unauthenticated user reach `/today`, or one that signs in but leaves the
/// router on the sign-in screen, would both pass a test that only poked at
/// widgets.

const _phone = Size(402, 874);

/// Pumps the app with the auth gate installed, entering at the splash the way
/// `main.dart` does.
Future<AuthController> _pumpApp(
  WidgetTester tester, {
  StoredSession? session,
}) async {
  tester.view.physicalSize = _phone;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [
      sessionStoreProvider.overrideWithValue(InMemorySessionStore(session)),
    ],
  );
  addTearDown(container.dispose);

  final auth = container.read(authControllerProvider);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: createRouter(initialLocation: '/starting', auth: auth),
      ),
    ),
  );
  await auth.restore();
  await tester.pumpAndSettle();
  return auth;
}

Future<void> _fillSignIn(
  WidgetTester tester, {
  String email = 'sara.khan@abergroup.ae',
  String password = 'aber12345',
}) async {
  await tester.enterText(find.byType(TextFormField).at(0), email);
  await tester.enterText(find.byType(TextFormField).at(1), password);
  await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
  await tester.pumpAndSettle();
}

void main() {
  group('the gate', () {
    testWidgets('a cold start with no session lands on sign in', (
      tester,
    ) async {
      await _pumpApp(tester);

      expect(find.text('Sign in'), findsWidgets);
      expect(find.text('Clock in'), findsNothing);
    });

    testWidgets('a deep link is refused while signed out', (tester) async {
      // Even a valid, previously-shareable link has to go through sign-in.
      tester.view.physicalSize = _phone;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final container = ProviderContainer(
        overrides: [
          sessionStoreProvider.overrideWithValue(InMemorySessionStore()),
        ],
      );
      addTearDown(container.dispose);
      final auth = container.read(authControllerProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: createRouter(initialLocation: '/deals/d1', auth: auth),
          ),
        ),
      );
      await auth.restore();
      await tester.pumpAndSettle();

      expect(find.text('Sign in'), findsWidgets);
    });

    testWidgets('a stored session skips sign in entirely', (tester) async {
      await _pumpApp(
        tester,
        session: const StoredSession(
          token: 'local.deadbeef',
          user: AuthUser(
            name: 'Sara Khan',
            email: 'sara.khan@abergroup.ae',
            role: 'Senior Agent',
            branch: 'Business Bay',
            employeeId: 'ABR-2041',
          ),
        ),
      );

      expect(find.text('Clock in'), findsOneWidget);
      expect(find.textContaining('Sara'), findsOneWidget);
    });
  });

  group('sign in', () {
    testWidgets('valid credentials reach Today', (tester) async {
      await _pumpApp(tester);
      await _fillSignIn(tester);

      expect(find.text('Clock in'), findsOneWidget);
      expect(find.textContaining('Sara'), findsOneWidget);
    });

    testWidgets('an empty form reports both fields rather than submitting', (
      tester,
    ) async {
      await _pumpApp(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Enter your work email.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);
      expect(find.text('Clock in'), findsNothing);
    });

    testWidgets('a personal email is rejected with a reason', (tester) async {
      await _pumpApp(tester);
      await _fillSignIn(tester, email: 'sara@gmail.com');

      expect(find.text('Use your Aber Group work email.'), findsOneWidget);
      expect(find.text('Clock in'), findsNothing);
    });

    testWidgets('a short password never leaves the form', (tester) async {
      await _pumpApp(tester);
      await _fillSignIn(tester, password: 'short');

      expect(find.text('Use at least 8 characters.'), findsOneWidget);
    });

    testWidgets('the password can be revealed and hidden again', (
      tester,
    ) async {
      await _pumpApp(tester);

      EditableText field() =>
          tester.widget<EditableText>(find.byType(EditableText).at(1));

      expect(field().obscureText, isTrue);
      await tester.tap(find.byTooltip('Show password'));
      await tester.pumpAndSettle();
      expect(field().obscureText, isFalse);

      await tester.tap(find.byTooltip('Hide password'));
      await tester.pumpAndSettle();
      expect(field().obscureText, isTrue);
    });
  });

  group('sign up', () {
    Future<void> openSignUp(WidgetTester tester) async {
      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();
    }

    Future<void> fill(
      WidgetTester tester, {
      String name = 'Layla Haddad',
      String email = 'layla.haddad@abergroup.ae',
      String id = 'ABR-3097',
      String password = 'marina2026',
      String? confirm,
    }) async {
      await tester.enterText(find.byType(TextFormField).at(0), name);
      await tester.enterText(find.byType(TextFormField).at(1), email);
      await tester.enterText(find.byType(TextFormField).at(2), id);
      await tester.enterText(find.byType(TextFormField).at(3), password);
      await tester.enterText(
        find.byType(TextFormField).at(4),
        confirm ?? password,
      );

      // Five fields plus the branch chips push the button below the fold on a
      // phone, and a tap at an off-screen offset silently does nothing.
      final submit = find.widgetWithText(FilledButton, 'Create account');
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pumpAndSettle();
    }

    testWidgets('creating an account signs you straight in as yourself', (
      tester,
    ) async {
      await _pumpApp(tester);
      await openSignUp(tester);
      await fill(tester);

      // Signed in as the new account, not as the seeded staff member.
      expect(find.text('Clock in'), findsOneWidget);
      expect(find.textContaining('Layla'), findsOneWidget);
    });

    testWidgets('the chosen branch follows through to the profile', (
      tester,
    ) async {
      await _pumpApp(tester);
      await openSignUp(tester);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Dubai Marina'));
      await tester.pumpAndSettle();
      await fill(tester);

      await tester.tap(find.text('LH'));
      await tester.pumpAndSettle();

      expect(find.text('Agent · Dubai Marina'), findsOneWidget);
      expect(find.text('ID ABR-3097'.toUpperCase()), findsOneWidget);
    });

    testWidgets('mismatched passwords are caught before the call', (
      tester,
    ) async {
      await _pumpApp(tester);
      await openSignUp(tester);
      await fill(tester, confirm: 'something-else9');

      expect(find.text('Those two passwords do not match.'), findsOneWidget);
      expect(find.text('Clock in'), findsNothing);
    });

    testWidgets('a password with no digit is refused', (tester) async {
      await _pumpApp(tester);
      await openSignUp(tester);
      await fill(tester, password: 'onlyletters');

      expect(
        find.text('Mix in at least one letter and one number.'),
        findsOneWidget,
      );
    });

    testWidgets('a malformed employee ID says what one looks like', (
      tester,
    ) async {
      await _pumpApp(tester);
      await openSignUp(tester);
      await fill(tester, id: '3097');

      expect(find.text('Staff IDs look like ABR-2041.'), findsOneWidget);
    });

    testWidgets('backing out returns to sign in', (tester) async {
      await _pumpApp(tester);
      await openSignUp(tester);
      expect(find.text('Create your account'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.text('Create your account'), findsNothing);
      expect(find.text('Sign in'), findsWidgets);
    });
  });

  group('sign out', () {
    testWidgets('confirming ends the session and returns to sign in', (
      tester,
    ) async {
      final auth = await _pumpApp(tester);
      await _fillSignIn(tester);
      expect(auth.isSignedIn, isTrue);

      // Reached from the profile, which is where a signed-in user finds it.
      await tester.tap(find.text('SK'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.widgetWithText(OutlinedButton, 'Sign out'),
        200,
      );
      await tester.tap(find.widgetWithText(OutlinedButton, 'Sign out'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
      await tester.pumpAndSettle();

      expect(auth.isSignedIn, isFalse);
      expect(find.text('Clock in'), findsNothing);
      expect(find.text('Work email'.toUpperCase()), findsOneWidget);
    });

    testWidgets('signing out from the More tab works too', (tester) async {
      // The profile is a root-navigator route while More is inside the tab
      // shell, so the two reach the same dialog through different navigators.
      final auth = await _pumpApp(tester);
      await _fillSignIn(tester);

      await tester.tap(find.text('More').last);
      await tester.pumpAndSettle();

      final row = find.text('Sign out');
      await tester.scrollUntilVisible(
        row,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
      await tester.pumpAndSettle();

      expect(auth.isSignedIn, isFalse);
      expect(find.text('Work email'.toUpperCase()), findsOneWidget);
    });

    testWidgets('the session is cleared, not just the screen', (tester) async {
      final auth = await _pumpApp(tester);
      await _fillSignIn(tester);
      await auth.signOut();
      await tester.pumpAndSettle();

      // A fresh restore must not resurrect the session from storage.
      await auth.restore();
      await tester.pumpAndSettle();

      expect(auth.status, AuthStatus.signedOut);
      expect(find.text('Clock in'), findsNothing);
    });
  });
}
