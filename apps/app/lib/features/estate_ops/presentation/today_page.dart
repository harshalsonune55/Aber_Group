import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/state/auth_controller.dart';
import '../data/estate_ops_data.dart';
import '../state/estate_ops_state.dart';
import 'widgets/estate_widgets.dart';
import 'widgets/new_lead_sheet.dart';

class TodayPage extends ConsumerWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ops = ref.watch(estateOpsProvider);
    final notifier = ref.read(estateOpsProvider.notifier);
    final staff = ref.watch(currentStaffProvider);
    final leftTasks = tasks
        .where((t) => !ops.doneTaskIds.contains(t.id))
        .length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Eyebrow(_todayLabel()),
                  const SizedBox(height: 8),
                  Text(
                    '${_greeting()}, ${staff.firstName}',
                    style: TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.6,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            InitialsAvatar(
              staff.initials,
              size: 40,
              semanticLabel: 'Open your profile',
              onTap: () => context.push('/profile'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _CheckInCard(
          checkedIn: ops.checkedIn,
          onTap: () {
            opsTick();
            notifier.toggleCheckedIn();
          },
        ),
        const SizedBox(height: 12),
        StatGrid(
          stats: kpis,
          // Each KPI is a shortcut to the screen it counts, so the numbers are
          // a way in rather than a read-out.
          onStatTap: (stat) => context.go(switch (stat.k) {
            'Open deals' => '/deals',
            'Visits wk' => '/inventory',
            _ => '/more/commission',
          }),
        ),
        const SizedBox(height: 12),
        _QuickActions(
          onAddLead: () async {
            final lead = await showNewLeadSheet(context);
            if (lead == null || !context.mounted) return;
            notifier.captureLead(lead);
            showOpsSnack(context, '${lead.name} added to your leads');
          },
        ),
        const SizedBox(height: 26),
        SectionHeader(
          title: 'Site visits today',
          trailing: '${todaysVisits.length} scheduled',
        ),
        Column(
          children: [
            for (final v in todaysVisits) ...[
              _VisitCard(
                visit: v,
                // `go` rather than `push`: the property lives in the Inventory
                // branch, so this opens it there with the list beneath it —
                // backing out lands on Inventory, not on a detail stranded
                // over Today.
                onTap: v.listingId == null
                    ? null
                    : () => context.go('/inventory/${v.listingId}'),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
        const SizedBox(height: 18),
        SectionHeader(
          title: 'New leads',
          trailing: '${ops.allLeads.length} unassigned',
        ),
        OpsListCard(
          children: [
            for (final l in ops.allLeads)
              OpsRow(
                title: l.name,
                subtitle: '${l.want} · ${l.source}',
                // The pill is the quick action; the rest of the row claims the
                // lead so an agent can pick it up without ringing first.
                trailing: OutlinedTag(
                  'Call',
                  onTap: () => showOpsSnack(context, 'Calling ${l.name}…'),
                ),
                onTap: () => showOpsSnack(
                  context,
                  '${l.name} assigned to you — ${l.source} lead',
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),
        SectionHeader(
          title: 'Tasks',
          trailing: leftTasks == 0 ? 'All clear' : '$leftTasks left',
        ),
        OpsListCard(
          children: [
            for (final t in tasks)
              _TaskRow(
                task: t,
                done: ops.doneTaskIds.contains(t.id),
                onToggle: () {
                  opsTick();
                  notifier.toggleTask(t.id);
                },
              ),
          ],
        ),
      ],
    );
  }

  /// The date beside it is real, so the greeting tracks the clock too — a
  /// hardcoded "Morning" reads as broken to anyone on an evening shift.
  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }

  String _todayLabel() {
    final now = DateTime.now();
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${weekdays[now.weekday - 1]} ${now.day} ${months[now.month - 1]}';
  }
}

class _CheckInCard extends StatelessWidget {
  const _CheckInCard({required this.checkedIn, required this.onTap});

  final bool checkedIn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (checkedIn) {
      return Material(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ON SHIFT · ${CurrentStaff.branch.toUpperCase()}',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                          color: scheme.onPrimary.withValues(alpha: 0.55),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        'Clocked in 9:12',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                          color: scheme.onPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: scheme.onPrimary.withValues(alpha: 0.25),
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'END',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: scheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Eyebrow('Shift not started · geo-verified'),
                    const SizedBox(height: 7),
                    Text(
                      'Clock in',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                        color: scheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward,
                  size: 18,
                  color: scheme.onPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onAddLead});

  /// Capturing a lead is the one quick action that creates a record rather
  /// than jumping to a screen, so it comes in as a callback instead of a path.
  final VoidCallback onAddLead;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final actions = <(String, String, VoidCallback)>[
      ('+', 'Add lead', onAddLead),
      ('⌂', 'Inventory', () => context.go('/inventory')),
      ('◷', 'Visits', () => context.go('/inventory')),
      ('AED', 'Claim', () => context.go('/more/expenses')),
    ];
    return Row(
      children: [
        for (final (index, action) in actions.indexed) ...[
          Expanded(
            child: Material(
              color: scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: action.$3,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: scheme.outlineVariant),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 6,
                  ),
                  child: Column(
                    children: [
                      Text(
                        action.$1,
                        style: TextStyle(
                          fontSize: action.$1.length > 1 ? 12 : 16,
                          fontWeight: FontWeight.w500,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        action.$2,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (index != actions.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _VisitCard extends StatelessWidget {
  const _VisitCard({required this.visit, this.onTap});

  final ScheduledVisit visit;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return OpsCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      // The design's divider is `align-self:stretch`. A bare stretch Row inside
      // a scroll view has an unbounded height, so the rule has to resolve
      // against the tallest child instead.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 52,
              child: Text(
                visit.time,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: scheme.onSurface,
                ),
              ),
            ),
            Container(width: 1, color: scheme.outlineVariant),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    visit.property,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${visit.client} · ${visit.area}',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.task,
    required this.done,
    required this.onToggle,
  });

  final Task task;
  final bool done;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            if (done)
              Container(
                width: 21,
                height: 21,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check, size: 13, color: scheme.onPrimary),
              )
            else
              Container(
                width: 21,
                height: 21,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.outline, width: 1.5),
                ),
              ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: done ? FontWeight.w400 : FontWeight.w500,
                      decoration: done ? TextDecoration.lineThrough : null,
                      color: done ? scheme.onSurfaceVariant : scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    task.meta,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
