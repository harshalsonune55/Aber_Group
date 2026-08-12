import 'package:flutter/material.dart';

import 'estate_widgets.dart';

/// The frame every capture form in the app shares.
///
/// Sheets rather than pushed screens throughout: capturing a lead, logging a
/// call or booking a visit all interrupt whatever the agent was doing, and a
/// sheet makes that interruption obviously temporary — dismissing it puts them
/// back exactly where they were, with the record they were looking at still
/// on screen behind.
Future<T?> showOpsSheet<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  required Widget Function(BuildContext) builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => OpsSheetBody(
      title: title,
      subtitle: subtitle,
      child: builder(sheetContext),
    ),
  );
}

class OpsSheetBody extends StatelessWidget {
  const OpsSheetBody({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      // Lifts the sheet clear of the keyboard, which otherwise covers the
      // fields at the bottom and the save button with them.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.4,
                color: scheme.onSurface,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 5),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 13.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

/// A labelled field in the sheet idiom — label above the box, so a filled
/// field still says what it is.
class OpsSheetField extends StatelessWidget {
  const OpsSheetField({
    super.key,
    required this.label,
    required this.controller,
    this.validator,
    this.hint,
    this.autofocus = false,
    this.maxLines = 1,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final String? hint;
  final bool autofocus;
  final int maxLines;
  final TextInputType? keyboardType;
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
            maxLines: maxLines,
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
            textInputAction: maxLines > 1
                ? TextInputAction.newline
                : (onSubmitted == null
                      ? TextInputAction.next
                      : TextInputAction.done),
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

/// Cancel / confirm pair, in that order — the safe option on the left, where
/// a thumb reaching for "not this" lands first.
class OpsSheetActions extends StatelessWidget {
  const OpsSheetActions({
    super.key,
    required this.confirmLabel,
    required this.onConfirm,
    this.cancelLabel = 'Cancel',
  });

  final String confirmLabel;
  final VoidCallback onConfirm;
  final String cancelLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(cancelLabel),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: onConfirm,
              child: Text(confirmLabel),
            ),
          ),
        ],
      ),
    );
  }
}
