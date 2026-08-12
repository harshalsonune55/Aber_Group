import 'dart:io';

import 'package:aber_app/features/estate_ops/data/estate_ops_data.dart';
import 'package:aber_app/features/estate_ops/state/estate_ops_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EstateOpsNotifier', () {
    late EstateOpsNotifier notifier;

    setUp(() => notifier = EstateOpsNotifier());
    tearDown(() => notifier.dispose());

    test('starts off shift with nothing done and no filters applied', () {
      expect(notifier.state.checkedIn, isFalse);
      expect(notifier.state.doneTaskIds, isEmpty);
      expect(notifier.state.requestOutcomes, isEmpty);
      expect(notifier.state.dealFilter, 'All');
      expect(notifier.state.listingFilter, 'All');
    });

    test('check-in toggles both ways', () {
      notifier.toggleCheckedIn();
      expect(notifier.state.checkedIn, isTrue);

      notifier.toggleCheckedIn();
      expect(notifier.state.checkedIn, isFalse);
    });

    test('a task can be completed and un-completed', () {
      notifier.toggleTask('t1');
      expect(notifier.state.doneTaskIds, contains('t1'));

      notifier.toggleTask('t1');
      expect(notifier.state.doneTaskIds, isNot(contains('t1')));
    });

    test('completing one task leaves the others alone', () {
      notifier
        ..toggleTask('t1')
        ..toggleTask('t3');

      expect(notifier.state.doneTaskIds, {'t1', 't3'});
    });

    test('resolving a request records which way it went', () {
      notifier.resolveRequest('r1', RequestOutcome.approved);
      notifier.resolveRequest('r2', RequestOutcome.declined);

      expect(notifier.state.requestOutcomes['r1'], RequestOutcome.approved);
      expect(notifier.state.requestOutcomes['r2'], RequestOutcome.declined);
      expect(notifier.state.isHandled('r1'), isTrue);
      expect(notifier.state.isHandled('r3'), isFalse);
    });

    test('filters are independent of each other', () {
      notifier.setDealFilter('Mine');
      notifier.setListingFilter('Sold');

      expect(notifier.state.dealFilter, 'Mine');
      expect(notifier.state.listingFilter, 'Sold');
    });

    test('state updates do not mutate the previous state object', () {
      notifier.toggleTask('t1');
      final before = notifier.state;

      notifier.toggleTask('t2');

      expect(before.doneTaskIds, {'t1'});
      expect(notifier.state.doneTaskIds, {'t1', 't2'});
    });

    test('a captured lead lands above the ones already waiting', () {
      const first = Lead(name: 'Aisha Rahman', want: 'Villa', source: 'Call');
      const second = Lead(name: 'Tom Reid', want: 'Office', source: 'Website');

      notifier.captureLead(first);
      notifier.captureLead(second);

      // Newest first, then the seeded backlog underneath.
      expect(
        notifier.state.allLeads.take(2).map((l) => l.name),
        ['Tom Reid', 'Aisha Rahman'],
      );
      expect(notifier.state.allLeads.length, leads.length + 2);
    });

    test('capturing a lead leaves the seed list alone', () {
      final seedCountBefore = leads.length;
      notifier.captureLead(
        const Lead(name: 'Aisha Rahman', want: 'Villa', source: 'Call'),
      );

      expect(leads.length, seedCountBefore);
      expect(notifier.state.capturedLeads.single.name, 'Aisha Rahman');
    });
  });

  group('deep-link lookups', () {
    test('resolve a record that exists', () {
      expect(findDeal(deals.first.id)?.property, deals.first.property);
      expect(findListing(listings.first.id)?.name, listings.first.name);
      expect(findTeamMember(team.first.id)?.name, team.first.name);
    });

    test('return null rather than throwing for an unknown id', () {
      expect(findDeal('nope'), isNull);
      expect(findListing('nope'), isNull);
      expect(findTeamMember('nope'), isNull);
      expect(modules['nope'], isNull);
    });
  });

  group('seed data', () {
    test('ids are unique, so a deep link resolves to one record', () {
      expect(deals.map((d) => d.id).toSet(), hasLength(deals.length));
      expect(listings.map((l) => l.id).toSet(), hasLength(listings.length));
      expect(team.map((p) => p.id).toSet(), hasLength(team.length));
      expect(tasks.map((t) => t.id).toSet(), hasLength(tasks.length));
      expect(requests.map((r) => r.id).toSet(), hasLength(requests.length));
    });

    test('every module the More screen links to exists', () {
      for (final (_, keys) in moreGroups) {
        for (final key in keys) {
          expect(modules[key], isNotNull, reason: '$key should be a module');
        }
      }
      expect(modules['admin'], isNotNull);
    });

    test('every deal filter matches at least one deal', () {
      for (final filter in dealFilters) {
        final matches = deals.where((d) {
          return switch (filter) {
            'All' => true,
            'Mine' => d.owner == 'You',
            _ => d.stage == filter,
          };
        });
        expect(matches, isNotEmpty, reason: '"$filter" should show something');
      }
    });

    test('only rentals carry a cheque count', () {
      for (final listing in listings) {
        if (listing.kind == 'Sale') {
          expect(
            listing.cheques,
            isNull,
            reason: '${listing.name} is a sale, so rent is not split',
          );
        } else {
          expect(
            listing.cheques,
            isNotNull,
            reason: '${listing.name} is a rental and needs a cheque term',
          );
        }
      }
    });

    test('the cheque term reads naturally and matches the count', () {
      for (final listing in listings.where((l) => l.cheques != null)) {
        expect(listing.chequeTerm, '${listing.cheques} cheques');
      }
      // Singular is not pluralised, for the rare one-cheque landlord.
      const single = Listing(
        id: 'x',
        name: 'x',
        config: 'x',
        area: 'x',
        price: 'x',
        status: 'For rent',
        agent: 'x',
        kind: 'Rent',
        specs: [],
        docs: [],
        visits: [],
        cheques: 1,
      );
      expect(single.chequeTerm, '1 cheque');
    });

    test('cheque filters map to the minimum they promise', () {
      expect(minChequesFor('Any'), isNull);
      expect(minChequesFor('1+'), 1);
      expect(minChequesFor('4+'), 4);
      expect(minChequesFor('6+'), 6);
    });

    test('a deal schedule counts its cleared cheques', () {
      for (final deal in deals) {
        final cleared = deal.schedule
            .where((c) => c.status == 'Cleared')
            .length;
        expect(deal.chequesCleared, cleared);
        expect(deal.chequesCleared, lessThanOrEqualTo(deal.schedule.length));
      }
    });

    test('every listing photo points at a bundled asset', () {
      for (final listing in listings) {
        if (listing.photo case final path?) {
          expect(path, startsWith('assets/listings/'));
          expect(
            File(path).existsSync(),
            isTrue,
            reason: '$path should exist on disk for ${listing.name}',
          );
        }
      }
    });

    test('every listing filter matches at least one listing', () {
      for (final filter in listingFilters) {
        final matches = listings.where((p) {
          return switch (filter) {
            'All' => true,
            'Under offer' => p.status == 'Under offer',
            'Sold' => p.status == 'Sold',
            _ => p.kind == filter,
          };
        });
        expect(matches, isNotEmpty, reason: '"$filter" should show something');
      }
    });
  });
}
