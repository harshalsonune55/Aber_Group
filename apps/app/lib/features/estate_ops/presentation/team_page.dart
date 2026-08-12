import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/estate_ops_extras.dart';
import '../data/estate_ops_data.dart';
import '../state/estate_ops_state.dart';
import 'widgets/estate_widgets.dart';

class TeamPage extends ConsumerWidget {
  const TeamPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final extras = context.estateExtras;
    final ops = ref.watch(estateOpsProvider);
    final notifier = ref.read(estateOpsProvider.notifier);
    final openRequests = requests.where((r) => !ops.isHandled(r.id)).toList();

    void resolve(ApprovalRequest request, RequestOutcome outcome) {
      opsTick();
      notifier.resolveRequest(request.id, outcome);
      showOpsSnack(
        context,
        '${outcome.label} — ${request.who}, ${request.what}',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        const PageTitle(
          title: 'Team',
          subtitle: '18 staff · 12 clocked in · 1 on leave',
        ),
        const SizedBox(height: 16),
        StatGrid(stats: attendanceStats),
        if (openRequests.isNotEmpty) ...[
          const SizedBox(height: 22),
          const SectionHeader(title: 'Awaiting your approval'),
          Column(
            children: [
              for (final r in openRequests) ...[
                _RequestCard(
                  request: r,
                  extras: extras,
                  onApprove: () => resolve(r, RequestOutcome.approved),
                  onDecline: () => resolve(r, RequestOutcome.declined),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ],
        const SizedBox(height: 24),
        const SectionHeader(title: 'Roster'),
        OpsListCard(
          children: [
            for (final p in team)
              OpsRow(
                leading: InitialsAvatar(p.initials),
                title: p.name,
                subtitle: p.role,
                trailing: Text(
                  p.status.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                    color: scheme.onSurface,
                  ),
                ),
                onTap: () => context.push('/team/${p.id}'),
              ),
          ],
        ),
      ],
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.extras,
    required this.onApprove,
    required this.onDecline,
  });

  final ApprovalRequest request;
  final EstateOpsExtras extras;
  final VoidCallback onApprove;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: extras.requestCard,
        border: Border.all(color: extras.requestBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${request.who} — ${request.what}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            request.when,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: kMinTapTarget,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: onApprove,
                    child: const Text('Approve'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: kMinTapTarget,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: onDecline,
                    child: const Text('Decline'),
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
