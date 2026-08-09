import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/env.dart';
import '../../../core/providers.dart';
import '../../../shared/responsive/breakpoints.dart';

/// The M0 walking skeleton: proves the Flutter client, the proxy and the API all
/// talk to each other on every target platform.
///
/// It stays in the app after M0 as a support screen — when an agent reports
/// "nothing loads", this is the page that says whether the backend is reachable
/// and which build they are on.
class SystemStatusPage extends ConsumerWidget {
  const SystemStatusPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(apiHealthProvider);
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () async => ref.refresh(apiHealthProvider.future),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('System status', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Connectivity between this device and the Aber Group backend.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          health.when(
            loading: () => const Card(
              child: ListTile(
                leading: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                title: Text('Contacting the backend…'),
              ),
            ),
            error: (error, _) => _StatusCard(
              ok: false,
              title: 'Could not reach the backend',
              subtitle: '$error',
            ),
            data: (data) => data.reachable
                ? _StatusCard(
                    ok: true,
                    title: 'Backend reachable',
                    subtitle:
                        '${data.service} v${data.version} · ${data.environment}',
                  )
                : _StatusCard(
                    ok: false,
                    title: 'Backend unreachable',
                    subtitle: data.failure?.message ?? 'Unknown error',
                  ),
          ),
          const SizedBox(height: 24),
          Text('Client', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          _InfoTile(label: 'API base URL', value: Env.apiBaseUrl),
          _InfoTile(label: 'Build environment', value: Env.environment),
          _InfoTile(label: 'Window size class', value: context.windowSize.name),
          _InfoTile(
            label: 'Screen width',
            value: '${MediaQuery.sizeOf(context).width.round()} px',
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.ok,
    required this.title,
    required this.subtitle,
  });

  final bool ok;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: Icon(
          ok ? Icons.check_circle_outline : Icons.error_outline,
          color: ok ? scheme.primary : scheme.error,
          size: 32,
        ),
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
