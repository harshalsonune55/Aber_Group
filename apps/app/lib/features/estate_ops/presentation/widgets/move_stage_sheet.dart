import 'package:flutter/material.dart';

import 'estate_widgets.dart';
import 'ops_sheet.dart';

/// The pipeline, in order. A deal moves along it; the order is what makes
/// "forward" and "backward" mean anything on the sheet.
const dealStages = <String>[
  'New',
  'Viewing',
  'Negotiation',
  'Documentation',
  'Closed',
];

/// Moves a deal to another stage.
///
/// Shows the whole pipeline rather than just the next step, because deals go
/// backwards in real life — a client who was in Documentation and has gone
/// quiet belongs back in Negotiation, and an agent who cannot record that will
/// simply leave the deal wrong.
///
/// Returns the chosen stage, or null if unchanged or dismissed.
Future<String?> showMoveStageSheet(
  BuildContext context, {
  required String property,
  required String current,
}) {
  return showOpsSheet<String>(
    context,
    title: 'Move stage',
    subtitle: property,
    builder: (_) => _MoveStageForm(current: current),
  );
}

class _MoveStageForm extends StatefulWidget {
  const _MoveStageForm({required this.current});

  final String current;

  @override
  State<_MoveStageForm> createState() => _MoveStageFormState();
}

class _MoveStageFormState extends State<_MoveStageForm> {
  late String _stage = widget.current;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final currentIndex = dealStages.indexOf(widget.current);
    final targetIndex = dealStages.indexOf(_stage);
    final goingBack = targetIndex >= 0 && targetIndex < currentIndex;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Eyebrow('Currently'),
            const SizedBox(width: 10),
            StatusPill(widget.current),
          ],
        ),
        const SizedBox(height: 18),
        const Eyebrow('Move to'),
        const SizedBox(height: 9),
        FilterChips(
          options: dealStages,
          selected: _stage,
          onSelected: (value) => setState(() => _stage = value),
        ),
        const SizedBox(height: 16),
        // Moving a deal backwards is legitimate but worth a beat of thought,
        // so it is called out rather than silently accepted.
        if (goingBack)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.undo, size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'This moves the deal back a stage. The pipeline count and '
                    'any commission forecast change with it.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        OpsSheetActions(
          confirmLabel: 'Move',
          // Confirming a move to the stage it is already in would write a
          // timeline entry saying nothing happened.
          onConfirm: _stage == widget.current
              ? () => Navigator.of(context).pop()
              : () => Navigator.of(context).pop(_stage),
        ),
      ],
    );
  }
}
