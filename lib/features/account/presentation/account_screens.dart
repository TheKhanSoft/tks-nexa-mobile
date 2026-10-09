import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tks_nexa_attendance/app/app_appearance_controller.dart';
import 'package:tks_nexa_attendance/app/app_router.dart';
import 'package:tks_nexa_attendance/app/app_theme.dart';
import 'package:tks_nexa_attendance/features/account/application/account_providers.dart';
import 'package:tks_nexa_attendance/features/account/domain/employee_profile.dart';
import 'package:tks_nexa_attendance/features/account/presentation/employee_avatar.dart';
import 'package:tks_nexa_attendance/features/auth/application/auth_providers.dart';
import 'package:tks_nexa_attendance/features/organization/application/organization_providers.dart';
import 'package:tks_nexa_attendance/features/organization/presentation/failure_message.dart';

class PersonalInformationScreen extends ConsumerWidget {
  const PersonalInformationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(employeeProfileProvider);
    final authToken = ref.watch(currentAuthSessionProvider)?.accessToken;
    final config = ref.watch(appConfigProvider);
    final theme = Theme.of(context);
    final brand = theme.extension<AppBrandTheme>() ?? AppBrandTheme.fallback;
    return Scaffold(
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.light,
        backgroundColor: brand.heroStart,
        foregroundColor: Colors.white,
        title: const Text(
          'Personal Information',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh profile',
            onPressed: () => ref.invalidate(employeeProfileProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.alphaBlend(
                brand.softAccent.withValues(alpha: .88),
                theme.canvasColor,
              ),
              theme.canvasColor,
              Color.alphaBlend(
                theme.colorScheme.secondary.withValues(alpha: .08),
                theme.canvasColor,
              ),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: profile.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _AccountError(
            message: safeFailureMessage(error),
            onRetry: () => ref.invalidate(employeeProfileProvider),
          ),
          data: (profile) => _ProfileContent(
            profile: profile,
            authToken: authToken,
            developmentConnectHost: config.developmentConnectHost,
            developmentConnectPort: config.developmentConnectPort,
          ),
        ),
      ),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({
    required this.profile,
    required this.authToken,
    required this.developmentConnectHost,
    required this.developmentConnectPort,
  });

  final EmployeeProfile profile;
  final String? authToken;
  final String? developmentConnectHost;
  final int? developmentConnectPort;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = constraints.maxWidth > 820
            ? (constraints.maxWidth - 760) / 2
            : 20.0;
        return ListView(
          padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 40),
          children: [
            _PersonalProfileHero(
              profile: profile,
              authToken: authToken,
              developmentConnectHost: developmentConnectHost,
              developmentConnectPort: developmentConnectPort,
            ),
            const SizedBox(height: 20),
            _InfoSection(
              icon: Icons.badge_outlined,
              title: 'Personal details',
              accent: colorScheme.secondary,
              compact: true,
              items: [
                ('Father name', profile.fatherName),
                ('CNIC', profile.cnic),
                ('Date of birth', profile.dateOfBirth),
                ('Gender', profile.gender),
              ],
            ),
            const SizedBox(height: 16),
            _InfoSection(
              icon: Icons.contact_mail_outlined,
              title: 'Contact',
              accent: colorScheme.tertiary,
              items: [
                if (profile.username.isNotEmpty)
                  (
                    'Username',
                    profile.username.startsWith('@')
                        ? profile.username
                        : '@${profile.username}',
                  ),
                ('Email', profile.email),
                ('Mobile number', profile.mobileNumber),
              ],
            ),
            const SizedBox(height: 16),
            _InfoSection(
              icon: Icons.work_outline_rounded,
              title: 'Employment',
              accent: colorScheme.primary,
              items: [
                (
                  'Department / office',
                  profile.department.isNotEmpty
                      ? profile.department
                      : profile.office,
                ),
                ('Campus', profile.campus),
                ('Reporting to', profile.reportingTo),
              ],
            ),
            const SizedBox(height: 16),
            _InfoSection(
              icon: Icons.location_on_outlined,
              title: 'Address',
              accent: Colors.deepOrange,
              items: [
                ('Street address', profile.address),
                ('City', profile.city),
                ('Province', profile.province),
                ('Postal code', profile.postalCode),
              ],
            ),
            const SizedBox(height: 16),
            _AttendanceSection(profile: profile),
          ],
        );
      },
    );
  }
}

