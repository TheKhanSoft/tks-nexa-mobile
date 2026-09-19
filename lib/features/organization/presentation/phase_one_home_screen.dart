import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tks_nexa_attendance/app/app_router.dart';
import 'package:tks_nexa_attendance/app/app_theme.dart';
import 'package:tks_nexa_attendance/features/account/application/account_providers.dart';
import 'package:tks_nexa_attendance/features/account/domain/employee_profile.dart';
import 'package:tks_nexa_attendance/features/account/presentation/employee_avatar.dart';
import 'package:tks_nexa_attendance/features/auth/application/auth_providers.dart';
import 'package:tks_nexa_attendance/features/organization/application/organization_providers.dart';
import 'package:tks_nexa_attendance/features/organization/domain/organization.dart';

class PhaseOneHomeScreen extends ConsumerStatefulWidget {
  const PhaseOneHomeScreen({super.key});

  @override
  ConsumerState<PhaseOneHomeScreen> createState() => _PhaseOneHomeScreenState();
}

class _PhaseOneHomeScreenState extends ConsumerState<PhaseOneHomeScreen> {
  int _selectedIndex = 0;

  Future<void> _logout() async {
    await ref.read(loginControllerProvider.notifier).logout();
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    if (mounted) context.go(AppRoutes.organizationSelection);
  }

  void _openAttendance() => context.push(AppRoutes.attendancePreparation);

  @override
  Widget build(BuildContext context) {
    final organizationState = ref.watch(organizationSessionProvider);
    return organizationState.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) => Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => ref.invalidate(organizationSessionProvider),
            child: const Text('Retry secure session'),
          ),
        ),
      ),
      data: (organization) {
        if (organization == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              context.go(AppRoutes.organizationSelection);
            }
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final profileState = ref.watch(employeeProfileProvider);
        final authSession = ref.watch(currentAuthSessionProvider);
        final config = ref.watch(appConfigProvider);
        final colorScheme = Theme.of(context).colorScheme;
        final brand =
            Theme.of(context).extension<AppBrandTheme>() ??
            AppBrandTheme.fallback;
        final employeeName =
            profileState.value?.name ?? authSession?.employeeName ?? 'Employee';
        final employeePhotoUrl =
            profileState.value?.photoUrl ?? authSession?.photoUrl;
        return Scaffold(
          drawer: _EmployeeDrawer(
            employeeName: employeeName,
            photoUrl: employeePhotoUrl,
            authToken: authSession?.accessToken,
            developmentConnectHost: config.developmentConnectHost,
            developmentConnectPort: config.developmentConnectPort,
            organization: organization,
            onDestinationSelected: (index) {
              Navigator.of(context).pop();
              setState(() => _selectedIndex = index);
            },
            onLogout: _logout,
          ),
          appBar: AppBar(
            backgroundColor: brand.heroStart,
            foregroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            title: Text(
              const [
                'Attendance',
                'History',
                'Camera attendance',
                'Schedule',
                'Account',
              ][_selectedIndex],
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            actions: [
              IconButton(
                tooltip: 'Notifications',
                onPressed: () =>
                    context.push(AppRoutes.notificationPreferences),
                icon: const Badge(
                  isLabelVisible: false,
                  child: Icon(Icons.notifications_none_rounded),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            top: false,
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                _HomeDashboard(
                  employeeName: employeeName,
                  organization: organization,
                  profile: profileState.value,
                  onMarkAttendance: _openAttendance,
                  onOpenHistory: () => setState(() => _selectedIndex = 1),
                  onOpenSchedule: () => setState(() => _selectedIndex = 3),
                ),
                const _EmptyFeaturePage(
                  icon: Icons.history_rounded,
                  title: 'Attendance history',
                  description:
                      'Your check-ins, check-outs, and attendance status will appear here.',
                ),
                _AttendancePage(onMarkAttendance: _openAttendance),
                const _EmptyFeaturePage(
                  icon: Icons.calendar_month_rounded,
                  title: 'My schedule',
                  description:
                      'Assigned shifts, upcoming workdays, and holidays will appear here.',
                ),
                _ProfilePage(
                  employeeName: employeeName,
                  organization: organization,
                  profileState: profileState,
                  authToken: authSession?.accessToken,
                  loginPhotoUrl: authSession?.photoUrl,
                  developmentConnectHost: config.developmentConnectHost,
                  developmentConnectPort: config.developmentConnectPort,
                  onLogout: _logout,
                ),
              ],
            ),
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
          floatingActionButton: SizedBox.square(
            dimension: 72,
            child: FloatingActionButton(
              key: const Key('camera_attendance'),
              tooltip: 'Camera attendance',
              onPressed: () {
                setState(() => _selectedIndex = 2);
                _openAttendance();
              },
              backgroundColor: _selectedIndex == 2
                  ? brand.heroStart
                  : colorScheme.primary,
              foregroundColor: Colors.white,
              elevation: 8,
              shape: const CircleBorder(
                side: BorderSide(color: Colors.white, width: 5),
              ),
              child: const Icon(Icons.camera_alt_rounded, size: 32),
            ),
          ),
          bottomNavigationBar: _PremiumBottomBar(
            selectedIndex: _selectedIndex,
            onSelected: (index) => setState(() => _selectedIndex = index),
          ),
        );
      },
    );
  }
}

