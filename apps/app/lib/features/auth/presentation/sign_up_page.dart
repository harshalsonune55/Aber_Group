import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../estate_ops/data/estate_ops_data.dart';
import '../state/auth_controller.dart';
import 'widgets/auth_widgets.dart';

class SignUpPage extends ConsumerStatefulWidget {
  const SignUpPage({super.key});

  @override
  ConsumerState<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends ConsumerState<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _employeeId = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  String _branch = branches.first;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _employeeId.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    final failure = await ref
        .read(authControllerProvider)
        .signUp(
          name: _name.text,
          email: _email.text,
          employeeId: _employeeId.text,
          branch: _branch,
          password: _password.text,
        );

    if (!mounted) return;
    if (failure != null) setState(() => _error = failure.message);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final auth = ref.watch(authControllerProvider);

    return AuthScaffold(
      title: 'Create your account',
      subtitle:
          'For Aber Group staff. Your branch manager approves the account '
          'before payroll and commission data appear.',
      onBack: auth.busy ? null : () => context.pop(),
      children: [
        Form(
          key: _formKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_error != null) AuthErrorBanner(message: _error!),
                AuthField(
                  label: 'Full name',
                  controller: _name,
                  hint: 'Sara Khan',
                  enabled: !auth.busy,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  validator: (value) =>
                      AuthValidators.required(value, 'full name'),
                ),
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
                  label: 'Employee ID',
                  controller: _employeeId,
                  hint: 'ABR-2041',
                  enabled: !auth.busy,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.next,
                  validator: AuthValidators.employeeId,
                ),
                _BranchPicker(
                  value: _branch,
                  enabled: !auth.busy,
                  onChanged: (value) => setState(() => _branch = value),
                ),
                AuthField(
                  label: 'Password',
                  controller: _password,
                  hint: 'At least 8 characters',
                  enabled: !auth.busy,
                  obscure: !_showPassword,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: AuthValidators.newPassword,
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
                AuthField(
                  label: 'Confirm password',
                  controller: _confirm,
                  enabled: !auth.busy,
                  obscure: !_showPassword,
                  textInputAction: TextInputAction.done,
                  onSubmitted: _submit,
                  validator: (value) => value == _password.text
                      ? null
                      : 'Those two passwords do not match.',
                ),
                const SizedBox(height: 8),
                AuthSubmitButton(
                  label: 'Create account',
                  busy: auth.busy,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Already have one?',
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
            TextButton(
              style: authLinkStyle,
              onPressed: auth.busy ? null : () => context.pop(),
              child: const Text('Sign in'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Branch is a closed list, so it is chips rather than a text field — the
/// four options fit on screen and a typo here misroutes approvals.
class _BranchPicker extends StatelessWidget {
  const _BranchPicker({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String value;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BRANCH',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final branch in branches)
                ChoiceChip(
                  label: Text(branch),
                  selected: branch == value,
                  // Chips shrink-wrap their label; this pads them out to a
                  // thumb-sized target without changing the type.
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  onSelected: enabled ? (_) => onChanged(branch) : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
