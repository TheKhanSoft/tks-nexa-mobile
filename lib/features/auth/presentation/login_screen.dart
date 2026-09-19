import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tks_nexa_attendance/app/app_router.dart';
import 'package:tks_nexa_attendance/app/app_theme.dart';
import 'package:tks_nexa_attendance/features/auth/application/auth_providers.dart';
import 'package:tks_nexa_attendance/features/auth/domain/login_method.dart';
import 'package:tks_nexa_attendance/features/organization/application/organization_providers.dart';
import 'package:tks_nexa_attendance/features/organization/presentation/failure_message.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  LoginMethod _method = LoginMethod.email;
  bool _showPassword = false;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState?.validate() != true) return;
    final succeeded = await ref
        .read(loginControllerProvider.notifier)
        .login(
          method: _method,
          identifier: _identifierController.text,
          password: _passwordController.text,
        );
    if (succeeded && mounted) context.go(AppRoutes.home);
  }

  void _changeMethod(LoginMethod method) {
    setState(() {
      _method = method;
      _identifierController.clear();
    });
  }

  Future<void> _changeOrganization() async {
    await ref.read(organizationSessionProvider.notifier).changeOrganization();
    if (mounted) context.go(AppRoutes.organizationSelection);
  }

  @override
  Widget build(BuildContext context) {
    final organization = ref.watch(organizationSessionProvider).value;
    final loginState = ref.watch(loginControllerProvider);
    if (organization == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(AppRoutes.organizationSelection);
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final theme = Theme.of(context);
    final brand = theme.extension<AppBrandTheme>() ?? AppBrandTheme.fallback;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Employee Login',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        leading: IconButton(
          tooltip: 'Choose another organization',
          onPressed: loginState.isLoading
              ? null
              : () => context.go(AppRoutes.organizationSelection),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.canvasColor,
              brand.softAccent.withValues(alpha: .72),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: Card(
                  elevation: 12,
                  shadowColor: theme.colorScheme.primary.withValues(alpha: .16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                    side: const BorderSide(color: Colors.white, width: 1.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: brand.heroGradient,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  width: 68,
                                  height: 68,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: .14),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  child: const Icon(
                                    Icons.apartment_rounded,
                                    color: Colors.white,
                                    size: 34,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  organization.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 21,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                // const SizedBox(height: 8),
                                // Container(
                                //   padding: const EdgeInsets.symmetric(
                                //     horizontal: 14,
                                //     vertical: 5,
                                //   ),
                                //   decoration: BoxDecoration(
                                //     color: Colors.white.withValues(alpha: .12),
                                //     borderRadius: BorderRadius.circular(999),
                                //   ),
                                //   child: Text(
                                //     organization.apiBaseUri.host,
                                //     style: const TextStyle(
                                //       color: Colors.white70,
                                //       fontSize: 12,
                                //       fontWeight: FontWeight.w600,
                                //     ),
                                //   ),
                                // ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Sign in to your account',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Choose the identifier registered by your organization.',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _LoginMethodSelector(
                            selected: _method,
                            enabled: !loginState.isLoading,
                            onSelected: _changeMethod,
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            key: const Key('login_identifier'),
                            controller: _identifierController,
                            enabled: !loginState.isLoading,
                            keyboardType: _keyboardTypeFor(_method),
                            autofillHints: _autofillHintsFor(_method),
                            inputFormatters: _method == LoginMethod.cnic
                                ? [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(13),
                                  ]
                                : [LengthLimitingTextInputFormatter(254)],
                            decoration: InputDecoration(
                              labelText: _identifierLabelFor(_method),
                              hintText: _identifierHintFor(_method),
                              prefixIcon: Icon(_iconFor(_method)),
                            ),
                            validator: (value) {
                              final text = value?.trim() ?? '';
                              if (text.isEmpty) {
                                return 'Enter your ${_method.label.toLowerCase()}.';
                              }
                              if (_method == LoginMethod.email &&
                                  (!text.contains('@') || text.length > 254)) {
                                return 'Enter a valid email address.';
                              }
                              if (_method == LoginMethod.cnic &&
                                  text.length != 13) {
                                return 'Enter the 13-digit CNIC number.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            key: const Key('login_password'),
                            controller: _passwordController,
                            enabled: !loginState.isLoading,
                            obscureText: !_showPassword,
                            autofillHints: const [AutofillHints.password],
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _login(),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(
                                Icons.lock_outline_rounded,
                              ),
                              suffixIcon: IconButton(
                                tooltip: _showPassword
                                    ? 'Hide password'
                                    : 'Show password',
                                onPressed: loginState.isLoading
                                    ? null
                                    : () => setState(
                                        () => _showPassword = !_showPassword,
                                      ),
                                icon: Icon(
                                  _showPassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                              ),
                            ),
                            validator: (value) => value == null || value.isEmpty
                                ? 'Enter your password.'
                                : null,
                          ),
                          if (loginState.hasError) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.errorContainer,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                safeFailureMessage(loginState.error!),
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onErrorContainer,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                          const SizedBox(height: 22),
                          FilledButton.icon(
                            key: const Key('login_submit'),
                            onPressed: loginState.isLoading ? null : _login,
                            icon: loginState.isLoading
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.login_rounded),
                            label: const Text('Secure login'),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            key: const Key('change_organization'),
                            onPressed: loginState.isLoading
                                ? null
                                : _changeOrganization,
                            icon: const Icon(Icons.swap_horiz_rounded),
                            label: const Text('Change organization'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginMethodSelector extends StatelessWidget {
  const _LoginMethodSelector({
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  final LoginMethod selected;
  final bool enabled;
  final ValueChanged<LoginMethod> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final method in LoginMethod.values)
              SizedBox(
                width: width,
                child: _LoginMethodButton(
                  method: method,
                  selected: selected == method,
                  enabled: enabled,
                  onTap: () => onSelected(method),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _LoginMethodButton extends StatelessWidget {
  const _LoginMethodButton({
    required this.method,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final LoginMethod method;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brand =
        Theme.of(context).extension<AppBrandTheme>() ?? AppBrandTheme.fallback;
    final foreground = selected ? colorScheme.primary : brand.mutedText;
    return Material(
      color: selected ? brand.softAccent : colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? colorScheme.primary : brand.divider,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        key: Key('login_method_${method.apiValue}'),
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          child: Row(
            children: [
              Icon(_iconFor(method), color: foreground, size: 21),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  method.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_circle_rounded,
                  color: colorScheme.primary,
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _iconFor(LoginMethod method) => switch (method) {
  LoginMethod.email => Icons.email_outlined,
  LoginMethod.cnic => Icons.contact_page_outlined,
  LoginMethod.employeeCode => Icons.badge_outlined,
  LoginMethod.username => Icons.person_outline_rounded,
};

String _identifierLabelFor(LoginMethod method) => switch (method) {
  LoginMethod.email => 'Email address',
  LoginMethod.cnic => 'CNIC number',
  LoginMethod.employeeCode => 'Employee ID / code',
  LoginMethod.username => 'Username',
};

String? _identifierHintFor(LoginMethod method) => switch (method) {
  LoginMethod.email => 'name@example.com',
  LoginMethod.cnic => '13 digits without dashes',
  LoginMethod.employeeCode => 'e.g. PK-TEST-0001',
  LoginMethod.username => 'Enter your username',
};

TextInputType _keyboardTypeFor(LoginMethod method) => switch (method) {
  LoginMethod.email => TextInputType.emailAddress,
  LoginMethod.cnic => TextInputType.number,
  LoginMethod.employeeCode || LoginMethod.username => TextInputType.text,
};

Iterable<String>? _autofillHintsFor(LoginMethod method) => switch (method) {
  LoginMethod.email => const [AutofillHints.email],
  LoginMethod.employeeCode ||
  LoginMethod.username => const [AutofillHints.username],
  LoginMethod.cnic => null,
};
