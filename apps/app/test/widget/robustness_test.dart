import 'package:aber_app/core/router.dart';
import 'package:aber_app/features/auth/data/session_store.dart';
import 'package:aber_app/features/auth/domain/auth_user.dart';
import 'package:aber_app/features/auth/state/auth_controller.dart';
import 'package:aber_app/features/estate_ops/data/estate_ops_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders every screen under conditions the design was not drawn at, and
/// fails on any layout overflow.
///
/// Text scale is not ours to choose — it is an OS accessibility setting, and
/// an agent who has turned it up is exactly the person who cannot read a
/// clipped label. A `RenderFlex overflowed` is reported through the same
/// channel as any other exception, so `takeException` catches it here even
/// though on a phone it only paints a yellow stripe.

/// Small phone. Narrower than the design's 402pt, because plenty of staff are
/// on older handsets.
const _smallPhone = Size(360, 690);

Future<void> _pumpAt(
  WidgetTester tester,
  String location, {
  double textScale = 1.0,
  Size size = _smallPhone,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [
      sessionStoreProvider.overrideWithValue(
        InMemorySessionStore(
          const StoredSession(
            token: 'local.test',
            user: AuthUser(
              name: 'Sara Khan',
              email: 'sara.khan@abergroup.ae',
              role: 'Senior Agent',
              branch: 'Business Bay',
              employeeId: 'ABR-2041',
            ),
          ),
        ),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: createRouter(initialLocation: location),
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          minScaleFactor: textScale,
          maxScaleFactor: textScale,
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Every screen in the app, by route.
const _routes = <String>[
  '/today',
  '/inventory',
  '/deals',
  '/team',
  '/more',
  '/profile',
  '/sign-in',
  '/sign-up',
  '/inventory/l1',
  '/deals/d1',
  '/more/commission',
];

void main() {
  group('large text', () {
    for (final scale in const [1.3, 2.0]) {
      testWidgets('every screen survives a ${scale}x text scale', (
        tester,
      ) async {
        for (final route in _routes) {
          await _pumpAt(tester, route, textScale: scale);
          expect(
            tester.takeException(),
            isNull,
            reason: '$route overflows at ${scale}x text',
          );
        }
      });
    }
  });

  group('small screens', () {
    testWidgets('every screen fits a 360pt-wide phone', (tester) async {
      for (final route in _routes) {
        await _pumpAt(tester, route);
        expect(
          tester.takeException(),
          isNull,
          reason: '$route overflows at 360pt wide',
        );
      }
    });
  });

  group('tap targets', () {
    /// Anything you are meant to hit with a thumb needs about 44dp. Below that
    /// the miss rate climbs sharply, and the people it fails first are the ones
    /// with the least steady hands.
    const minimum = 44.0;

    void collect(WidgetTester tester, Set<String> into) {
      for (final element in find.byType(InkWell).evaluate()) {
        final inkWell = element.widget as InkWell;
        // A null handler is a decorative or disabled row, not a target.
        if (inkWell.onTap == null) continue;

        final box = element.renderObject as RenderBox?;
        if (box == null || !box.hasSize || box.size.isEmpty) continue;

        final size = box.size;
        if (size.height < minimum || size.width < minimum) {
          into.add('${size.width.round()}x${size.height.round()}');
        }
      }
    }

    /// Scrolls the whole screen, because a list only builds what is near the
    /// viewport — checking one screenful would miss most of the controls.
    Future<Set<String>> sweep(WidgetTester tester, String route) async {
      await _pumpAt(tester, route, size: const Size(402, 874));
      final undersized = <String>{};

      for (var pass = 0; pass < 14; pass++) {
        collect(tester, undersized);
        final scrollable = find.byType(Scrollable);
        if (scrollable.evaluate().isEmpty) break;
        await tester.drag(scrollable.first, const Offset(0, -420));
        await tester.pumpAndSettle();
      }
      return undersized;
    }

    for (final route in _routes) {
      testWidgets('$route has no undersized controls', (tester) async {
        final undersized = await sweep(tester, route);
        expect(
          undersized,
          isEmpty,
          reason: 'tappable areas under ${minimum}dp on $route: $undersized',
        );
      });
    }
  });

  group('seed data', () {
    test('every scheduled visit points at a listing that exists', () {
      for (final visit in todaysVisits) {
        if (visit.listingId == null) continue;
        expect(
          findListing(visit.listingId!),
          isNotNull,
          reason: '${visit.property} points at a missing listing',
        );
      }
    });
  });
}
