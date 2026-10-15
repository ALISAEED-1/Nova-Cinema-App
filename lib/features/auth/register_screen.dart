import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/validators.dart';
import '../../navigation/app_router.dart';
import '../../widgets/primary_button.dart';
import 'auth_controller.dart';
import 'widgets/auth_scaffold.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _acceptedTerms = false;
  String? _termsError;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final valid = _formKey.currentState!.validate();
    setState(() {
      _termsError =
          _acceptedTerms ? null : 'Please accept the Terms & Conditions.';
    });
    if (!valid || !_acceptedTerms) return;

    final auth = context.read<AuthController>();
    final ok = await auth.register(
      name: _name.text,
      email: _email.text,
      password: _password.text,
    );
    if (!ok || !mounted) return;

    // Registration signs the account straight in, so the new user lands on
    // plan selection rather than being asked to log in again.
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.plans, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final text = Theme.of(context).textTheme;

    return AuthScaffold(
      title: 'Join the experience',
      subtitle: 'Create your account to start watching.',
      form: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              onChanged: (_) => auth.clearError(),
              decoration: const InputDecoration(
                hintText: 'First name',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: Validators.name,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              onChanged: (_) => auth.clearError(),
              decoration: const InputDecoration(
                hintText: 'Email address',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
              validator: Validators.email,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              onChanged: (_) => auth.clearError(),
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: 'Password (min. 6 characters)',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: _obscure ? 'Show password' : 'Hide password',
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: Validators.password,
            ),
            const SizedBox(height: AppSpacing.md),
            InkWell(
              borderRadius: AppRadius.button,
              onTap: () => setState(() {
                _acceptedTerms = !_acceptedTerms;
                if (_acceptedTerms) _termsError = null;
              }),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: AppDurations.fast,
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: _acceptedTerms
                            ? AppColors.primary
                            : AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _acceptedTerms
                              ? AppColors.primary
                              : AppColors.borderStrong,
                        ),
                      ),
                      child: _acceptedTerms
                          ? const Icon(Icons.check_rounded,
                              size: 16, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        'I agree to the Terms & Conditions',
                        style: text.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            FormErrorBanner(_termsError ?? auth.error),
            PrimaryButton(
              label: 'Sign Up',
              loading: auth.busy,
              onPressed: _submit,
            ),
          ],
        ),
      ),
      footer: Center(
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Already have an account? ', style: text.bodyMedium),
            GestureDetector(
              onTap: () {
                auth.clearError();
                // Sign-up is the root after onboarding, so there may be
                // nothing to pop back to.
                final nav = Navigator.of(context);
                if (nav.canPop()) {
                  nav.pop();
                } else {
                  nav.pushReplacementNamed(AppRoutes.login);
                }
              },
              child: Text(
                'Sign in',
                style: text.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
