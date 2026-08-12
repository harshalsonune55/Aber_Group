import 'package:flutter/material.dart';

import '../../../estate_ops/presentation/widgets/estate_widgets.dart'
    show kMinTapTarget;

/// Style shared by the auth screens' inline links ("Forgot password?",
/// "Create an account"). A [TextButton] shrink-wraps to its label, which puts
/// these under a thumb-sized target on every form.
final ButtonStyle authLinkStyle = TextButton.styleFrom(
  minimumSize: const Size(kMinTapTarget, kMinTapTarget),
);

/// The branded frame both auth screens sit in.
///
/// Centred and width-capped rather than stretched: on a laptop a sign-in form
/// that runs the full width of the window is a lot of mouse travel between the
/// email field and the password field, and the estate-ops screens behind it
/// are the same measure.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.onBack,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              shrinkWrap: true,
              children: [
                if (onBack != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Back',
                      color: scheme.onSurface,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: kMinTapTarget,
                        height: kMinTapTarget,
                      ),
                    ),
                  ),
                const _WordMark(),
                const SizedBox(height: 28),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.6,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 26),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WordMark extends StatelessWidget {
  const _WordMark();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            'A',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              height: 1,
              color: scheme.onPrimary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'ABER GROUP',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.6,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// A labelled text field in the estate-ops idiom — the label sits above the
/// box rather than floating inside it, so a filled field still says what it
/// is at a glance.
class AuthField extends StatelessWidget {
  const AuthField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.obscure = false,
    this.enabled = true,
    this.autofillHints,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.trailing,
    this.validator,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final bool obscure;
  final bool enabled;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final Widget? trailing;
  final String? Function(String?)? validator;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 7),
          TextFormField(
            controller: controller,
            enabled: enabled,
            obscureText: obscure,
            keyboardType: keyboardType,
            autofillHints: autofillHints,
            textInputAction: textInputAction,
            textCapitalization: textCapitalization,
            validator: validator,
            onFieldSubmitted: onSubmitted == null
                ? null
                : (_) => onSubmitted!(),
            style: TextStyle(fontSize: 14.5, color: scheme.onSurface),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                fontSize: 14,
                color: scheme.onSurfaceVariant,
              ),
              suffixIcon: trailing,
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

/// Shows the message from a rejected sign-in above the form.
///
/// Kept in the page body rather than a snack bar: it is the answer to what the
/// user just tried, so it should stay on screen while they fix the field, not
/// time out after four seconds.
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        border: Border.all(color: scheme.error.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 17, color: scheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: scheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-width primary action that swaps its label for a spinner while busy.
///
/// The spinner replaces the label inside the same box so the button does not
/// change size mid-tap and shift everything below it.
class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({
    super.key,
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 50,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        child: busy
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: scheme.onPrimary,
                ),
              )
            : Text(label),
      ),
    );
  }
}

/// Validators shared by both forms, so "what counts as a work email" has one
/// definition rather than one per screen.
class AuthValidators {
  const AuthValidators._();

  static final _email = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

  static String? email(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Enter your work email.';
    if (!_email.hasMatch(text)) return 'That does not look like an email.';
    return null;
  }

  static String? required(String? value, String field) =>
      (value ?? '').trim().isEmpty ? 'Enter your $field.' : null;

  static String? password(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Enter your password.';
    if (text.length < 8) return 'Use at least 8 characters.';
    return null;
  }

  /// Sign-up asks for more than sign-in does: a password being rejected at
  /// *creation* time is a small annoyance, whereas being rejected at sign-in
  /// because the rules changed is a support call.
  static String? newPassword(String? value) {
    final text = value ?? '';
    final basic = password(text);
    if (basic != null) return basic;
    if (!text.contains(RegExp(r'[A-Za-z]')) ||
        !text.contains(RegExp(r'\d'))) {
      return 'Mix in at least one letter and one number.';
    }
    return null;
  }

  static String? employeeId(String? value) {
    final text = (value ?? '').trim().toUpperCase();
    if (text.isEmpty) return 'Enter the ID on your staff card.';
    if (!RegExp(r'^ABR-\d{4}$').hasMatch(text)) {
      return 'Staff IDs look like ABR-2041.';
    }
    return null;
  }
}
