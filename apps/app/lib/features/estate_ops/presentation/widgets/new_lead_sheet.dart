import 'package:flutter/material.dart';

import '../../data/estate_ops_data.dart';
import 'estate_widgets.dart';

/// Takes down a lead in the thirty seconds an agent has while the person is
/// still standing in front of them.
///
/// A sheet rather than a pushed screen: capturing a lead interrupts whatever
/// the agent was doing, and a sheet makes that interruption obviously
/// temporary — dismissing it puts them back exactly where they were.
///
/// Deliberately three fields. Everything else about a lead (budget, timeline,
/// which unit they liked) can be filled in later from the desk; a capture form
/// long enough to need scrolling is one the agent skips and writes on their
/// hand instead.
Future<Lead?> showNewLeadSheet(BuildContext context) {
  return showModalBottomSheet<Lead>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const _NewLeadSheet(),
  );
}

const _sources = <String>['Bayut', 'Website', 'Referral', 'Walk-in', 'Call'];

class _NewLeadSheet extends StatefulWidget {
  const _NewLeadSheet();

  @override
  State<_NewLeadSheet> createState() => _NewLeadSheetState();
}

class _NewLeadSheetState extends State<_NewLeadSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _want = TextEditingController();
  String _source = _sources.first;

  @override
  void dispose() {
    _name.dispose();
    _want.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      Lead(
        name: _name.text.trim(),
        want: _want.text.trim(),
        source: _source,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      // Lifts the sheet clear of the keyboard, which otherwise covers the
      // requirement field and the save button both.
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'New lead',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.4,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 18),
              _SheetField(
                label: 'Name',
                controller: _name,
                hint: 'Daniel Morris',
                textCapitalization: TextCapitalization.words,
                autofocus: true,
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Who is this lead?'
                    : null,
              ),
              _SheetField(
                label: 'Looking for',
                controller: _want,
                hint: '2BR rental, Dubai Marina, AED 190K',
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: _save,
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Note what they are after.'
                    : null,
              ),
              const Eyebrow('Source'),
              const SizedBox(height: 9),
              FilterChips(
                options: _sources,
                selected: _source,
                onSelected: (value) => setState(() => _source = value),
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
                      child: const Text('Save lead'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  const _SheetField({
    required this.label,
    required this.controller,
    required this.validator,
    this.hint,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final String? Function(String?) validator;
  final String? hint;
  final bool autofocus;
  final TextCapitalization textCapitalization;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(label),
          const SizedBox(height: 7),
          TextFormField(
            controller: controller,
            autofocus: autofocus,
            textCapitalization: textCapitalization,
            textInputAction: onSubmitted == null
                ? TextInputAction.next
                : TextInputAction.done,
            onFieldSubmitted: onSubmitted == null
                ? null
                : (_) => onSubmitted!(),
            validator: validator,
            style: TextStyle(fontSize: 14.5, color: scheme.onSurface),
            decoration: InputDecoration(
              hintText: hint,
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
        ],
      ),
    );
  }
}
