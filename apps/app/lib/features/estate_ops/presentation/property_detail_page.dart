import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/estate_ops_data.dart';
import '../state/estate_ops_state.dart';
import 'widgets/book_visit_sheet.dart';
import 'widgets/estate_widgets.dart';
import 'widgets/photo_placeholder.dart';

class PropertyDetailPage extends ConsumerWidget {
  const PropertyDetailPage({super.key, required this.listingId});

  final String listingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listing = findListing(listingId);
    if (listing == null) {
      return const OpsNotFoundPage(
        title: 'Property',
        message: 'This listing is no longer in the inventory.',
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final visits = ref.watch(estateOpsProvider).visitsFor(listing);

    return Scaffold(
      appBar: OpsDetailAppBar(title: listing.name),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: ListingPhoto(asset: listing.photo, height: 170),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.name,
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.4,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${listing.config} · ${listing.area}',
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                listing.price,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          StatGrid(
            stats: [
              ...listing.specs,
              // Kept out of the seed specs so the cheque count has one home:
              // Listing.cheques, which the card and the filter also read.
              if (listing.chequeTerm case final term?) (k: 'Payment', v: term),
            ],
            columns: 2,
          ),
          const SizedBox(height: 18),
          const SectionHeader(title: 'Documents'),
          OpsListCard(
            children: [
              for (final d in listing.docs)
                OpsRow(
                  title: d.name,
                  trailing: StatusPill(d.state),
                  onTap: () =>
                      showOpsSnack(context, 'Opening ${d.name} — ${d.state}'),
                ),
            ],
          ),
          const SizedBox(height: 18),
          SectionHeader(
            title: 'Visit history',
            trailing: '${visits.length} visits',
          ),
          OpsListCard(
            children: [
              for (final v in visits)
                OpsRow(
                  title: v.who,
                  trailing: Text(
                    v.when,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  onTap: () => showOpsSnack(
                    context,
                    '${v.who} · viewed ${v.when}',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () async {
                    final visit = await showBookVisitSheet(
                      context,
                      property: listing.name,
                    );
                    if (visit == null || !context.mounted) return;
                    opsTick();
                    ref
                        .read(estateOpsProvider.notifier)
                        .bookVisit(listing.id, visit);
                    showOpsSnack(
                      context,
                      'Visit booked — ${visit.who}, ${visit.when}',
                    );
                  },
                  child: const Text('Book a visit'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => showOpsSnack(context, 'Share sheet opened'),
                  child: const Text('Share'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