class _PremiumBottomBar extends StatelessWidget {
  const _PremiumBottomBar({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      height: 74,
      elevation: 12,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      color: Theme.of(context).colorScheme.surface,
      shape: const CircularNotchedRectangle(),
      notchMargin: 9,
      child: Row(
        children: [
          Expanded(
            child: _BottomBarItem(
              icon: Icons.home_outlined,
              selectedIcon: Icons.home_rounded,
              label: 'Home',
              selected: selectedIndex == 0,
              onTap: () => onSelected(0),
            ),
          ),
          Expanded(
            child: _BottomBarItem(
              icon: Icons.fact_check_outlined,
              selectedIcon: Icons.fact_check_rounded,
              label: 'History',
              selected: selectedIndex == 1,
              onTap: () => onSelected(1),
            ),
          ),
          const SizedBox(width: 78),
          Expanded(
            child: _BottomBarItem(
              icon: Icons.calendar_month_outlined,
              selectedIcon: Icons.calendar_month_rounded,
              label: 'Schedule',
              selected: selectedIndex == 3,
              onTap: () => onSelected(3),
            ),
          ),
          Expanded(
            child: _BottomBarItem(
              icon: Icons.account_circle_outlined,
              selectedIcon: Icons.account_circle_rounded,
              label: 'Account',
              selected: selectedIndex == 4,
              onTap: () => onSelected(4),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBarItem extends StatelessWidget {
  const _BottomBarItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return InkResponse(
      onTap: onTap,
      radius: 30,
      child: Semantics(
        selected: selected,
        button: true,
        label: label,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? selectedIcon : icon, color: color, size: 24),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeDashboard extends StatelessWidget {
  const _HomeDashboard({
    required this.employeeName,
    required this.organization,
    required this.profile,
    required this.onMarkAttendance,
    required this.onOpenHistory,
    required this.onOpenSchedule,
  });

  final String employeeName;
  final Organization organization;
  final EmployeeProfile? profile;
  final VoidCallback onMarkAttendance;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenSchedule;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final brand =
        Theme.of(context).extension<AppBrandTheme>() ?? AppBrandTheme.fallback;
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth > 760
            ? (constraints.maxWidth - 720) / 2
            : 20.0;
        return ListView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            12,
            horizontalPadding,
            28,
          ),
          children: [
            Text(
              'Hello, ${_firstName(employeeName)}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Here’s your attendance overview for today.',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 22),
            _OrganizationCard(organization: organization),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: brand.heroGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x2917324D),
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      _StatusPill(),
                      Spacer(),
                      Icon(Icons.shield_outlined, color: Colors.white70),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    profile?.canMarkAttendance == false
                        ? 'Attendance unavailable'
                        : 'Ready for your workday?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _attendanceSummary(profile),
                    style: const TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    key: const Key('mark_attendance'),
                    onPressed: profile?.canMarkAttendance == false
                        ? null
                        : onMarkAttendance,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: brand.heroStart,
                    ),
                    icon: const Icon(Icons.camera_alt_rounded),
                    label: const Text('Open camera attendance'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            Text(
              'Quick access',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _QuickAction(
                    icon: Icons.history_rounded,
                    label: 'History',
                    onTap: onOpenHistory,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.calendar_month_rounded,
                    label: 'Schedule',
                    onTap: onOpenSchedule,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _OrganizationCard extends StatelessWidget {
  const _OrganizationCard({required this.organization});

  final Organization organization;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: colorScheme.secondary.withValues(alpha: .13),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                Icons.apartment_rounded,
                color: colorScheme.secondary,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    organization.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.verified_rounded,
                        size: 16,
                        color: AppPalette.emerald,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Securely connected',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 9, color: Color(0xFF70E0B5)),
          SizedBox(width: 7),
          Text(
            'Connected',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.secondary),
              const SizedBox(height: 9),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttendancePage extends StatelessWidget {
  const _AttendancePage({required this.onMarkAttendance});

  final VoidCallback onMarkAttendance;

  @override
  Widget build(BuildContext context) {
    return _EmptyFeaturePage(
      icon: Icons.camera_alt_rounded,
      title: 'Camera attendance',
      description:
          'Open the secure camera to verify your identity and record attendance. Your organization’s mobile policy determines the required checks.',
      action: FilledButton.icon(
        onPressed: onMarkAttendance,
        icon: const Icon(Icons.camera_alt_rounded),
        label: const Text('Open secure camera'),
      ),
    );
  }
}

class _EmptyFeaturePage extends StatelessWidget {
  const _EmptyFeaturePage({
    required this.icon,
    required this.title,
    required this.description,
    this.action,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final brand =
        Theme.of(context).extension<AppBrandTheme>() ?? AppBrandTheme.fallback;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            children: [
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: brand.softAccent,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Icon(
                  icon,
                  size: 40,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 9),
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              if (action != null) ...[const SizedBox(height: 24), action!],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfilePage extends ConsumerWidget {
  const _ProfilePage({
    required this.employeeName,
    required this.organization,
    required this.profileState,
    required this.authToken,
    required this.loginPhotoUrl,
    required this.developmentConnectHost,
    required this.developmentConnectPort,
    required this.onLogout,
  });

  final String employeeName;
  final Organization organization;
  final AsyncValue<EmployeeProfile> profileState;
  final String? authToken;
  final String? loginPhotoUrl;
  final String? developmentConnectHost;
  final int? developmentConnectPort;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth > 780
            ? (constraints.maxWidth - 720) / 2
            : 20.0;
        return ListView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            12,
            horizontalPadding,
            28,
          ),
          children: [
            _EmployeeProfileHeader(
              employeeName: employeeName,
              organization: organization,
              profile: profileState.value,
              authToken: authToken,
              loginPhotoUrl: loginPhotoUrl,
              developmentConnectHost: developmentConnectHost,
              developmentConnectPort: developmentConnectPort,
            ),
            const SizedBox(height: 22),
            const _ProfileSectionLabel('ACCOUNT'),
            Card(
              child: Column(
                children: [
                  if (profileState.isLoading)
                    const LinearProgressIndicator()
                  else if (profileState.hasError)
                    ListTile(
                      leading: const Icon(Icons.sync_problem_outlined),
                      title: const Text('Profile could not be refreshed'),
                      trailing: const Icon(Icons.refresh_rounded),
                      onTap: () => ref.invalidate(employeeProfileProvider),
                    ),
                  _ProfileTile(
                    icon: Icons.badge_outlined,
                    title: 'Personal information',
                    subtitle: 'Identity, contact and employment details',
                    accent: colorScheme.primary,
                    onTap: profileState.value == null
                        ? null
                        : () => context.push(AppRoutes.personalInformation),
                  ),
                  const Divider(height: 1, indent: 68),
                  _ProfileTile(
                    icon: Icons.password_rounded,
                    title: 'Change password',
                    subtitle: 'Update your account password securely',
                    accent: colorScheme.tertiary,
                    onTap: () => context.push(AppRoutes.changePassword),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const _ProfileSectionLabel('PREFERENCES & SECURITY'),
            Card(
              child: Column(
                children: [
                  _ProfileTile(
                    icon: Icons.notifications_outlined,
                    title: 'Notification preferences',
                    subtitle: 'Attendance and account alerts',
                    accent: colorScheme.secondary,
                    onTap: () =>
                        context.push(AppRoutes.notificationPreferences),
                  ),
                  const Divider(height: 1, indent: 68),
                  _ProfileTile(
                    icon: Icons.lock_outline_rounded,
                    title: 'Security & devices',
                    subtitle: 'Session and device protection',
                    accent: colorScheme.tertiary,
                    onTap: () => context.push(AppRoutes.securityDevices),
                  ),
                  const Divider(height: 1, indent: 68),
                  _ProfileTile(
                    icon: Icons.settings_outlined,
                    title: 'App settings',
                    subtitle: 'Appearance and attendance preferences',
                    accent: colorScheme.primary,
                    onTap: () => context.push(AppRoutes.appSettings),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Card(
              child: ListTile(
                key: const Key('logout'),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 7,
                ),
                leading: CircleAvatar(
                  backgroundColor: Colors.red.shade50,
                  child: Icon(Icons.logout_rounded, color: Colors.red.shade700),
                ),
                title: Text(
                  'Sign out securely',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: const Text(
                  'End this session and return to organizations',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: onLogout,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return ListTile(
      minTileHeight: 76,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Icon(icon, color: accent, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: muted, fontSize: 12),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: muted),
      onTap: onTap,
    );
  }
}

class _EmployeeProfileHeader extends StatelessWidget {
  const _EmployeeProfileHeader({
    required this.employeeName,
    required this.organization,
    required this.profile,
    required this.authToken,
    required this.loginPhotoUrl,
    required this.developmentConnectHost,
    required this.developmentConnectPort,
  });

  final String employeeName;
  final Organization organization;
  final EmployeeProfile? profile;
  final String? authToken;
  final String? loginPhotoUrl;
  final String? developmentConnectHost;
  final int? developmentConnectPort;

  @override
  Widget build(BuildContext context) {
    final brand =
        Theme.of(context).extension<AppBrandTheme>() ?? AppBrandTheme.fallback;
    final designation = profile == null
        ? 'Employee'
        : _designationAndGrade(profile!);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: brand.heroGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppPalette.indigo.withValues(alpha: .24),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -42,
            top: -48,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: AppPalette.cyan.withValues(alpha: .18),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: -55,
            bottom: -70,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 20),
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    EmployeeAvatar(
                      name: employeeName,
                      photoUrl: profile?.photoUrl ?? loginPhotoUrl,
                      authToken: authToken,
                      developmentConnectHost: developmentConnectHost,
                      developmentConnectPort: developmentConnectPort,
                      size: 112,
                    ),
                    if (profile case final employee?)
                      Positioned(
                        right: 2,
                        bottom: 3,
                        child: Tooltip(
                          message: employee.isActive
                              ? 'Active employee'
                              : 'Inactive employee',
                          child: Semantics(
                            label: employee.isActive
                                ? 'Active employee'
                                : 'Inactive employee',
                            child: Container(
                              width: 29,
                              height: 29,
                              decoration: BoxDecoration(
                                color: employee.isActive
                                    ? AppPalette.emerald
                                    : Colors.orange,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                              ),
                              child: Icon(
                                employee.isActive
                                    ? Icons.check_rounded
                                    : Icons.pause_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  employeeName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.3,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  designation,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  organization.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (profile == null || profile!.employeeCode.isEmpty)
                      const _ProfilePill(
                        icon: Icons.badge_outlined,
                        label: 'Employee account',
                      )
                    else
                      _ProfilePill(
                        icon: Icons.badge_outlined,
                        label: profile!.employeeCode,
                      ),
                    if (profile?.username.isNotEmpty == true)
                      _ProfilePill(
                        icon: Icons.alternate_email_rounded,
                        label: profile!.username,
                      ),
                  ],
                ),
                if (profile case final employee?) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _ProfileMetric(
                            icon: Icons.schedule_rounded,
                            value:
                                employee.assignedShift?.name ?? 'Not assigned',
                            label: 'Shift',
                          ),
                        ),
                        const _MetricDivider(),
                        Expanded(
                          child: _ProfileMetric(
                            icon: Icons.face_retouching_natural_rounded,
                            value: employee.faceEnrolled ? 'Ready' : 'Pending',
                            label: 'Face ID',
                          ),
                        ),
                        const _MetricDivider(),
                        Expanded(
                          child: _ProfileMetric(
                            icon: Icons.verified_rounded,
                            value: employee.canMarkAttendance
                                ? 'Allowed'
                                : 'Limited',
                            label: 'Attendance',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _designationAndGrade(EmployeeProfile profile) {
  final designation = profile.designation.trim().isEmpty
      ? 'Employee'
      : profile.designation.trim();
  final grade = profile.designationGrade.trim();
  return grade.isEmpty ? designation : '$designation ($grade)';
}

class _ProfilePill extends StatelessWidget {
  const _ProfilePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 15),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileMetric extends StatelessWidget {
  const _ProfileMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF9BE7F4), size: 21),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 42, color: Colors.white12);
  }
}

class _ProfileSectionLabel extends StatelessWidget {
  const _ProfileSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 9),
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

class _EmployeeDrawer extends StatelessWidget {
  const _EmployeeDrawer({
    required this.employeeName,
    required this.photoUrl,
    required this.authToken,
    required this.developmentConnectHost,
    required this.developmentConnectPort,
    required this.organization,
    required this.onDestinationSelected,
    required this.onLogout,
  });

  final String employeeName;
  final String? photoUrl;
  final String? authToken;
  final String? developmentConnectHost;
  final int? developmentConnectPort;
  final Organization organization;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final brand =
        Theme.of(context).extension<AppBrandTheme>() ?? AppBrandTheme.fallback;
    void openRoute(String route) {
      Navigator.of(context).pop();
      context.push(route);
    }

    return Drawer(
      backgroundColor: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: brand.heroGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 10, 10, 22),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton.filledTonal(
                        tooltip: 'Close menu',
                        onPressed: () => Navigator.of(context).pop(),
                        style: IconButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.white.withValues(alpha: .14),
                        ),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                    EmployeeAvatar(
                      name: employeeName,
                      photoUrl: photoUrl,
                      authToken: authToken,
                      developmentConnectHost: developmentConnectHost,
                      developmentConnectPort: developmentConnectPort,
                      size: 88,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      employeeName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      organization.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(color: Colors.white.withValues(alpha: .2), height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                  children: [
                    _DrawerMenuTile(
                      icon: Icons.home_rounded,
                      label: 'Home',
                      onTap: () => onDestinationSelected(0),
                    ),
                    _DrawerMenuTile(
                      icon: Icons.person_rounded,
                      label: 'My profile',
                      onTap: () => onDestinationSelected(4),
                    ),
                    _DrawerMenuTile(
                      icon: Icons.fact_check_rounded,
                      label: 'Attendance history',
                      onTap: () => onDestinationSelected(1),
                    ),
                    _DrawerMenuTile(
                      icon: Icons.calendar_month_rounded,
                      label: 'My schedule',
                      onTap: () => onDestinationSelected(3),
                    ),
                    _DrawerMenuTile(
                      icon: Icons.notifications_rounded,
                      label: 'Notifications',
                      onTap: () => openRoute(AppRoutes.notificationPreferences),
                    ),
                    _DrawerMenuTile(
                      icon: Icons.security_rounded,
                      label: 'Security & devices',
                      onTap: () => openRoute(AppRoutes.securityDevices),
                    ),
                    _DrawerMenuTile(
                      icon: Icons.settings_rounded,
                      label: 'App settings',
                      onTap: () => openRoute(AppRoutes.appSettings),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Divider(color: Colors.white.withValues(alpha: .2)),
                    ),
                    _DrawerMenuTile(
                      icon: Icons.logout_rounded,
                      label: 'Sign out securely',
                      foregroundColor: const Color(0xFFFFB4BC),
                      onTap: onLogout,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
                child: Text(
                  'TKS Nexa Attendance',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .55),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerMenuTile extends StatelessWidget {
  const _DrawerMenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.foregroundColor = Colors.white,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        minTileHeight: 52,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Icon(icon, color: foregroundColor),
        title: Text(
          label,
          style: TextStyle(color: foregroundColor, fontWeight: FontWeight.w700),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: foregroundColor.withValues(alpha: .55),
        ),
        onTap: onTap,
      ),
    );
  }
}

String _firstName(String name) {
  final normalized = name.trim();
  if (normalized.isEmpty || normalized == 'Employee') return 'there';
  return normalized.split(RegExp(r'\s+')).first;
}

String _attendanceSummary(EmployeeProfile? profile) {
  if (profile == null) return 'Loading your attendance eligibility...';
  if (!profile.canMarkAttendance) {
    return profile.attendanceReasons.isEmpty
        ? 'Attendance is not currently available for this account.'
        : profile.attendanceReasons.first;
  }
  final shift = profile.assignedShift;
  if (shift == null) return 'Verify securely to record your attendance.';
  return '${shift.name} · ${shift.startTime}–${shift.endTime}';
}
