import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/estate_ops_data.dart';
import '../state/estate_ops_state.dart';
import 'widgets/estate_widgets.dart';

class DealsPage extends ConsumerWidget {
  const DealsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final ops = ref.watch(estateOpsProvider);
    final filter = ops.dealFilter;
    final notifier = ref.read(estateOpsProvider.notifier);

    // Filters on the *current* stage, not the seeded one, so a deal moved on
    // its detail page immediately files itself under the right filter here.
    final filtered = deals.where((d) {
      return switch (filter) {
        'All' => true,
        'Mine' => d.owner == 'You',
        _ => ops.stageOf(d) == filter,
      };
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        PageTitle(
          title: 'Pipeline',
          // Counts what is on screen, so the summary tracks the filter.
          subtitle: '${filtered.length} deals · AED 22.1M weighted',
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            for (final (index, s) in stageBars.indexed) ...[
              Expanded(child: _StageBar(stat: s)),
              if (index != stageBars.length - 1) const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 14),
        FilterChips(
          options: dealFilters,
          selected: filter,
          onSelected: notifier.setDealFilter,
        ),
        const SizedBox(height: 14),
        Column(
          children: [
            for (final d in filtered) ...[
              _DealCard(
                deal: d,
                stage: ops.stageOf(d),
                onTap: () => context.push('/deals/${d.id}'),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 32),
            child: Center(
              child: Text(
                'No deals match this filter',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          ),
      ],
    );
  }
}

class _StageBar extends StatelessWidget {
  const _StageBar({required this.stat});

  final Stat stat;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            stat.v,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Eyebrow(stat.k),
        ],
      ),
    );
  }
}

class _DealCard extends StatelessWidget {
  const _DealCard({
    required this.deal,
    required this.stage,
    required this.onTap,
  });

  final Deal deal;
  final String stage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return OpsCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      onTap: onTap,
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
                      deal.property,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${deal.client} · ${deal.owner}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                deal.value,
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
              StatusPill(stage),
              const SizedBox(width: 8),
              // Stage names and ages are both free text; let the age give way
              // rather than overflow the card.
              Expanded(
                child: Text(
                  deal.age,
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
    );
  }
}
