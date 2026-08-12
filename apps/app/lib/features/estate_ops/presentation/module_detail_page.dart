import 'package:flutter/material.dart';

import '../data/estate_ops_data.dart';
import 'widgets/estate_widgets.dart';

class ModuleDetailPage extends StatelessWidget {
  const ModuleDetailPage({super.key, required this.moduleKey});

  final String moduleKey;

  @override
  Widget build(BuildContext context) {
    final module = modules[moduleKey];
    if (module == null) {
      return const OpsNotFoundPage(
        title: 'Not found',
        message: 'That section has moved or is not available to you.',
      );
    }
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: OpsDetailAppBar(title: module.name),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            module.name,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            module.blurb,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          StatGrid(stats: module.stats, columns: 2),
          const SizedBox(height: 18),
          OpsListCard(
            children: [
              for (final r in module.rows)
                OpsRow(
                  title: r.a,
                  subtitle: r.b,
                  trailing: Text(
                    r.c,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurface,
                    ),
                  ),
                  onTap: () => showOpsSnack(context, '${r.a} · ${r.b} · ${r.c}'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
