import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/state/auth_controller.dart';
import '../data/estate_ops_data.dart';
import 'profile_page.dart';
import 'widgets/estate_widgets.dart';

class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final staff = ref.watch(currentStaffProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Text(
          'More',
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 18),
        OpsCard(
          padding: const EdgeInsets.all(16),
          onTap: () => context.push('/profile'),
          child: Row(
            children: [
              InitialsAvatar(staff.initials, size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      staff.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${staff.role} · ${staff.branch} · ID ${staff.employeeId}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
        for (final (title, keys) in moreGroups) ...[
          const SizedBox(height: 20),
          SectionHeader(title: title),
          OpsListCard(
            children: [
              for (final key in keys)
                OpsRow(
                  title: modules[key]!.name,
                  trailing: Text(
                    modules[key]!.meta,
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  onTap: () => context.push('/more/$key'),
                ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        const SectionHeader(title: 'Admin'),
        OpsListCard(
          children: [
            OpsRow(
              title: modules['admin']!.name,
              trailing: Text(
                modules['admin']!.meta,
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
              ),
              onTap: () => context.push('/more/admin'),
            ),
            OpsRow(
              title: 'System status',
              trailing: Text(
                'Diagnostics',
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
              ),
              onTap: () => context.push('/more/status'),
            ),
            OpsRow(
              title: 'Sign out',
              onTap: () => confirmSignOut(context, ref),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Center(
          child: Text(
            'Staff access only · Aber Group 0.1.0',
            style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
