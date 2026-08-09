import 'package:aber_app/shared/responsive/aber_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _destinations = <ShellDestination>[
  ShellDestination(
    label: 'Home',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
    route: '/home',
  ),
  ShellDestination(
    label: 'Leads',
    icon: Icons.people_outline,
    selectedIcon: Icons.people,
    route: '/leads',
  ),
];

Widget _wrap(Widget child, Size size) => MediaQuery(
  data: MediaQueryData(size: size),
  child: MaterialApp(home: child),
);

void main() {
  group('AberShell navigation chrome', () {
    testWidgets('phone width uses bottom navigation', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrap(
          AberShell(
            destinations: _destinations,
            selectedIndex: 0,
            onDestinationSelected: (_) {},
            child: const Text('content'),
          ),
          const Size(390, 844),
        ),
      );

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('desktop width uses a navigation rail', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrap(
          AberShell(
            destinations: _destinations,
            selectedIndex: 0,
            onDestinationSelected: (_) {},
            child: const Text('content'),
          ),
          const Size(1280, 800),
        ),
      );

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('the child renders at every width', (tester) async {
      for (final size in [const Size(390, 844), const Size(1280, 800)]) {
        await tester.pumpWidget(
          _wrap(
            AberShell(
              destinations: _destinations,
              selectedIndex: 0,
              onDestinationSelected: (_) {},
              child: const Text('content'),
            ),
            size,
          ),
        );
        expect(find.text('content'), findsOneWidget);
      }
    });

    testWidgets('selecting a destination reports its index', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      int? selected;
      await tester.pumpWidget(
        _wrap(
          AberShell(
            destinations: _destinations,
            selectedIndex: 0,
            onDestinationSelected: (i) => selected = i,
            child: const Text('content'),
          ),
          const Size(390, 844),
        ),
      );

      await tester.tap(find.text('Leads'));
      await tester.pumpAndSettle();
      expect(selected, 1);
    });
  });

  group('AdaptiveListDetail', () {
    testWidgets('shows only the list on a phone', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrap(
          const AdaptiveListDetail(list: Text('list'), detail: Text('detail')),
          const Size(390, 844),
        ),
      );

      expect(find.text('list'), findsOneWidget);
      expect(find.text('detail'), findsNothing);
    });

    testWidgets('shows both panes on a desktop', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrap(
          const AdaptiveListDetail(list: Text('list'), detail: Text('detail')),
          const Size(1280, 800),
        ),
      );

      expect(find.text('list'), findsOneWidget);
      expect(find.text('detail'), findsOneWidget);
    });

    testWidgets('prompts when nothing is selected on a wide window', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrap(
          const AdaptiveListDetail(list: Text('list')),
          const Size(1280, 800),
        ),
      );

      expect(find.textContaining('Select an item'), findsOneWidget);
    });
  });
}
