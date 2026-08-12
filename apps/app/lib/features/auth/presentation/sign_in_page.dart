import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/auth_controller.dart';
import 'widgets/auth_widgets.dart';

class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key});

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Clearing first means a second attempt does not sit under the message
    // from the first one while it is in flight.
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    final failure = await ref
        .read(authControllerProvider)
        .signIn(email: _email.text, password: _password.text);

    if (!mounted) return;
    // On success the router's redirect takes over — this page is already being
    // torn down, so it must not also try to navigate.
    if (failure != null) setState(() => _error = failure.message);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final auth = ref.watch(authControllerProvider);

    return AuthScaffold(
      title: 'Sign in',
      subtitle:
          'Staff access to the Aber Group operations app. Use the work email '
          'your branch manager set you up with.',
      children: [
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_error != null) AuthErrorBanner(message: _error!),
                AuthField(
                  label: 'Work email',
                  controller: _email,
                  hint: 'you@abergroup.ae',
                  enabled: !auth.busy,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username],
                  validator: AuthValidators.email,
                ),
                AuthField(
                  label: 'Password',
                  controller: _password,
                  enabled: !auth.busy,
                  obscure: !_showPassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  validator: AuthValidators.password,
                  onSubmitted: _submit,
                  trailing: IconButton(
                    icon: Icon(
                      _showPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 19,
                    ),
                    color: scheme.onSurfaceVariant,
                    tooltip: _showPassword ? 'Hide password' : 'Show password',
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    style: authLinkStyle,
                    onPressed: () => ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Ask your branch manager to reset it for now.',
                          ),
                        ),
                      ),
                    child: const Text('Forgot password?'),
                  ),
                ),
                const SizedBox(height: 8),
                AuthSubmitButton(
                  label: 'Sign in',
                  busy: auth.busy,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        const _PendingIdentityNote(),
        const SizedBox(height: 6),
        // A Wrap, not a Row: the prompt plus the link is wider than a narrow
        // phone at a large text scale, and this is the one line on the screen
        // a new user is looking for.
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'New to Aber Group?',
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
            TextButton(
              style: authLinkStyle,
              onPressed: auth.busy ? null : () => context.push('/sign-up'),
              child: const Text('Create an account'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Says out loud that the identity service is not live yet.
///
/// Without it the screen is a locked door with no key: there is no server to
/// check credentials against, so anyone opening the app would be guessing at a
/// password that does not exist. Delete this widget in the same change that
/// points [AuthRepository] at `/v1/auth`.
class _PendingIdentityNote extends StatelessWidget {
  const _PendingIdentityNote();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PREVIEW BUILD',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'The identity service is not live yet. Any @abergroup.ae address '
            'with an 8-character password signs in; sara.khan@abergroup.ae '
            'opens the seeded agent.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