class _PersonalProfileHero extends StatelessWidget {
  const _PersonalProfileHero({
    required this.profile,
    required this.authToken,
    required this.developmentConnectHost,
    required this.developmentConnectPort,
  });

  final EmployeeProfile profile;
  final String? authToken;
  final String? developmentConnectHost;
  final int? developmentConnectPort;

  @override
  Widget build(BuildContext context) {
    final brand =
        Theme.of(context).extension<AppBrandTheme>() ?? AppBrandTheme.fallback;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: brand.heroGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: brand.heroMiddle.withValues(alpha: .2),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -58,
            top: -76,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: -66,
            bottom: -94,
            child: Container(
              width: 210,
              height: 210,
              decoration: BoxDecoration(
                color: brand.heroEnd.withValues(alpha: .22),
                shape: BoxShape.circle,
              ),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 500;
              final statusLabel = profile.isActive
                  ? 'Active employee'
                  : 'Inactive employee';
              final avatar = Stack(
                clipBehavior: Clip.none,
                children: [
                  EmployeeAvatar(
                    name: profile.name,
                    photoUrl: profile.photoUrl,
                    authToken: authToken,
                    developmentConnectHost: developmentConnectHost,
                    developmentConnectPort: developmentConnectPort,
                    size: compact ? 82 : 104,
                  ),
                  Positioned(
                    right: 1,
                    bottom: 1,
                    child: Tooltip(
                      message: statusLabel,
                      child: Semantics(
                        label: statusLabel,
                        child: Container(
                          width: 29,
                          height: 29,
                          decoration: BoxDecoration(
                            color: profile.isActive
                                ? AppPalette.emerald
                                : Colors.orange,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: Icon(
                            profile.isActive
                                ? Icons.check_rounded
                                : Icons.pause_rounded,
                            color: Colors.white,
                            size: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
              final details = Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.name,
                    textAlign: TextAlign.start,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 20 : 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.4,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _designationWithGrade(profile),
                    textAlign: TextAlign.start,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (profile.employeeCode.isNotEmpty)
                        _HeaderBadge(
                          icon: Icons.badge_outlined,
                          label: profile.employeeCode,
                        ),
                      if (profile.username.isNotEmpty)
                        _HeaderBadge(
                          icon: Icons.alternate_email_rounded,
                          label: profile.username,
                        ),
                    ],
                  ),
                ],
              );
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  avatar,
                  SizedBox(width: compact ? 16 : 24),
                  Expanded(child: details),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

String _designationWithGrade(EmployeeProfile profile) {
  final designation = profile.designation.trim().isEmpty
      ? 'Employee'
      : profile.designation.trim();
  final grade = profile.designationGrade.trim();
  return grade.isEmpty ? designation : '$designation ($grade)';
}

class NotificationPreferencesScreen extends ConsumerWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _PreferenceScreen(
      title: 'Notifications',
      subtitle: 'Choose the updates that matter to you.',
      children: [
        SwitchListTile(
          value: true,
          onChanged: null,
          secondary: Icon(Icons.alarm_rounded),
          title: Text('Attendance reminders'),
          subtitle: Text('Reminders before your shift and missing check-outs.'),
        ),
        Divider(height: 1, indent: 56),
        SwitchListTile(
          value: true,
          onChanged: null,
          secondary: Icon(Icons.event_repeat_rounded),
          title: Text('Schedule changes'),
          subtitle: Text('Changes to shifts, workdays, or holidays.'),
        ),
        Divider(height: 1, indent: 56),
        SwitchListTile(
          value: true,
          onChanged: null,
          secondary: Icon(Icons.gpp_good_outlined),
          title: Text('Security alerts'),
          subtitle: Text('New sign-ins and important account activity.'),
        ),
      ],
    );
  }
}

class AppSettingsScreen extends ConsumerWidget {
  const AppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance =
        ref.watch(appAppearanceProvider).value ?? const AppAppearance();
    final preferences =
        ref.watch(appPreferencesProvider).value ?? const AppPreferences();

    return _PreferenceScreen(
      title: 'App settings',
      subtitle: 'Personalize your attendance experience on this device.',
      header: _AppearancePanel(
        appearance: appearance,
        onBrightnessSelected: ref
            .read(appAppearanceProvider.notifier)
            .setBrightnessPreference,
        onThemeSelected: ref.read(appAppearanceProvider.notifier).setColorTheme,
        onBackgroundSelected: ref
            .read(appAppearanceProvider.notifier)
            .setBackgroundStyle,
      ),
      children: [
        SwitchListTile(
          value: preferences.use24HourTime,
          onChanged: (value) => ref
              .read(appPreferencesProvider.notifier)
              .setUse24HourTime(value),
          secondary: const Icon(Icons.schedule_rounded),
          title: const Text('Use 24-hour time'),
          subtitle: const Text(
            'Display shift and attendance times in 24-hour format.',
          ),
        ),
        const Divider(height: 1, indent: 56),
        SwitchListTile(
          value: preferences.dataSaver,
          onChanged: (value) => ref
              .read(appPreferencesProvider.notifier)
              .setDataSaver(value),
          secondary: const Icon(Icons.data_saver_on_rounded),
          title: const Text('Reduce mobile data usage'),
          subtitle: const Text(
            'Load fewer non-essential images on mobile networks.',
          ),
        ),
        const Divider(height: 1, indent: 56),
        SwitchListTile(
          value: preferences.rememberTab,
          onChanged: (value) => ref
              .read(appPreferencesProvider.notifier)
              .setRememberTab(value),
          secondary: const Icon(Icons.restore_page_outlined),
          title: const Text('Remember last opened tab'),
          subtitle: const Text(
            'Return to your most recently used section.',
          ),
        ),
      ],
    );
  }
}

class SecurityDevicesScreen extends ConsumerWidget {
  const SecurityDevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(employeeProfileProvider).value;
    final security = profile?.security;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Security & devices')),
      body: _PageWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            const _PageIntro(
              icon: Icons.security_rounded,
              title: 'Your account is protected',
              subtitle: 'Review the current session and manage your password.',
            ),
            const SizedBox(height: 20),
            const _SectionLabel('TRUSTED DEVICE'),
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(18),
                leading: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.secondary.withValues(alpha: .14),
                  child: Icon(
                    Icons.smartphone_rounded,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                title: Text(
                  security?.deviceName.isNotEmpty == true
                      ? security!.deviceName
                      : 'This device',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  security?.hasTrustedDevice == true
                      ? 'Hardware key enrolled and session active'
                      : 'Secure bearer session active',
                ),
                trailing: Icon(
                  security?.hasTrustedDevice == true
                      ? Icons.verified_rounded
                      : Icons.shield_outlined,
                  color: security?.hasTrustedDevice == true
                      ? AppPalette.emerald
                      : colors.outline,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const _SectionLabel('VERIFICATION READINESS'),
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(18),
                leading: Icon(
                  profile?.faceEnrolled == true
                      ? Icons.face_retouching_natural_rounded
                      : Icons.face_retouching_off_rounded,
                  color: AppPalette.cyan,
                ),
                title: Text(
                  profile?.faceEnrolled == true
                      ? 'Face profile enrolled'
                      : 'Face profile not enrolled',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'Enrollment is managed by your organization.',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(18),
                leading: Icon(
                  security?.institutionalCameraAvailable == true
                      ? Icons.videocam_rounded
                      : Icons.videocam_off_outlined,
                  color: security?.institutionalCameraAvailable == true
                      ? AppPalette.emerald
                      : colors.outline,
                ),
                title: Text(
                  security?.institutionalCameraAvailable == true
                      ? 'Institutional cameras available'
                      : 'No institutional camera assigned',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  security?.locationName.isNotEmpty == true
                      ? security!.locationName
                      : 'Based on your assigned campus and office.',
                ),
              ),
            ),
            if (security?.keyFingerprint.isNotEmpty == true) ...[
              const SizedBox(height: 20),
              const _SectionLabel('HARDWARE KEY FINGERPRINT'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: SelectableText(
                    _groupFingerprint(security!.keyFingerprint),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            const _SectionLabel('LAST 30 DAYS'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _SecurityMetric(
                      icon: Icons.shield_rounded,
                      label: 'Trust score',
                      value: security?.averageTrustScore == null
                          ? 'No data'
                          : '${security!.averageTrustScore!.toStringAsFixed(1)}%',
                    ),
                    _SecurityMetric(
                      icon: Icons.fact_check_outlined,
                      label: 'Attendance scans',
                      value: '${security?.totalScans ?? 0}',
                    ),
                    _SecurityMetric(
                      icon: Icons.video_camera_front_rounded,
                      label: 'Camera confirmed',
                      value: '${security?.corroboratedCount ?? 0}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.push(AppRoutes.changePassword),
              icon: const Icon(Icons.password_rounded),
              label: const Text('Change password'),
            ),
          ],
        ),
      ),
    );
  }

  static String _groupFingerprint(String value) {
    final normalized = value.replaceAll(':', '').toUpperCase();
    return RegExp(
      '.{1,4}',
    ).allMatches(normalized).map((match) => match.group(0)).join(' ');
  }
}

class _SecurityMetric extends StatelessWidget {
  const _SecurityMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 138),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: .42),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: colors.primary),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _showPasswords = false;

  @override
  void dispose() {
    _current.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState?.validate() != true) return;
    final changed = await ref
        .read(changePasswordControllerProvider.notifier)
        .submit(currentPassword: _current.text, newPassword: _password.text);
    if (!mounted || !changed) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Password changed successfully.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(changePasswordControllerProvider);
    final session = ref.watch(currentAuthSessionProvider);
    final profile = ref.watch(employeeProfileProvider).value;
    final isTempPassword = (session?.mustChangePassword == true) ||
        (profile?.mustChangePassword == true) ||
        (session?.actionRequired == 'change_password');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Change password'),
        actions: [
          if (isTempPassword)
            IconButton(
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout_rounded),
              onPressed: () async {
                await ref.read(loginControllerProvider.notifier).logout();
                if (context.mounted) {
                  context.go(AppRoutes.organizationSelection);
                }
              },
            ),
        ],
      ),
      body: _PageWidth(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isTempPassword) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.error.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Theme.of(context).colorScheme.error,
                          size: 26,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Temporary Password Detected',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Theme.of(context).colorScheme.error,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                session?.actionMessage ??
                                    session?.passwordChangeMessage ??
                                    'Your account is using a temporary password. You must set a new permanent password before marking attendance.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(context).colorScheme.onErrorContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                const _PageIntro(
                  icon: Icons.password_rounded,
                  title: 'Create a strong password',
                  subtitle:
                      'Use at least 8 characters and avoid reusing your current password.',
                ),
                const SizedBox(height: 22),
                _PasswordField(
                  controller: _current,
                  label: 'Current password',
                  obscureText: !_showPasswords,
                  validator: (value) => value == null || value.isEmpty
                      ? 'Enter your current password.'
                      : null,
                ),
                const SizedBox(height: 14),
                _PasswordField(
                  controller: _password,
                  label: 'New password',
                  obscureText: !_showPasswords,
                  validator: (value) => value == null || value.length < 8
                      ? 'Use at least 8 characters.'
                      : null,
                ),
                const SizedBox(height: 14),
                _PasswordField(
                  controller: _confirmation,
                  label: 'Confirm new password',
                  obscureText: !_showPasswords,
                  validator: (value) => value != _password.text
                      ? 'Passwords do not match.'
                      : null,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show passwords'),
                  value: _showPasswords,
                  onChanged: state.isLoading
                      ? null
                      : (value) => setState(() => _showPasswords = value),
                ),
                if (state.hasError) ...[
                  const SizedBox(height: 8),
                  Text(
                    safeFailureMessage(state.error!),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: state.isLoading ? null : _submit,
                  icon: state.isLoading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded),
                  label: const Text('Update password'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AppearancePanel extends StatelessWidget {
  const _AppearancePanel({
    required this.appearance,
    required this.onBrightnessSelected,
    required this.onThemeSelected,
    required this.onBackgroundSelected,
  });

  final AppAppearance appearance;
  final Future<void> Function(AppBrightnessPreference) onBrightnessSelected;
  final Future<void> Function(AppColorTheme) onThemeSelected;
  final Future<void> Function(AppBackgroundStyle) onBackgroundSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brand = theme.extension<AppBrandTheme>() ?? AppBrandTheme.fallback;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.palette_outlined,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Appearance',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Choose display mode, palette, and page background.',
                        style: TextStyle(color: brand.mutedText, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'DISPLAY MODE',
              style: TextStyle(
                color: brand.mutedText,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<AppBrightnessPreference>(
                segments: const [
                  ButtonSegment(
                    value: AppBrightnessPreference.system,
                    icon: Icon(Icons.brightness_auto_rounded),
                    label: Text('System'),
                  ),
                  ButtonSegment(
                    value: AppBrightnessPreference.light,
                    icon: Icon(Icons.light_mode_rounded),
                    label: Text('Light'),
                  ),
                  ButtonSegment(
                    value: AppBrightnessPreference.dark,
                    icon: Icon(Icons.dark_mode_rounded),
                    label: Text('Night'),
                  ),
                ],
                selected: {appearance.brightnessPreference},
                onSelectionChanged: (selection) =>
                    onBrightnessSelected(selection.first),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'COLOR THEME',
              style: TextStyle(
                color: brand.mutedText,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth >= 520
                    ? (constraints.maxWidth - 12) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final theme in AppColorTheme.values)
                      SizedBox(
                        width: width,
                        child: _ThemeChoice(
                          theme: theme,
                          selected: appearance.colorTheme == theme,
                          onTap: () => onThemeSelected(theme),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            Text(
              'APP BACKGROUND',
              style: TextStyle(
                color: brand.mutedText,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final style in appearance.colorTheme.availableBackgrounds)
                  _BackgroundStylePill(
                    style: style,
                    selected: appearance.backgroundStyle == style,
                    onTap: () => onBackgroundSelected(style),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BackgroundStylePill extends StatelessWidget {
  const _BackgroundStylePill({
    required this.style,
    required this.selected,
    required this.onTap,
  });

  final AppBackgroundStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pillBg = style.colorFor(Theme.of(context).brightness);
    final textColor = pillBg.computeLuminance() > 0.42
        ? const Color(0xFF0F172A)
        : Colors.white;
    final isDarkOption = pillBg.computeLuminance() <= 0.42;

    return InkWell(
      key: Key('background_${style.name}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: pillBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : (isDarkOption ? Colors.white30 : Colors.black12),
            width: selected ? 2.5 : 1.0,
          ),
          boxShadow: [
            if (selected)
              BoxShadow(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(
                Icons.check_circle_rounded,
                size: 16,
                color: isDarkOption
                    ? Colors.white
                    : Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              style.label,
              style: TextStyle(
                color: textColor,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeChoice extends StatelessWidget {
  const _ThemeChoice({
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  final AppColorTheme theme;
  final bool selected;
  final VoidCallback onTap;

  List<Color> get colors => switch (theme) {
    AppColorTheme.royal => const [
      Color(0xFF111C4E),
      Color(0xFF4338CA),
      Color(0xFF2563EB),
    ],
    AppColorTheme.ocean => const [
      Color(0xFF073B4C),
      Color(0xFF007F86),
      Color(0xFF0EA5A4),
    ],
    AppColorTheme.emerald => const [
      Color(0xFF063F36),
      Color(0xFF047857),
      Color(0xFF10B981),
    ],
    AppColorTheme.plum => const [
      Color(0xFF351451),
      Color(0xFF7C3AED),
      Color(0xFFC026D3),
    ],
    AppColorTheme.sunset => const [
      Color(0xFF501A2A),
      Color(0xFFCF3F51),
      Color(0xFFF59E0B),
    ],
    AppColorTheme.graphite => const [
      Color(0xFF111827),
      Color(0xFF334155),
      Color(0xFF64748B),
    ],
  };

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final brand =
        Theme.of(context).extension<AppBrandTheme>() ?? AppBrandTheme.fallback;
    return Material(
      color: selected
          ? primary.withValues(alpha: .07)
          : Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? primary : brand.divider,
          width: selected ? 1.7 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('theme_${theme.name}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 34,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors),
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  theme.label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, color: primary, size: 21),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreferenceScreen extends StatelessWidget {
  const _PreferenceScreen({
    required this.title,
    required this.subtitle,
    required this.children,
    this.header,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _PageWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            _PageIntro(
              icon: Icons.tune_rounded,
              title: title,
              subtitle: subtitle,
            ),
            if (header != null) ...[
              const SizedBox(height: 18),
              header!,
            ],
            const SizedBox(height: 22),
            Card(
              child: Column(
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({
    required this.icon,
    required this.title,
    required this.items,
    required this.accent,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final List<(String, String)> items;
  final Color accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibleItems = items
        .where((item) => item.$2.trim().isNotEmpty)
        .toList(growable: false);
    final surface = theme.cardTheme.color ?? theme.colorScheme.surface;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color.alphaBlend(accent.withValues(alpha: .12), surface),
            surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: .13)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: .08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accent),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final breakpoint = compact ? 300.0 : 430.0;
                final width = constraints.maxWidth >= breakpoint
                    ? (constraints.maxWidth - 10) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final item in visibleItems)
                      SizedBox(
                        width: width,
                        child: _InfoValue(
                          label: item.$1,
                          value: item.$2,
                          accent: accent,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoValue extends StatelessWidget {
  const _InfoValue({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;
    final brand = theme.extension<AppBrandTheme>() ?? AppBrandTheme.fallback;
    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: Color.alphaBlend(accent.withValues(alpha: .07), surface),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: .14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              color: brand.mutedText,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            value.isEmpty ? 'Not provided' : value,
            style: TextStyle(
              fontSize: 14,
              height: 1.25,
              fontWeight: FontWeight.w700,
              color: value.isEmpty
                  ? brand.mutedText.withValues(alpha: .75)
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceSection extends StatelessWidget {
  const _AttendanceSection({required this.profile});
  final EmployeeProfile profile;

  @override
  Widget build(BuildContext context) {
    final shift = profile.assignedShift;
    String formatTime(String? timeStr) {
      if (timeStr == null || timeStr.trim().isEmpty) return '';
      final parts = timeStr.trim().split(':');
      if (parts.length >= 2) {
        final hour = parts[0].padLeft(2, '0');
        final min = parts[1].padLeft(2, '0');
        return '$hour:$min';
      }
      return timeStr;
    }

    return _InfoSection(
      icon: Icons.schedule_rounded,
      title: 'Attendance & shift',
      accent: Theme.of(context).colorScheme.tertiary,
      compact: true,
      items: [
        (
          'Attendance access',
          profile.canMarkAttendance ? 'Allowed' : 'Not available',
        ),
        ('Face enrollment', profile.faceEnrolled ? 'Ready' : 'Not enrolled'),
        ('Assigned shift', shift?.name ?? ''),
        (
          'Shift time',
          shift == null
              ? ''
              : '${formatTime(shift.startTime)} – ${formatTime(shift.endTime)}',
        ),
        (
          'Grace period',
          shift == null ? '' : '${shift.gracePeriodMinutes} minutes',
        ),
      ],
    );
  }
}

class _PageIntro extends StatelessWidget {
  const _PageIntro({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brand =
        Theme.of(context).extension<AppBrandTheme>() ?? AppBrandTheme.fallback;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: brand.softAccent,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 27,
            backgroundColor: colorScheme.surface,
            child: Icon(icon, color: colorScheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: brand.mutedText, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderBadge extends StatelessWidget {
  const _HeaderBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: .28),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: .9), size: 14),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscureText,
    required this.validator,
  });
  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
      ),
    );
  }
}

class _PageWidth extends StatelessWidget {
  const _PageWidth({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: child,
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final muted =
        Theme.of(context).extension<AppBrandTheme>()?.mutedText ??
        AppPalette.muted;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
      child: Text(
        label,
        style: TextStyle(
          color: muted,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _AccountError extends StatelessWidget {
  const _AccountError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
