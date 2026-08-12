import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/estate_ops_data.dart';
import '../state/estate_ops_state.dart';
import 'widgets/estate_widgets.dart';
import 'widgets/log_call_sheet.dart';
import 'widgets/move_stage_sheet.dart';

class DealDetailPage extends ConsumerWidget {
  const DealDetailPage({super.key, required this.dealId});

  final String dealId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deal = findDeal(dealId);
    if (deal == null) {
      return const OpsNotFoundPage(
        title: 'Deal',
        message: 'This deal is no longer in your pipeline.',
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final ops = ref.watch(estateOpsProvider);
    final notifier = ref.read(estateOpsProvider.notifier);
    final activity = ops.activityFor(deal);

    return Scaffold(
      appBar: OpsDetailAppBar(title: deal.property),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Eyebrow(ops.stageOf(deal)),
          const SizedBox(height: 10),
          Text(
            deal.value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.4,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${deal.client} · ${deal.type}',
            style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: DetailStatCard(
                  label: 'Your commission',
                  value: deal.commission,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DetailStatCard(label: 'Closing', value: deal.closing),
              ),
            ],
          ),
          if (deal.schedule.isNotEmpty) ...[
            const SizedBox(height: 20),
            SectionHeader(
              title: 'Payment schedule',
              trailing: _scheduleSummary(deal, ops.submittedCountFor(deal)),
            ),
            OpsListCard(
              children: [
                for (final cheque in deal.schedule)
                  _ChequeRow(
                    deal: deal,
                    cheque: cheque,
                    status: ops.chequeStatus(deal.id, cheque),
                    canSubmit: ops.canSubmitCheque(deal.id, cheque),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          SectionHeader(
            title: 'Activity',
            trailing: '${activity.length} entries',
          ),
          OpsListCard(
            children: [
              for (final a in activity)
                OpsRow(title: a.what, subtitle: '${a.when} · ${a.who}'),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () async {
                    final entry = await showLogCallSheet(
                      context,
                      client: deal.client,
                    );
                    if (entry == null || !context.mounted) return;
                    opsTick();
                    notifier.logActivity(deal.id, entry);
                    showOpsSnack(context, 'Call logged for ${deal.client}');
                  },
                  child: const Text('Log a call'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final from = ops.stageOf(deal);
                    final to = await showMoveStageSheet(
                      context,
                      property: deal.property,
                      current: from,
                    );
                    if (to == null || !context.mounted) return;
                    opsTick();
                    notifier.moveDealStage(
                      deal.id,
                      from: from,
                      to: to,
                      when: opsTimestamp(),
                    );
                    showOpsSnack(context, 'Stage moved to $to');
                  },
                  child: const Text('Move stage'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "2 of 6 cleared · 1 submitted".
///
/// The submitted count only appears once there is one, so a schedule nobody
/// has touched reads exactly as it did before.
String _scheduleSummary(Deal deal, int submitted) {
  final cleared = '${deal.chequesCleared} of ${deal.schedule.length} cleared';
  return submitted == 0 ? cleared : '$cleared · $submitted submitted';
}

/// One cheque in the payment schedule.
///
/// A pending cheque is the only one with an action on it, and it says so —
/// "Submit" rather than a row that merely happens to be tappable, because
/// handing a cheque to the bank is not something to discover by accident.
class _ChequeRow extends ConsumerWidget {
  const _ChequeRow({
    required this.deal,
    required this.cheque,
    required this.status,
    required this.canSubmit,
  });

  final Deal deal;
  final Cheque cheque;
  final String status;
  final bool canSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return OpsRow(
      title: cheque.label,
      subtitle: 'Due ${cheque.due}',
      onTap: canSubmit
          ? () => _confirm(context, ref)
          : () => showOpsSnack(
              context,
              '${cheque.label} · ${cheque.amount} · $status',
            ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            cheque.amount,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 5),
          // The action replaces the status rather than sitting beside it: a
          // "PENDING" pill next to a "SUBMIT" button says the same thing
          // twice, and the pair overflows the row at a large text scale.
          // Submit showing *is* what pending looks like.
          if (canSubmit)
            OutlinedTag('Submit', onTap: () => _confirm(context, ref))
          else
            StatusPill(status),
        ],
      ),
    );
  }

  /// Confirms before recording it. Submitting a cheque is a claim about money
  /// having physically moved, and the agent is the only one who can say so —
  /// a mis-tap here is a figure someone reconciles against later.
  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Submit this cheque?'),
        content: Text(
          '${cheque.label} · ${cheque.amount}, due ${cheque.due}.\n\n'
          'This records it as handed in to the bank. Clearing is confirmed by '
          'the bank separately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    opsTick();
    ref
        .read(estateOpsProvider.notifier)
        .submitCheque(deal.id, cheque, when: opsTimestamp());
    showOpsSnack(context, '${cheque.label} submitted — ${cheque.amount}');
  }
}
