import 'package:flutter/material.dart';

import '../data/estate_ops_data.dart';
import 'widgets/estate_widgets.dart';

class PersonDetailPage extends StatelessWidget {
  const PersonDetailPage({super.key, required this.personId});

  final String personId;

  @override
  Widget build(BuildContext context) {
    final person = findTeamMember(personId);
    if (person == null) {
      return const OpsNotFoundPage(
        title: 'Team member',
        message: 'This person is no longer on the roster.',
      );
    }
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: OpsDetailAppBar(title: person.name),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              InitialsAvatar(person.initials, size: 60),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      person.name,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      person.role,
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          StatGrid(stats: person.stats, columns: 3),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Attendance this week'),
          OpsListCard(
            children: [
              for (final w in person.week)
                OpsRow(
                  title: w.day,
                  trailing: Text(
                    w.hours,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Assigned work'),
          OpsListCard(
            children: [
              for (final w in person.assigned)
                OpsRow(
                  title: w.title,
                  trailing: Text(
                    w.due,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () =>
                      showOpsSnack(context, 'Message sent to ${person.name}'),
                  child: const Text('Message'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      showOpsSnack(context, 'Task assigned to ${person.name}'),
                  child: const Text('Assign task'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
