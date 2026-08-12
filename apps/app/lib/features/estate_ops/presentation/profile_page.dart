import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/state/auth_controller.dart';
import '../data/estate_ops_data.dart';
import '../state/estate_ops_state.dart';
import 'widgets/estate_widgets.dart';

/// The signed-in staff member's own profile.
///
/// Sits on the root navigator rather than inside a tab: the header avatar is
/// on every screen, so opening the profile must not yank the user to a
/// different tab and lose where they were. It covers the shell instead, and
/// backing out returns them to the tab they came from.
///
/// The links out go through `context.go`, which closes this page and lands on
/// the module inside the More tab — the module's own back button then returns
/// to More, which is where a staff member expects to end up rather than back
/// on a profile they are done with.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final ops = ref.watch(estateOpsProvider);
    final notifier = ref.read(estateOpsProvider.notifier);
    final staff = ref.watch(currentStaffProvider);

    return Scaffold(
      appBar: const OpsDetailAppBar(title: 'My profile'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Row(
            children: [
              InitialsAvatar(staff.initials, size: 64),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      staff.name,
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.4,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${staff.role} · ${staff.branch}',
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    StatusPill('ID ${staff.employeeId}'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _ShiftCard(
            checkedIn: ops.checkedIn,
            onToggle: () {
              notifier.toggleCheckedIn();
              showOpsSnack(
                context,
                ops.checkedIn
                    ? 'Shift ended — timesheet updated'
                    : 'Clocked in at ${staff.branch}',
              );
            },
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'This month'),
          const StatGrid(stats: profileStats, columns: 3),
          const SizedBox(height: 22),
          const SectionHeader(title: 'Contact'),
          OpsListCard(
            children: [
              for (final (label, value, message) in [
                (
                  'Work email',
                  staff.email,
                  'Email copied to the clipboard',
                ),
                const ('Mobile', '+971 50 xxx 4120', 'Calling your own number?'),
                const (
                  'Manager',
                  'Omar Al Rashid',
                  'Message sent to Omar Al Rashid',
                ),
              ])
                OpsRow(
                  title: label,
                  subtitle: value,
                  trailing: Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                  onTap: () => showOpsSnack(context, message),
                ),
            ],
          ),
          const SizedBox(height: 22),
          const SectionHeader(title: 'My work'),
          OpsListCard(
            children: [
              for (final key in const [
                'attendance',
                'commission',
                'targets',
                'leave',
                'expenses',
              ])
                OpsRow(
                  title: modules[key]!.name,
                  trailing: Text(
                    modules[key]!.meta,
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  onTap: () => context.go('/more/$key'),
                ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => showOpsSnack(
                    context,
                    'Profile edits open once M1 identity lands',
                  ),
                  child: const Text('Edit profile'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => confirmSignOut(context, ref),
                  child: const Text('Sign out'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Center(
            child: Text(
              'Staff access only · Aber Group 0.1.0',
              style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// Asks before signing out, from both the profile page and the More list.
///
/// Signing out is the one destructive control in the app — it drops whatever
/// half-filled form the agent is on — so it confirms rather than firing on the
/// first tap.
///
/// Clearing the session is all this does: the router is watching the auth
/// controller, so it moves to the sign-in screen on its own. Navigating here
/// as well would race that redirect.
Future<void> confirmSignOut(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Sign out?'),
      content: const Text(
        'You will need your staff credentials to get back in.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Sign out'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;
  await ref.read(authControllerProvider).signOut();
}

class _ShiftCard extends StatelessWidget {
  const _ShiftCard({required this.checkedIn, required this.onToggle});

  final bool checkedIn;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return OpsCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow(checkedIn ? 'On shift' : 'Off shift'),
                const SizedBox(height: 7),
                Text(
                  checkedIn ? 'Clocked in 9:12' : 'Not clocked in today',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          checkedIn
              ? OutlinedButton(
                  onPressed: onToggle,
                  child: const Text('End shift'),
                )
              : FilledButton(
                  onPressed: onToggle,
                  child: const Text('Clock in'),
                ),
        ],
      ),
    );
  }
}
