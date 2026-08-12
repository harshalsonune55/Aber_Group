import 'package:aber_app/core/router.dart';
import 'package:aber_app/features/estate_ops/data/estate_ops_data.dart';
import 'package:aber_app/features/estate_ops/presentation/widgets/estate_widgets.dart';
import 'package:aber_app/features/estate_ops/presentation/widgets/photo_placeholder.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Drives the Estate Ops staff app through the real router and the real
/// `EstateOpsNotifier`, at phone size — the width the design targets and the
/// only one that gets the dark staff-app theme and the native tab bar.
///
/// Deliberately exercises whole screens rather than individual widgets: the
/// screens are thin views over static seed data, so the behaviour worth
/// protecting is the wiring — tab switching, filters surviving a tab change,
/// detail pushes, and deep links that name a record that no longer exists.

const _phone = Size(402, 874);

Future<void> _pumpApp(WidgetTester tester, {String at = '/today'}) async {
  tester.view.physicalSize = _phone;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp.router(
        routerConfig: createRouter(initialLocation: at),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Taps a bottom-tab label. The tab bar renders the label as plain text, so
/// this scopes to the last match to avoid colliding with body copy.
Future<void> _tapTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

/// Scrolls a below-the-fold control into view and taps it.
///
/// `scrollUntilVisible` stops as soon as the widget is *built*, which a
/// [ListView] does up to its cache extent past the viewport — so on its own it
/// leaves the target off-screen and the tap misses. [WidgetTester.ensureVisible]
/// finishes the job.
/// The page's own list is the outermost scrollable; a screen with a text field
/// on it has a second one (the field's editable region), which is not what we
/// want to drag.
Future<void> _scrollAndTap(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('tab navigation', () {
    testWidgets('opens on Today with the shift card and the roster hidden', (
      tester,
    ) async {
      await _pumpApp(tester);

      expect(find.text('Clock in'), findsOneWidget);
      expect(find.textContaining('Sara'), findsOneWidget);
      expect(find.text('Roster'), findsNothing);
    });

    testWidgets('every tab reaches its screen', (tester) async {
      await _pumpApp(tester);

      for (final (tab, heading) in const [
        ('Inventory', 'Inventory'),
        ('Deals', 'Pipeline'),
        ('Team', 'Team'),
        ('More', 'More'),
      ]) {
        await _tapTab(tester, tab);
        expect(
          find.text(heading),
          findsWidgets,
          reason: 'tapping $tab should show the $heading screen',
        );
      }
    });
  });

  group('Today', () {
    testWidgets('clocking in swaps the card to the on-shift state', (
      tester,
    ) async {
      await _pumpApp(tester);

      await tester.tap(find.text('Clock in'));
      await tester.pumpAndSettle();

      expect(find.text('Clock in'), findsNothing);
      expect(find.text('Clocked in 9:12'), findsOneWidget);
      expect(find.text('END'), findsOneWidget);
    });

    testWidgets('completing a task updates the remaining count', (
      tester,
    ) async {
      await _pumpApp(tester);

      // The task list sits below the fold on a phone.
      await tester.scrollUntilVisible(find.text(tasks.first.title), 200);
      await tester.pumpAndSettle();
      expect(find.text('${tasks.length} left'), findsOneWidget);

      await tester.tap(find.text(tasks.first.title));
      await tester.pumpAndSettle();

      expect(find.text('${tasks.length - 1} left'), findsOneWidget);
    });

    testWidgets('check-in survives visiting another tab', (tester) async {
      await _pumpApp(tester);

      await tester.tap(find.text('Clock in'));
      await tester.pumpAndSettle();
      await _tapTab(tester, 'Team');
      await _tapTab(tester, 'Today');

      expect(find.text('Clocked in 9:12'), findsOneWidget);
    });

    testWidgets('a scheduled visit opens the property it is against', (
      tester,
    ) async {
      await _pumpApp(tester);

      final visit = todaysVisits.first;
      final listing = findListing(visit.listingId!)!;
      await _scrollAndTap(tester, find.text(visit.property));

      expect(find.text(listing.price), findsOneWidget);
      expect(find.text('Documents'.toUpperCase()), findsOneWidget);
    });

    testWidgets('a KPI tile jumps to the screen it counts', (tester) async {
      await _pumpApp(tester);

      // Stat labels render through Eyebrow, which upper-cases them.
      await tester.tap(find.text('Open deals'.toUpperCase()));
      await tester.pumpAndSettle();

      expect(find.text('Pipeline'), findsOneWidget);
    });

    testWidgets('capturing a lead adds it to the list and the count', (
      tester,
    ) async {
      await _pumpApp(tester);

      await tester.tap(find.text('Add lead'));
      await tester.pumpAndSettle();
      expect(find.text('New lead'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), 'Aisha Rahman');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Villa, Al Barsha',
      );
      await tester.tap(find.text('Referral'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save lead'));
      await tester.pumpAndSettle();

      expect(find.text('Aisha Rahman added to your leads'), findsOneWidget);

      // Newest first, and the section count follows.
      await tester.scrollUntilVisible(
        find.text('Aisha Rahman'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Villa, Al Barsha · Referral'), findsOneWidget);
      expect(find.text('${leads.length + 1} unassigned'), findsOneWidget);
    });

    testWidgets('an empty capture form reports both fields', (tester) async {
      await _pumpApp(tester);

      await tester.tap(find.text('Add lead'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save lead'));
      await tester.pumpAndSettle();

      expect(find.text('Who is this lead?'), findsOneWidget);
      expect(find.text('Note what they are after.'), findsOneWidget);
      // Still open, holding what was typed, rather than dropped.
      expect(find.text('New lead'), findsOneWidget);
    });

    testWidgets('cancelling the capture adds nothing', (tester) async {
      await _pumpApp(tester);

      await tester.tap(find.text('Add lead'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Never Saved');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('New lead'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('${leads.length} unassigned'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Never Saved'), findsNothing);
    });

    testWidgets('a captured lead survives visiting another tab', (
      tester,
    ) async {
      await _pumpApp(tester);

      await tester.tap(find.text('Add lead'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Aisha Rahman');
      await tester.enterText(find.byType(TextFormField).at(1), 'Villa');
      await tester.tap(find.text('Save lead'));
      await tester.pumpAndSettle();

      await _tapTab(tester, 'Team');
      await _tapTab(tester, 'Today');

      // Switching tabs returns Today to the top, so the leads section needs
      // scrolling back into view.
      await tester.scrollUntilVisible(
        find.text('Aisha Rahman'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('${leads.length + 1} unassigned'), findsOneWidget);
    });

    testWidgets('a quick action reaches the module behind it', (tester) async {
      await _pumpApp(tester);

      await tester.tap(find.text('Claim'));
      await tester.pumpAndSettle();

      expect(find.text(modules['expenses']!.blurb), findsOneWidget);
    });

    testWidgets('a lead can be called or claimed, and they differ', (
      tester,
    ) async {
      await _pumpApp(tester);

      final lead = leads.first;
      await _scrollAndTap(tester, find.text(lead.name));
      expect(
        find.text('${lead.name} assigned to you — ${lead.source} lead'),
        findsOneWidget,
      );

      // The pill sits inside the row it just claimed, and has to win the tap.
      await tester.tap(find.text('CALL').first);
      await tester.pumpAndSettle();
      expect(find.text('Calling ${lead.name}…'), findsOneWidget);
    });
  });

  group('Profile', () {
    testWidgets('the header avatar opens the profile and backs out again', (
      tester,
    ) async {
      await _pumpApp(tester);

      await tester.tap(find.text(CurrentStaff.initials));
      await tester.pumpAndSettle();

      expect(find.text('My profile'), findsOneWidget);
      expect(find.text('ID ${CurrentStaff.employeeId}'.toUpperCase()), findsOneWidget);

      await tester.tap(find.text('‹'));
      await tester.pumpAndSettle();

      // Back onto Today, not onto some other tab.
      expect(find.text('Clock in'), findsOneWidget);
    });

    testWidgets('the profile is reachable from More as well', (tester) async {
      await _pumpApp(tester);
      await _tapTab(tester, 'More');

      await tester.tap(find.text(CurrentStaff.name));
      await tester.pumpAndSettle();

      expect(find.text('My profile'), findsOneWidget);
    });

    testWidgets('clocking in from the profile is the same shift', (
      tester,
    ) async {
      await _pumpApp(tester);
      await tester.tap(find.text(CurrentStaff.initials));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Clock in'));
      await tester.pumpAndSettle();
      expect(find.text('Clocked in 9:12'), findsOneWidget);

      await tester.tap(find.text('‹'));
      await tester.pumpAndSettle();

      // Today reflects the shift started on the profile screen.
      expect(find.text('END'), findsOneWidget);
    });

    testWidgets('a profile link lands on that module inside More', (
      tester,
    ) async {
      await _pumpApp(tester);
      await tester.tap(find.text(CurrentStaff.initials));
      await tester.pumpAndSettle();

      final module = modules['commission']!;
      await _scrollAndTap(tester, find.text(module.name));

      expect(find.text(module.blurb), findsOneWidget);
    });
  });

  group('Inventory', () {
    testWidgets('a filter narrows the list and the count follows', (
      tester,
    ) async {
      await _pumpApp(tester);
      await _tapTab(tester, 'Inventory');

      final sold = listings.where((l) => l.status == 'Sold').toList();
      await tester.tap(find.text('Sold'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          '${sold.length} of ${listings.length} properties · 4 branches',
        ),
        findsOneWidget,
      );
      expect(find.text(sold.single.name), findsOneWidget);
    });

    testWidgets('the cheque filter keeps only rentals that accept enough', (
      tester,
    ) async {
      await _pumpApp(tester);
      await _tapTab(tester, 'Inventory');

      await tester.tap(find.text('4+'));
      await tester.pumpAndSettle();

      for (final listing in listings) {
        final qualifies = (listing.cheques ?? 0) >= 4;
        expect(
          find.text(listing.name),
          qualifies ? findsOneWidget : findsNothing,
          reason: '${listing.name} accepts ${listing.cheques} cheques',
        );
      }
    });

    testWidgets('rental cards quote the cheque split, sales do not', (
      tester,
    ) async {
      await _pumpApp(tester);
      await _tapTab(tester, 'Inventory');

      final rental = listings.firstWhere((l) => l.cheques != null);
      final sale = listings.firstWhere((l) => l.cheques == null);

      expect(
        find.textContaining(rental.chequeTerm!),
        findsWidgets,
        reason: '${rental.name} should show "${rental.chequeTerm}"',
      );
      expect(sale.chequeTerm, isNull);
    });

    testWidgets('listing photos render from bundled assets', (tester) async {
      await _pumpApp(tester);
      await _tapTab(tester, 'Inventory');

      expect(find.byType(ListingPhoto), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a search with no matches explains itself', (tester) async {
      await _pumpApp(tester);
      await _tapTab(tester, 'Inventory');

      await tester.enterText(find.byType(TextField), 'zzzz-no-such-property');
      await tester.pumpAndSettle();

      expect(find.text('No properties match this search'), findsOneWidget);
    });

    testWidgets('clearing filters from the empty state restores the list', (
      tester,
    ) async {
      await _pumpApp(tester);
      await _tapTab(tester, 'Inventory');

      // Both a chip filter and a search, so the reset has to undo both.
      await tester.tap(find.text('Sold'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'zzzz-no-such-property');
      await tester.pumpAndSettle();

      await _scrollAndTap(tester, find.text('Clear filters'));

      expect(
        find.text(
          '${listings.length} of ${listings.length} properties · 4 branches',
        ),
        findsOneWidget,
      );
    });

    testWidgets('tapping a listing opens its detail', (tester) async {
      await _pumpApp(tester);
      await _tapTab(tester, 'Inventory');

      final listing = listings.first;
      await _scrollAndTap(tester, find.text(listing.name).first);

      // Section headers render through Eyebrow, which upper-cases them.
      expect(find.text(listing.price), findsOneWidget);
      expect(find.text('Documents'.toUpperCase()), findsOneWidget);

      await tester.scrollUntilVisible(find.text(listing.visits.first.who), 200);
      expect(find.text('Visit history'.toUpperCase()), findsOneWidget);
    });
  });

  group('Booking a visit', () {
    testWidgets('the form records the visit onto the property', (tester) async {
      final listing = listings.first;
      await _pumpApp(tester, at: '/inventory/${listing.id}');

      await _scrollAndTap(tester, find.text('Book a visit'));
      expect(find.text(listing.name), findsWidgets);

      await tester.enterText(find.byType(TextFormField).first, 'Aisha Rahman');
      await tester.tap(find.text('15:30'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Book visit'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(OpsListCard),
          matching: find.textContaining('Aisha Rahman — 15:30'),
        ),
        findsOneWidget,
        reason: 'the booking belongs in the visit history',
      );
      expect(
        find.text('${listing.visits.length + 1} visits'),
        findsOneWidget,
        reason: 'and the count should follow',
      );
    });

    testWidgets('a visit with no client named is refused', (tester) async {
      await _pumpApp(tester, at: '/inventory/${listings.first.id}');

      await _scrollAndTap(tester, find.text('Book a visit'));
      await tester.tap(find.text('Book visit'));
      await tester.pumpAndSettle();

      expect(find.text('Who is viewing?'), findsOneWidget);
    });

    testWidgets('cancelling books nothing', (tester) async {
      final listing = listings.first;
      await _pumpApp(tester, at: '/inventory/${listing.id}');

      await _scrollAndTap(tester, find.text('Book a visit'));
      await tester.enterText(find.byType(TextFormField).first, 'Never Booked');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Never Booked'), findsNothing);
      expect(find.text('${listing.visits.length} visits'), findsOneWidget);
    });
  });

  group('Moving a deal stage', () {
    testWidgets('the move follows the deal back to the pipeline list', (
      tester,
    ) async {
      // A deal that is not already in Documentation, so the move is a change.
      final deal = deals.firstWhere((d) => d.stage != 'Documentation');
      await _pumpApp(tester, at: '/deals/${deal.id}');

      await _scrollAndTap(tester, find.text('Move stage'));
      await tester.tap(find.text('Documentation').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move'));
      await tester.pumpAndSettle();

      expect(find.text('Stage moved to Documentation'), findsOneWidget);
      // Written onto the timeline, with where it came from.
      expect(
        find.text('Stage moved — ${deal.stage} to Documentation'),
        findsOneWidget,
      );

      // And the pipeline agrees: the deal now files under the new stage.
      await tester.tap(find.text('‹'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Documentation').first);
      await tester.pumpAndSettle();

      expect(
        find.text(deal.property),
        findsOneWidget,
        reason: 'a moved deal should appear under the filter it moved into',
      );
    });

    testWidgets('choosing the stage it is already in changes nothing', (
      tester,
    ) async {
      final deal = deals.first;
      await _pumpApp(tester, at: '/deals/${deal.id}');

      await _scrollAndTap(tester, find.text('Move stage'));
      await tester.tap(find.text('Move'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Stage moved'), findsNothing);
      expect(
        find.text('${deal.activity.length} entries'),
        findsOneWidget,
        reason: 'no timeline entry for a move that did not happen',
      );
    });

    testWidgets('moving backwards warns before it is confirmed', (
      tester,
    ) async {
      final deal = deals.firstWhere((d) => d.stage == 'Documentation');
      await _pumpApp(tester, at: '/deals/${deal.id}');

      await _scrollAndTap(tester, find.text('Move stage'));
      await tester.tap(find.text('New').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('moves the deal back a stage'), findsOneWidget);
    });
  });

  group('Deals', () {
    testWidgets('the pipeline summary counts only the filtered deals', (
      tester,
    ) async {
      await _pumpApp(tester);
      await _tapTab(tester, 'Deals');

      expect(
        find.text('${deals.length} deals · AED 22.1M weighted'),
        findsOneWidget,
      );

      final mine = deals.where((d) => d.owner == 'You').length;
      await tester.tap(find.text('Mine'));
      await tester.pumpAndSettle();

      expect(find.text('$mine deals · AED 22.1M weighted'), findsOneWidget);
    });

    testWidgets('a stage filter shows only that stage', (tester) async {
      await _pumpApp(tester);
      await _tapTab(tester, 'Deals');

      await tester.tap(find.text('Documentation'));
      await tester.pumpAndSettle();

      for (final deal in deals) {
        expect(
          find.text(deal.property),
          deal.stage == 'Documentation' ? findsOneWidget : findsNothing,
          reason: '${deal.property} is in ${deal.stage}',
        );
      }
    });

    testWidgets('a filter survives visiting another tab', (tester) async {
      await _pumpApp(tester);
      await _tapTab(tester, 'Deals');

      await tester.tap(find.text('Mine'));
      await tester.pumpAndSettle();
      await _tapTab(tester, 'Today');
      await _tapTab(tester, 'Deals');

      final mine = deals.where((d) => d.owner == 'You').length;
      expect(find.text('$mine deals · AED 22.1M weighted'), findsOneWidget);
    });

    testWidgets('opening a deal shows its commission and activity', (
      tester,
    ) async {
      await _pumpApp(tester);
      await _tapTab(tester, 'Deals');

      final deal = deals.first;
      await tester.tap(find.text(deal.property).first);
      await tester.pumpAndSettle();

      expect(find.text('Your commission'.toUpperCase()), findsOneWidget);
      expect(find.text(deal.commission), findsOneWidget);
      expect(find.text('Activity'.toUpperCase()), findsOneWidget);
    });

    testWidgets('a logged call lands on the deal timeline', (tester) async {
      await _pumpApp(tester);
      await _tapTab(tester, 'Deals');

      final deal = deals.first;
      await _scrollAndTap(tester, find.text(deal.property).first);
      await _scrollAndTap(tester, find.text('Log a call'));

      await tester.tap(find.text('Callback booked'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Wants a second viewing');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Call logged for ${deal.client}'), findsOneWidget);

      // The entry itself is on the timeline, newest first, and the count grew.
      await tester.scrollUntilVisible(
        find.text('${deal.activity.length + 1} entries'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text('Call — Callback booked · Wants a second viewing'),
        findsOneWidget,
      );
    });

    testWidgets('a call logged with no note still records the outcome', (
      tester,
    ) async {
      await _pumpApp(tester);
      await _tapTab(tester, 'Deals');

      await _scrollAndTap(tester, find.text(deals.first.property).first);
      await _scrollAndTap(tester, find.text('Log a call'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Call — Reached'), findsOneWidget);
    });

    testWidgets('cancelling the call sheet logs nothing', (tester) async {
      await _pumpApp(tester);
      await _tapTab(tester, 'Deals');

      final deal = deals.first;
      await _scrollAndTap(tester, find.text(deal.property).first);
      await _scrollAndTap(tester, find.text('Log a call'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Call —'), findsNothing);
      expect(find.text('${deal.activity.length} entries'), findsOneWidget);
    });

    testWidgets('a logged call is still there after leaving the deal', (
      tester,
    ) async {
      await _pumpApp(tester);
      await _tapTab(tester, 'Deals');

      final deal = deals.first;
      await _scrollAndTap(tester, find.text(deal.property).first);
      await _scrollAndTap(tester, find.text('Log a call'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Out of the deal, round another tab, and back in.
      await tester.tap(find.text('‹'));
      await tester.pumpAndSettle();
      await _tapTab(tester, 'Today');
      await _tapTab(tester, 'Deals');
      await _scrollAndTap(tester, find.text(deal.property).first);

      await tester.scrollUntilVisible(
        find.text('Call — Reached'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Call — Reached'), findsOneWidget);
    });

    testWidgets('a deal with a payment plan lists its cheques', (tester) async {
      await _pumpApp(tester);
      await _tapTab(tester, 'Deals');

      final deal = deals.firstWhere((d) => d.schedule.isNotEmpty);
      await tester.tap(find.text(deal.property).first);
      await tester.pumpAndSettle();

      expect(find.text('Payment schedule'.toUpperCase()), findsOneWidget);
      expect(
        find.text('${deal.chequesCleared} of ${deal.schedule.length} cleared'),
        findsOneWidget,
      );
      expect(find.text(deal.schedule.first.label), findsOneWidget);
      expect(find.text(deal.schedule.first.amount), findsOneWidget);
    });

    testWidgets('submitting a cheque confirms, records and retimelines it', (
      tester,
    ) async {
      final deal = deals.firstWhere((d) => d.schedule.isNotEmpty);
      final pending = deal.schedule.firstWhere((c) => c.status == 'Pending');
      await _pumpApp(tester, at: '/deals/${deal.id}');

      await _scrollAndTap(tester, find.text('SUBMIT').first);

      // It asks before claiming money has moved.
      expect(find.text('Submit this cheque?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
      await tester.pumpAndSettle();

      // The confirmation and the permanent record read the same, so each is
      // matched where it lives rather than by wording alone.
      final wording = '${pending.label} submitted — ${pending.amount}';

      expect(
        find.descendant(of: find.byType(SnackBar), matching: find.text(wording)),
        findsOneWidget,
        reason: 'the agent should be told it went through',
      );
      expect(
        find.descendant(
          of: find.byType(OpsListCard),
          matching: find.text(wording),
        ),
        findsOneWidget,
        reason: 'and it should be on the timeline, provable later',
      );

      // The row's own status moved, and the summary counts it.
      expect(find.text('SUBMITTED'), findsWidgets);
      expect(
        find.textContaining('1 submitted'),
        findsOneWidget,
        reason: 'the schedule header should count it',
      );
    });

    testWidgets('cancelling leaves the cheque pending', (tester) async {
      final deal = deals.firstWhere((d) => d.schedule.isNotEmpty);
      await _pumpApp(tester, at: '/deals/${deal.id}');

      await _scrollAndTap(tester, find.text('SUBMIT').first);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('SUBMITTED'), findsNothing);
      expect(find.textContaining('submitted'), findsNothing);
    });

    testWidgets('a cleared cheque offers no submit action', (tester) async {
      final deal = deals.firstWhere(
        (d) => d.schedule.any((c) => c.status == 'Cleared'),
      );
      final cleared = deal.schedule.where((c) => c.status == 'Cleared').length;
      final pending = deal.schedule.where((c) => c.status == 'Pending').length;
      await _pumpApp(tester, at: '/deals/${deal.id}');

      // One Submit per pending cheque, none for the cleared ones.
      expect(find.text('SUBMIT'), findsNWidgets(pending));
      expect(find.text('CLEARED'), findsNWidgets(cleared));
    });

    testWidgets('a deal with no plan agreed hides the schedule', (
      tester,
    ) async {
      final deal = deals.firstWhere((d) => d.schedule.isEmpty);
      await _pumpApp(tester, at: '/deals/${deal.id}');

      expect(find.text('Payment schedule'.toUpperCase()), findsNothing);
      expect(find.text('Activity'.toUpperCase()), findsOneWidget);
    });
  });

  group('Team approvals', () {
    testWidgets('approving clears the request and says so', (tester) async {
      await _pumpApp(tester);
      await _tapTab(tester, 'Team');

      final request = requests.first;
      final label = '${request.who} — ${request.what}';
      expect(find.text(label), findsOneWidget);

      await tester.tap(find.text('Approve').first);
      await tester.pumpAndSettle();

      expect(find.text(label), findsNothing);
      expect(
        find.text('Approved — ${request.who}, ${request.what}'),
        findsOneWidget,
      );
    });

    testWidgets('declining is reported as a decline, not an approval', (
      tester,
    ) async {
      await _pumpApp(tester);
      await _tapTab(tester, 'Team');

      final request = requests.first;
      await tester.tap(find.text('Decline').first);
      await tester.pumpAndSettle();

      expect(
        find.text('Declined — ${request.who}, ${request.what}'),
        findsOneWidget,
      );
    });

    testWidgets('the section disappears once every request is handled', (
      tester,
    ) async {
      await _pumpApp(tester);
      await _tapTab(tester, 'Team');

      for (var i = 0; i < requests.length; i++) {
        await tester.tap(find.text('Approve').first);
        await tester.pumpAndSettle();
      }

      expect(find.text('Awaiting your approval'.toUpperCase()), findsNothing);
      expect(find.text('Roster'.toUpperCase()), findsOneWidget);
    });

    testWidgets('tapping a roster row opens that person', (tester) async {
      await _pumpApp(tester);
      await _tapTab(tester, 'Team');

      final person = team.first;
      await tester.tap(find.text(person.name));
      await tester.pumpAndSettle();

      expect(find.text('Attendance this week'.toUpperCase()), findsOneWidget);
      expect(find.text('Assigned work'.toUpperCase()), findsOneWidget);
    });
  });

  group('More', () {
    // What confirming actually *does* is covered end-to-end in auth_test.dart,
    // where the router carries the sign-in gate; here it is only that the
    // control asks first rather than firing on the first tap.
    testWidgets('signing out asks first, and cancelling changes nothing', (
      tester,
    ) async {
      await _pumpApp(tester);
      await _tapTab(tester, 'More');

      await _scrollAndTap(tester, find.text('Sign out'));
      expect(find.text('Sign out?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Sign out?'), findsNothing);
      expect(find.text('More'), findsWidgets);
    });

    testWidgets('every listed module opens its detail screen', (tester) async {
      await _pumpApp(tester);

      for (final (_, keys) in moreGroups) {
        for (final key in keys) {
          await _tapTab(tester, 'More');
          final module = modules[key]!;

          await _scrollAndTap(tester, find.text(module.name));

          expect(
            find.text(module.blurb),
            findsOneWidget,
            reason: '$key should open its own detail',
          );
        }
      }
    });
  });

  group('other form factors', () {
    // The screens claim to render under the ambient light M3 theme behind the
    // navigation rail as well as the forced-dark phone theme, because they
    // read ColorScheme/EstateOpsExtras rather than literal hex. These pin that
    // claim down — including the stat grids, which are the part most likely to
    // clip when the type metrics change.
    testWidgets('every tab renders on a desktop-width light theme', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: ThemeData.light(),
            routerConfig: createRouter(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NavigationRail), findsOneWidget);

      for (final tab in const ['Inventory', 'Deals', 'Team', 'More']) {
        await tester.tap(find.text(tab).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$tab should render');
      }
    });

    testWidgets('the profile renders on the ambient light theme too', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: ThemeData.light(),
            routerConfig: createRouter(initialLocation: '/profile'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('My profile'), findsOneWidget);
      expect(find.text(CurrentStaff.name), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the Android build shows pill nav instead of a tab bar', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      await _pumpApp(tester);

      expect(find.text('Clock in'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Each destination carries an icon in its pill, and the selected tab
      // shows the filled variant.
      expect(find.byIcon(Icons.today), findsOneWidget);
      expect(find.byIcon(Icons.apartment_outlined), findsOneWidget);
      expect(find.byIcon(Icons.handshake_outlined), findsOneWidget);
      expect(find.byIcon(Icons.groups_outlined), findsOneWidget);
      expect(find.byIcon(Icons.more_horiz_outlined), findsOneWidget);

      // Has to be cleared inside the body: the framework asserts that no
      // foundation debug variable outlives the test, and that check runs
      // before tear-downs.
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('deep links', () {
    testWidgets('a valid deal link opens that deal directly', (tester) async {
      final deal = deals.last;
      await _pumpApp(tester, at: '/deals/${deal.id}');

      expect(find.text(deal.commission), findsOneWidget);
    });

    testWidgets('an unknown record renders not-found instead of throwing', (
      tester,
    ) async {
      for (final path in const [
        '/deals/does-not-exist',
        '/inventory/does-not-exist',
        '/team/does-not-exist',
        '/more/does-not-exist',
      ]) {
        await _pumpApp(tester, at: path);

        expect(
          find.byType(OpsNotFoundPage),
          findsOneWidget,
          reason: '$path should land on the not-found screen',
        );
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('back from a deep-linked detail leaves the detail', (
      tester,
    ) async {
      await _pumpApp(tester, at: '/deals/${deals.first.id}');

      await tester.tap(find.text('‹'));
      await tester.pumpAndSettle();

      expect(find.text('Log a call'), findsNothing);
    });
  });
}
