import 'package:flutter/material.dart';

import '../../data/estate_ops_data.dart';
import 'estate_widgets.dart';
import 'ops_sheet.dart';

/// Books a viewing against a property.
///
/// The date is a real picker rather than a typed string: a viewing that lands
/// on the wrong day wastes an owner's afternoon and a client's, and "15/11" is
/// ambiguous enough between UAE and US conventions to do exactly that.
///
/// Returns the visit-history entry to record, or null if the agent backed out.
Future<VisitEntry?> showBookVisitSheet(
  BuildContext context, {
  required String property,
}) {
  return showOpsSheet<VisitEntry>(
    context,
    title: 'Book a visit',
    subtitle: property,
    builder: (_) => const _BookVisitForm(),
  );
}

const _slots = <String>['10:00', '11:30', '14:00', '15:30', '17:00'];

class _BookVisitForm extends StatefulWidget {
  const _BookVisitForm();

  @override
  State<_BookVisitForm> createState() => _BookVisitFormState();
}

class _BookVisitFormState extends State<_BookVisitForm> {
  final _formKey = GlobalKey<FormState>();
  final _client = TextEditingController();
  final _note = TextEditingController();

  late DateTime _date = DateTime.now();
  String _slot = _slots.first;

  @override
  void dispose() {
    _client.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      // No back-dating: this books a viewing, it does not record one that
      // already happened. A year ahead is well past any real booking.
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final note = _note.text.trim();
    Navigator.of(context).pop((
      who: note.isEmpty
          ? '${_client.text.trim()} — $_slot'
          : '${_client.text.trim()} — $_slot · $note',
      when: opsDayLabel(_date),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          OpsSheetField(
            label: 'Client',
            controller: _client,
            hint: 'Fatima Noor',
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            validator: (value) =>
                (value ?? '').trim().isEmpty ? 'Who is viewing?' : null,
          ),
          const Eyebrow('Date'),
          const SizedBox(height: 7),
          _DateButton(label: opsDayLabel(_date), onTap: _pickDate),
          const SizedBox(height: 16),
          const Eyebrow('Time'),
          const SizedBox(height: 9),
          FilterChips(
            options: _slots,
            selected: _slot,
            onSelected: (value) => setState(() => _slot = value),
          ),
          const SizedBox(height: 18),
          OpsSheetField(
            label: 'Note (optional)',
            controller: _note,
            hint: 'Bring the floor plan and the Ejari draft',
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
          ),
          OpsSheetActions(confirmLabel: 'Book visit', onConfirm: _save),
          const SizedBox(height: 10),
          Text(
            'The owner is notified once the booking syncs.',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 17,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 14.5, color: scheme.onSurface),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
