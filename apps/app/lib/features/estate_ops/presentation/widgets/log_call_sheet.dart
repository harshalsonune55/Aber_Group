import 'package:flutter/material.dart';

import '../../data/estate_ops_data.dart';
import 'estate_widgets.dart';

/// Records the call an agent has just finished, while they still remember it.
///
/// Asks for the outcome first and the note second, because the outcome is the
/// part the pipeline is built on ("did anyone actually reach them?") and it is
/// the part an agent in a hurry will skip if it is a free-text box. The note
/// is optional for the same reason — a call logged with no detail is still
/// worth far more than a call not logged at all.
///
/// Returns the timeline entry to record, or null if the agent backed out.
Future<ActivityEntry?> showLogCallSheet(
  BuildContext context, {
  required String client,
}) {
  return showModalBottomSheet<ActivityEntry>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _LogCallSheet(client: client),
  );
}

const _outcomes = <String>[
  'Reached',
  'No answer',
  'Left message',
  'Callback booked',
];

class _LogCallSheet extends StatefulWidget {
  const _LogCallSheet({required this.client});

  final String client;

  @override
  State<_LogCallSheet> createState() => _LogCallSheetState();
}

class _LogCallSheetState extends State<_LogCallSheet> {
  final _note = TextEditingController();
  String _outcome = _outcomes.first;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final note = _note.text.trim();
    Navigator.of(context).pop((
      what: note.isEmpty ? 'Call — $_outcome' : 'Call — $_outcome · $note',
      when: opsTimestamp(),
      // Matches the seed timeline, which attributes the agent's own entries
      // to "You" rather than to their name.
      who: 'You',
    ));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Log a call',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.4,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              widget.client,
              style: TextStyle(fontSize: 13.5, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            const Eyebrow('Outcome'),
            const SizedBox(height: 9),
            FilterChips(
              options: _outcomes,
              selected: _outcome,
              onSelected: (value) => setState(() => _outcome = value),
            ),
            const SizedBox(height: 18),
            const Eyebrow('Note (optional)'),
            const SizedBox(height: 7),
            TextField(
              controller: _note,
              maxLines: 3,
              minLines: 2,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(fontSize: 14.5, color: scheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Wants a second viewing before the weekend',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: scheme.onSurfaceVariant,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _save,
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
