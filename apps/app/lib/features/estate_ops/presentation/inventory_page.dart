import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/estate_ops_data.dart';
import '../state/estate_ops_state.dart';
import 'widgets/estate_widgets.dart';
import 'widgets/photo_placeholder.dart';

class InventoryPage extends ConsumerStatefulWidget {
  const InventoryPage({super.key});

  @override
  ConsumerState<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends ConsumerState<InventoryPage> {
  final _query = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ops = ref.watch(estateOpsProvider);
    final filter = ops.listingFilter;
    final chequeFilter = ops.chequeFilter;
    final notifier = ref.read(estateOpsProvider.notifier);
    final minCheques = minChequesFor(chequeFilter);

    final filtered = listings.where((p) {
      final matchesFilter = switch (filter) {
        'All' => true,
        'Under offer' => p.status == 'Under offer',
        'Sold' => p.status == 'Sold',
        _ => p.kind == filter,
      };
      // A cheque count only exists on rentals, so asking for one excludes
      // sales rather than silently ignoring the filter.
      final matchesCheques =
          minCheques == null || (p.cheques != null && p.cheques! >= minCheques);
      final text = '${p.name} ${p.config}'.toLowerCase();
      final matchesSearch = text.contains(_search.toLowerCase());
      return matchesFilter && matchesCheques && matchesSearch;
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        PageTitle(
          title: 'Inventory',
          subtitle:
              '${filtered.length} of ${listings.length} properties · 4 branches',
        ),
        const SizedBox(height: 16),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              Icon(Icons.search, size: 17, color: scheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _query,
                  textInputAction: TextInputAction.search,
                  onChanged: (value) => setState(() => _search = value),
                  style: TextStyle(fontSize: 13.5, color: scheme.onSurface),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: 'Search by area, code or owner',
                    hintStyle: TextStyle(
                      fontSize: 13.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              // Clearing a search on a phone otherwise means holding backspace
              // through the whole query.
              if (_search.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.close, size: 17),
                  color: scheme.onSurfaceVariant,
                  tooltip: 'Clear search',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: kMinTapTarget,
                    height: kMinTapTarget,
                  ),
                  onPressed: () {
                    _query.clear();
                    setState(() => _search = '');
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FilterChips(
          options: listingFilters,
          selected: filter,
          onSelected: notifier.setListingFilter,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Padding(
              padding: EdgeInsets.only(right: 10),
              child: Eyebrow('Cheques'),
            ),
            Expanded(
              child: FilterChips(
                options: chequeFilters,
                selected: chequeFilter,
                onSelected: notifier.setChequeFilter,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Column(
          children: [
            for (final p in filtered) ...[
              _ListingCard(
                listing: p,
                onTap: () => context.push('/inventory/${p.id}'),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 32),
            child: Column(
              children: [
                Text(
                  'No properties match this search',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 14),
                // Two filter rows plus a search box can combine into an empty
                // list without it being obvious which one is to blame, so the
                // way out is one tap rather than three.
                OutlinedButton(
                  onPressed: () {
                    _query.clear();
                    setState(() => _search = '');
                    notifier.clearListingFilters();
                  },
                  child: const Text('Clear filters'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ListingCard extends StatelessWidget {
  const _ListingCard({required this.listing, required this.onTap});

  final Listing listing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListingPhoto(asset: listing.photo, height: 110),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.2,
                                  color: scheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                [
                                  listing.config,
                                  listing.area,
                                  // Rent is quoted with its cheque split here,
                                  // the way the portals list it.
                                  ?listing.chequeTerm,
                                ].join(' · '),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          listing.price,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        StatusPill(listing.status),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            listing.agent,
                            textAlign: TextAlign.end,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
