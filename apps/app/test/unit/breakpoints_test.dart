import 'package:aber_app/shared/responsive/breakpoints.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Breakpoints.fromWidth', () {
    test('classifies phone widths as compact', () {
      expect(Breakpoints.fromWidth(390), WindowSize.compact); // iPhone
      expect(Breakpoints.fromWidth(599), WindowSize.compact);
    });

    test('classifies tablet widths as medium', () {
      expect(Breakpoints.fromWidth(600), WindowSize.medium);
      expect(Breakpoints.fromWidth(768), WindowSize.medium); // iPad portrait
      expect(Breakpoints.fromWidth(1023), WindowSize.medium);
    });

    test('classifies laptop widths as expanded', () {
      expect(Breakpoints.fromWidth(1024), WindowSize.expanded);
      expect(Breakpoints.fromWidth(1280), WindowSize.expanded);
    });

    test('classifies wide desktop as large', () {
      expect(Breakpoints.fromWidth(1440), WindowSize.large);
      expect(Breakpoints.fromWidth(1920), WindowSize.large);
    });
  });

  group('WindowSize capabilities', () {
    test('only compact lacks a side panel', () {
      expect(WindowSize.compact.hasSidePanel, isFalse);
      expect(WindowSize.medium.hasSidePanel, isTrue);
      expect(WindowSize.expanded.hasSidePanel, isTrue);
      expect(WindowSize.large.hasSidePanel, isTrue);
    });

    test('a third inspector pane needs at least an expanded window', () {
      expect(WindowSize.compact.hasInspector, isFalse);
      expect(WindowSize.medium.hasInspector, isFalse);
      expect(WindowSize.expanded.hasInspector, isTrue);
    });

    test('dashboard column counts scale with the window', () {
      // The director's KPI row: one per row on a phone, four on a laptop.
      expect(WindowSize.compact.dashboardColumns, 1);
      expect(WindowSize.medium.dashboardColumns, 2);
      expect(WindowSize.expanded.dashboardColumns, 4);
      expect(WindowSize.large.dashboardColumns, 4);
    });
  });
}
