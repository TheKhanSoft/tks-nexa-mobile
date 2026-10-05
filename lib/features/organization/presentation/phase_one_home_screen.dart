import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:tks_nexa_attendance/app/app_router.dart';
import 'package:tks_nexa_attendance/app/app_theme.dart';
import 'package:tks_nexa_attendance/features/account/application/account_providers.dart';
import 'package:tks_nexa_attendance/features/account/domain/employee_profile.dart';
import 'package:tks_nexa_attendance/features/account/presentation/account_screens.dart';
import 'package:tks_nexa_attendance/features/account/presentation/employee_avatar.dart';
import 'package:tks_nexa_attendance/features/auth/application/auth_providers.dart';
import 'package:tks_nexa_attendance/features/attendance/application/attendance_history_providers.dart';
import 'package:tks_nexa_attendance/features/attendance/data/local_selfie_storage.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/attendance_record.dart';
import 'package:tks_nexa_attendance/features/attendance/presentation/attendance_history_screen.dart';
import 'package:tks_nexa_attendance/features/attendance/presentation/mobile_attendance_log_screen.dart';
import 'package:tks_nexa_attendance/features/attendance/domain/face_capture_evidence.dart';
import 'package:tks_nexa_attendance/features/attendance/presentation/face_capture_screen.dart';
import 'package:tks_nexa_attendance/features/organization/application/organization_providers.dart';
import 'package:tks_nexa_attendance/features/organization/domain/organization.dart';
import 'package:tks_nexa_attendance/features/organization/presentation/failure_message.dart';

class PhaseOneHomeScreen extends ConsumerStatefulWidget {
  const PhaseOneHomeScreen({super.key});

  @override
  ConsumerState<PhaseOneHomeScreen> createState() => _PhaseOneHomeScreenState();
}

class _PhaseOneHomeScreenState extends ConsumerState<PhaseOneHomeScreen> {
  int _selectedIndex = 0;
  bool _loginPromptChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPostLoginPrompts();
    });
  }

  void _checkPostLoginPrompts() {
    if (!mounted || _loginPromptChecked) return;
    _loginPromptChecked = true;

    final session = ref.read(currentAuthSessionProvider);
    final profile = ref.read(employeeProfileProvider).value;

    final isTempPassword = (session?.mustChangePassword == true) ||
        (profile?.mustChangePassword == true && session?.mustChangePassword != false) ||
        (session?.actionRequired == 'change_password');

    if (isTempPassword) {
      _showPasswordChangeRequiredDialog();
      return;
    }
  }

  Future<void> _logout() async {
    await ref.read(loginControllerProvider.notifier).logout();
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    if (mounted) context.go(AppRoutes.organizationSelection);
  }

  Future<void> _refreshAllData() async {
    ref.invalidate(employeeProfileProvider);
    ref.invalidate(attendanceHistoryResponseProvider);
    ref.invalidate(organizationSessionProvider);
    ref.invalidate(mobilePunchLogsProvider);
    await Future.wait<void>([
      ref.read(employeeProfileProvider.future).then((_) {}, onError: (_) {}),
      ref.read(attendanceHistoryResponseProvider.future).then((_) {}, onError: (_) {}),
    ]);
  }

  void _openAttendance() {
    final session = ref.read(currentAuthSessionProvider);
    final profile = ref.read(employeeProfileProvider).value;

    final isTempPassword = (session?.mustChangePassword == true) ||
        (profile?.mustChangePassword == true && session?.mustChangePassword != false) ||
        (session?.actionRequired == 'change_password');

    if (isTempPassword) {
      _showPasswordChangeRequiredDialog();
      return;
    }

    final hasPhoto = (profile != null && profile.photoUrl != null && profile.photoUrl!.isNotEmpty) ||
        (session != null && session.hasPhoto && session.photoUrl != null && session.photoUrl!.isNotEmpty);
    final photoMissing = !hasPhoto || (session != null && !session.hasPhoto);

    if (photoMissing) {
      _showPhotoRequiredDialog(isMandatoryForAttendance: true);
      return;
    }

    context.push(AppRoutes.attendancePreparation);
  }

  void _showPasswordChangeRequiredDialog() {
    final session = ref.read(currentAuthSessionProvider);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.password_rounded, color: Colors.amber, size: 36),
        title: const Text(
          'Password Change Required',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          session?.actionMessage ??
              session?.passwordChangeMessage ??
              'You are using a temporary password. You must change your password before marking attendance.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Later'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.lock_reset_rounded),
            label: const Text('Change Password Now'),
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await context.push(AppRoutes.changePassword);
              if (mounted) {
                ref.invalidate(employeeProfileProvider);
              }
            },
          ),
        ],
      ),
    );
  }

  void _showPhotoRequiredDialog({required bool isMandatoryForAttendance}) {
    final session = ref.read(currentAuthSessionProvider);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.add_a_photo_rounded, color: Colors.amber, size: 36),
        title: Text(
          isMandatoryForAttendance ? 'Profile Photo Required' : 'Profile Picture Missing',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          isMandatoryForAttendance
              ? 'Biometric attendance requires a registered face photo. Please upload your photo before marking attendance.'
              : (session?.photoWarningMessage ??
                  session?.actionMessage ??
                  'No profile picture is registered for your account. Please upload your face photo before marking attendance.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(isMandatoryForAttendance ? 'Cancel' : 'Remind Me Later'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.camera_alt_rounded),
            label: const Text('Upload Photo Now'),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _captureAndUploadPhoto(openAttendanceOnSuccess: isMandatoryForAttendance);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _captureAndUploadPhoto({bool openAttendanceOnSuccess = false}) async {
    final capture = await Navigator.of(context).push<FaceCaptureEvidence>(
      MaterialPageRoute(
        builder: (_) => const FaceCaptureScreen(
          title: 'Enroll Profile Photo',
          instruction: 'Center your face clearly in frame',
        ),
      ),
    );
    if (!mounted || capture == null) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const PopScope(
        canPop: false,
        child: Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Text('Uploading photo & enrolling face…'),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    try {
      final photoUrl = await ref
          .read(photoUploadControllerProvider.notifier)
          .uploadPhoto(photoBytes: capture.bytes);
      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      if (!mounted) return;
      if (photoUrl != null && photoUrl.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 10),
                Expanded(
                  child: Text('Profile photo uploaded and enrolled successfully!'),
                ),
              ],
            ),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
        if (openAttendanceOnSuccess && mounted) {
          _openAttendance();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to upload photo. Please try again.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(safeFailureMessage(e)),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

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
            systemOverlayStyle: SystemUiOverlayStyle.light,
            backgroundColor: brand.heroStart,
            foregroundColor: Colors.white,
            title: Text(
              const [
                'TKS Nexa',
                'Attendance History',
                'Camera Verification',
                'Profile',
                'Settings',
              ][_selectedIndex],
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            actions: [
              IconButton(
                tooltip: 'Refresh All Data',
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _refreshAllData,
              ),
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
                  authToken: authSession?.accessToken,
                  developmentConnectHost: config.developmentConnectHost,
                  developmentConnectPort: config.developmentConnectPort,
                  onMarkAttendance: _openAttendance,
                  onOpenHistory: () => setState(() => _selectedIndex = 1),
                  onOpenProfile: () => setState(() => _selectedIndex = 3),
                  onRefresh: _refreshAllData,
                ),
                const AttendanceHistoryScreen(),
                _AttendancePage(onMarkAttendance: _openAttendance),
                _ProfilePage(
                  employeeName: employeeName,
                  organization: organization,
                  profileState: profileState,
                  authToken: authSession?.accessToken,
                  loginPhotoUrl: authSession?.photoUrl,
                  developmentConnectHost: config.developmentConnectHost,
                  developmentConnectPort: config.developmentConnectPort,
                  onLogout: _logout,
                  onUploadPhoto: _captureAndUploadPhoto,
                ),
                const AppSettingsScreen(),
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
              icon: Icons.person_outline_rounded,
              selectedIcon: Icons.person_rounded,
              label: 'Profile',
              selected: selectedIndex == 3,
              onTap: () => onSelected(3),
            ),
          ),
          Expanded(
            child: _BottomBarItem(
              icon: Icons.settings_outlined,
              selectedIcon: Icons.settings_rounded,
              label: 'Settings',
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
    required this.authToken,
    required this.developmentConnectHost,
    required this.developmentConnectPort,
    required this.onMarkAttendance,
    required this.onOpenHistory,
    required this.onOpenProfile,
    required this.onRefresh,
  });

  final String employeeName;
  final Organization organization;
  final EmployeeProfile? profile;
  final String? authToken;
  final String? developmentConnectHost;
  final int? developmentConnectPort;
  final VoidCallback onMarkAttendance;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenProfile;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth > 760
            ? (constraints.maxWidth - 720) / 2
            : 20.0;
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            12,
            horizontalPadding,
            28,
          ),
          children: [
            Row(
              children: [
                EmployeeAvatar(
                  name: employeeName,
                  photoUrl: profile?.photoUrl,
                  authToken: authToken,
                  developmentConnectHost: developmentConnectHost,
                  developmentConnectPort: developmentConnectPort,
                  size: 50,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hello, ${_firstName(employeeName)}',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: colors.primary,
                              letterSpacing: -0.3,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        profile?.designation.isNotEmpty == true
                            ? profile!.designation
                            : organization.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _OrganizationCard(organization: organization),
            const SizedBox(height: 16),
            _TodaysAttendanceCard(profile: profile),
            const SizedBox(height: 22),
            _RecentAttendanceSection(
              profile: profile,
              onOpenHistory: onOpenHistory,
            ),
            const SizedBox(height: 22),
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
                    icon: Icons.person_rounded,
                    label: 'My Profile',
                    onTap: onOpenProfile,
                  ),
                ),
              ],
            ),
            ],
          ),
        );
      },
    );
  }
}

class _TodaysAttendanceCard extends ConsumerWidget {
  const _TodaysAttendanceCard({required this.profile});

  final EmployeeProfile? profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final brand =
        theme.extension<AppBrandTheme>() ?? AppBrandTheme.fallback;
    final shift = profile?.assignedShift;
    final is24Hour = ref.watch(appPreferencesProvider).value?.use24HourTime ?? false;

    final historyAsync = ref.watch(attendanceHistoryResponseProvider);
    final now = DateTime.now();
    final todayRec = historyAsync.value?.records.where((r) =>
        r.date.year == now.year &&
        r.date.month == now.month &&
        r.date.day == now.day).firstOrNull;

    final (statusLabel, statusColor, statusIcon, statusSubtitle) =
        (todayRec != null && todayRec.firstInFormatted != null && todayRec.firstInFormatted != '--:--')
            ? (
                todayRec.status.toUpperCase(),
                todayRec.isPresent
                    ? const Color(0xFF10B981)
                    : (todayRec.isLate ? const Color(0xFFF59E0B) : const Color(0xFF2563EB)),
                todayRec.isPresent ? Icons.check_circle_rounded : Icons.access_time_filled_rounded,
                'Punch In: ${todayRec.firstInFormatted} · ${todayRec.lastOutFormatted != null ? 'Punch Out: ${todayRec.lastOutFormatted}' : 'Checked In (Active)'}',
              )
            : _getTodayStatusInfo(profile);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: brand.heroGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -35,
            top: -35,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: -40,
            bottom: -50,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white24,
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        statusIcon,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Today's Attendance",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _formattedTodayDate(),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: statusColor.withValues(alpha: 0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 16, color: Colors.white),
                          const SizedBox(width: 7),
                          Text(
                            statusLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              letterSpacing: 0.7,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 17,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          statusSubtitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _HeroMetricItem(
                          icon: Icons.schedule_rounded,
                          label: 'Shift',
                          value: shift?.name ?? 'Standard Shift',
                        ),
                      ),
                      Container(width: 1, height: 38, color: Colors.white24),
                      Expanded(
                        child: _HeroMetricItem(
                          icon: Icons.access_time_rounded,
                          label: 'Shift Hours',
                          value: _formatShiftHours(shift, is24Hour),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatShiftHours(EmployeeShiftProfile? shift, bool is24Hour) {
    final rawStart = shift?.startTime ?? '08:00:00';
    final rawEnd = shift?.endTime ?? '17:00:00';
    final startFormatted = _formatTimeDisplay(rawStart, is24Hour);
    final endFormatted = _formatTimeDisplay(rawEnd, is24Hour);
    return '$startFormatted - $endFormatted';
  }

  String _formatTimeDisplay(String timeStr, bool use24Hour) {
    try {
      final parts = timeStr.trim().split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = parts[1];
        if (use24Hour) {
          return '${hour.toString().padLeft(2, '0')}:$minute';
        } else {
          final period = hour >= 12 ? 'PM' : 'AM';
          var h = hour % 12;
          if (h == 0) h = 12;
          return '${h.toString().padLeft(2, '0')}:$minute $period';
        }
      }
    } catch (_) {}
    return timeStr;
  }

  (String, Color, IconData, String) _getTodayStatusInfo(
      EmployeeProfile? profile) {
    if (profile == null) {
      return (
        'NOT MARKED',
        const Color(0xFFF59E0B),
        Icons.schedule_rounded,
        'Checking today\'s attendance record...'
      );
    }

    final reasons = profile.attendanceReasons;
    final reasonsText = reasons.join(' ').toLowerCase();

    if (reasonsText.contains('already marked') ||
        reasonsText.contains('present') ||
        (!profile.canMarkAttendance && reasonsText.contains('completed'))) {
      return (
        'PRESENT',
        const Color(0xFF10B981),
        Icons.check_circle_rounded,
        'Verified attendance recorded for today.'
      );
    }
    if (reasonsText.contains('leave') || reasonsText.contains('on leave')) {
      return (
        'ON LEAVE',
        const Color(0xFF8B5CF6),
        Icons.flight_takeoff_rounded,
        'Approved official leave status.'
      );
    }
    if (reasonsText.contains('official duty') || reasonsText.contains('duty')) {
      return (
        'OFFICIAL DUTY',
        const Color(0xFF2563EB),
        Icons.business_center_rounded,
        'Assigned on official duty assignment.'
      );
    }
    if (!profile.canMarkAttendance &&
        (reasonsText.contains('absent') || reasonsText.contains('holiday'))) {
      return (
        'ABSENT',
        const Color(0xFFEF4444),
        Icons.cancel_rounded,
        'No attendance recorded for today.'
      );
    }

    return (
      'NOT MARKED',
      const Color(0xFFF59E0B),
      Icons.pending_actions_rounded,
      'Pending punch for today\'s shift.'
    );
  }

  String _formattedTodayDate() {
    final now = DateTime.now();
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayName = days[now.weekday - 1];
    final monthName = months[now.month - 1];
    return '$dayName, ${now.day} $monthName ${now.year}';
  }
}

class _HeroMetricItem extends StatelessWidget {
  const _HeroMetricItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF9BE7F4), size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
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

class _RecentAttendanceSection extends ConsumerWidget {
  const _RecentAttendanceSection({
    required this.profile,
    required this.onOpenHistory,
  });

  final EmployeeProfile? profile;
  final VoidCallback onOpenHistory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final historyAsync = ref.watch(attendanceHistoryResponseProvider);
    final records = historyAsync.value?.records ?? const <AttendanceRecord>[];
    final items = _generateRecentDays(profile, records);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Mobile Attendance Logs',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.2,
              ),
            ),
            TextButton.icon(
              onPressed: onOpenHistory,
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: const Text(
                'View All',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 195,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return _RecentDayCard(
                item: items[index],
                onTap: onOpenHistory,
              );
            },
          ),
        ),
      ],
    );
  }

  List<_RecentDayItem> _generateRecentDays(
    EmployeeProfile? profile,
    List<AttendanceRecord> records,
  ) {
    final now = DateTime.now();
    final days = <_RecentDayItem>[];
    final shiftName = profile?.assignedShift?.name ?? 'Standard Shift';

    // 1. Check if today is in records
    final todayRec = records.where((r) =>
        r.date.year == now.year &&
        r.date.month == now.month &&
        r.date.day == now.day).firstOrNull;

    if (todayRec != null &&
        todayRec.firstInFormatted != null &&
        todayRec.firstInFormatted != '--:--') {
      final isPres = todayRec.isPresent;
      final isLate = todayRec.isLate;
      days.add(_RecentDayItem(
        date: now,
        status: todayRec.status.toUpperCase(),
        color: isPres
            ? const Color(0xFF10B981)
            : (isLate ? const Color(0xFFF59E0B) : const Color(0xFF2563EB)),
        icon: isPres
            ? Icons.check_circle_rounded
            : (isLate ? Icons.access_time_filled_rounded : Icons.verified_user_rounded),
        subtitle:
            '${todayRec.shiftName.isNotEmpty ? todayRec.shiftName : shiftName} · ${todayRec.trustScore ?? 100}% Trust',
        timeRange:
            '${todayRec.firstInFormatted ?? '--:--'} - ${todayRec.lastOutFormatted ?? 'Active'}',
        capturedPhotoUrl: todayRec.photoUrl,
      ));
    } else {
      days.add(_RecentDayItem(
        date: now,
        status: 'PENDING',
        color: const Color(0xFFF59E0B),
        icon: Icons.pending_actions_rounded,
        subtitle: '$shiftName · Awaiting punch',
        timeRange: 'Not marked yet',
        capturedPhotoUrl: null,
      ));
    }

    // 2. Add past records (excluding today)
    for (final rec in records) {
      if (rec.date.year == now.year &&
          rec.date.month == now.month &&
          rec.date.day == now.day) {
        continue;
      }
      if (days.length >= 7) break;

      final isPres = rec.isPresent;
      final isLate = rec.isLate;
      final isOff = (rec.date.weekday == DateTime.saturday ||
              rec.date.weekday == DateTime.sunday) ||
          rec.isOffDay;
      final isDuty = rec.isOfficialDuty;
      final isLeave = rec.isOnLeave;

      Color color;
      IconData icon;
      if (isPres) {
        color = const Color(0xFF10B981);
        icon = Icons.check_circle_rounded;
      } else if (isLate) {
        color = const Color(0xFFF59E0B);
        icon = Icons.access_time_filled_rounded;
      } else if (isDuty) {
        color = const Color(0xFF2563EB);
        icon = Icons.business_center_rounded;
      } else if (isLeave) {
        color = const Color(0xFF8B5CF6);
        icon = Icons.flight_takeoff_rounded;
      } else if (isOff) {
        color = const Color(0xFF6B7280);
        icon = Icons.weekend_rounded;
      } else {
        color = const Color(0xFFEF4444);
        icon = Icons.cancel_rounded;
      }

      final timeRange = (rec.firstInFormatted != null &&
              rec.firstInFormatted != '--:--')
          ? '${rec.firstInFormatted} - ${rec.lastOutFormatted ?? '--:--'}'
          : (isOff
              ? 'Weekly Off'
              : (isLeave
                  ? 'Approved Leave'
                  : (isDuty ? 'Official Duty' : 'Absent')));

      days.add(_RecentDayItem(
        date: rec.date,
        status: rec.status.toUpperCase(),
        color: color,
        icon: icon,
        subtitle:
            '${rec.shiftName.isNotEmpty ? rec.shiftName : shiftName} · ${rec.trustScore ?? 100}% Trust',
        timeRange: timeRange,
        capturedPhotoUrl: rec.photoUrl,
      ));
    }

    // 3. Fallback padding if brand new account with no history
    if (days.length == 1) {
      for (var i = 1; i <= 4; i++) {
        final d = now.subtract(Duration(days: i));
        final isWeekend =
            d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;
        days.add(_RecentDayItem(
          date: d,
          status: isWeekend ? 'OFF DAY' : 'NOT RECORDED',
          color: const Color(0xFF6B7280),
          icon: isWeekend ? Icons.weekend_rounded : Icons.history_rounded,
          subtitle: '$shiftName · Timesheet',
          timeRange: isWeekend ? 'Weekly Off' : 'No record',
          capturedPhotoUrl: null,
        ));
      }
    }

    return days;
  }
}

class _RecentDayItem {
  const _RecentDayItem({
    required this.date,
    required this.status,
    required this.color,
    required this.icon,
    required this.subtitle,
    required this.timeRange,
    this.capturedPhotoUrl,
  });

  final DateTime date;
  final String status;
  final Color color;
  final IconData icon;
  final String subtitle;
  final String timeRange;
  final String? capturedPhotoUrl;
}

class _RecentDayCard extends ConsumerWidget {
  const _RecentDayCard({required this.item, this.onTap});

  final _RecentDayItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dateStr = _formatDateShort(item.date);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: 175,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: item.color.withValues(alpha: 0.35),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Captured Mobile Attendance Picture Header
            Stack(
              children: [
                Container(
                  height: 98,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.16),
                  ),
                  child: _buildItemImage(context, ref, item),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.3),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.55),
                        ],
                      ),
                    ),
                  ),
                ),
              // Top-Right Corner Floating Status Badge (ACCEPTED / MATCHED / PENDING / REJECTED / DUTY)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: item.color,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: item.color.withValues(alpha: 0.45),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(item.icon, size: 13, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        item.status,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Top-Left Mobile Camera Badge
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    size: 11,
                    color: Colors.white,
                  ),
                ),
              ),
              Positioned(
                bottom: 6,
                left: 10,
                child: Text(
                  dateStr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    shadows: [
                      Shadow(blurRadius: 4, color: Color(0xCC000000)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.timeRange,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  }

  Widget _buildItemImage(BuildContext context, WidgetRef ref, _RecentDayItem item) {
    final photo = item.capturedPhotoUrl;
    if (photo != null && photo.isNotEmpty) {
      if (photo.startsWith('http://') || photo.startsWith('https://')) {
        return Image.network(
          photo,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          errorBuilder: (_, _, _) => _cameraImageFallback(item.color),
        );
      } else {
        final file = File(photo);
        if (file.existsSync()) {
          return Image.file(
            file,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (_, _, _) => _cameraImageFallback(item.color),
          );
        }
      }
    }
    // Check local storage for today's selfie
    final isToday = item.date.day == DateTime.now().day &&
        item.date.month == DateTime.now().month &&
        item.date.year == DateTime.now().year;
    if (isToday) {
      return FutureBuilder<String?>(
        future: ref.read(localSelfieStorageProvider).getSelfiePath(date: item.date),
        builder: (context, snapshot) {
          final localPath = snapshot.data;
          if (localPath != null && localPath.isNotEmpty) {
            final f = File(localPath);
            if (f.existsSync()) {
              return Image.file(
                f,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                errorBuilder: (_, _, _) => _cameraImageFallback(item.color),
              );
            }
          }
          return _cameraImageFallback(item.color);
        },
      );
    }

    return _cameraImageFallback(item.color);
  }

  static Widget _cameraImageFallback(Color accentColor) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentColor.withValues(alpha: 0.28),
            accentColor.withValues(alpha: 0.10),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.camera_front_rounded,
                size: 22,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 3),
            const Text(
              'Verified Punch',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDateShort(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayName = days[date.weekday - 1];
    final monthName = months[date.month - 1];
    return '$dayName, ${date.day} $monthName';
  }
}

class _OrganizationCard extends StatelessWidget {
  const _OrganizationCard({required this.organization});

  final Organization organization;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer.withValues(alpha: .5),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: .2),
                ),
              ),
              child: Image.asset(
                isDark
                    ? 'assets/images/logo_transparent_for_dark_bg.png'
                    : 'assets/images/logo_transparent_for_light_bg.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Image.asset(
                  'assets/images/android-chrome-512x512.png',
                  fit: BoxFit.contain,
                ),
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
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppPalette.emerald.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppPalette.emerald.withValues(alpha: 0.25),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified_rounded,
                          size: 14,
                          color: AppPalette.emerald,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Securely connected',
                          style: TextStyle(
                            color: AppPalette.emerald,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.shield_outlined,
                color: colorScheme.primary,
                size: 22,
              ),
            ),
          ],
        ),
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
    required this.onUploadPhoto,
  });

  final String employeeName;
  final Organization organization;
  final AsyncValue<EmployeeProfile> profileState;
  final String? authToken;
  final String? loginPhotoUrl;
  final String? developmentConnectHost;
  final int? developmentConnectPort;
  final VoidCallback onLogout;
  final VoidCallback onUploadPhoto;

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
            const _ProfileSectionLabel('ACCOUNT DETAILS'),
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
                    icon: Icons.camera_alt_rounded,
                    title: (profileState.value?.photoUrl?.isNotEmpty ?? false)
                        ? 'Update face photo'
                        : 'Upload face photo',
                    subtitle: 'Capture clear face photo for biometric verification',
                    accent: Colors.teal,
                    onTap: onUploadPhoto,
                  ),
                  const Divider(height: 1, indent: 68),
                  _ProfileTile(
                    icon: Icons.password_rounded,
                    title: 'Change password',
                    subtitle: 'Update your account password securely',
                    accent: colorScheme.tertiary,
                    onTap: () => context.push(AppRoutes.changePassword),
                  ),
                  const Divider(height: 1, indent: 68),
                  _ProfileTile(
                    keyName: const Key('logout'),
                    icon: Icons.logout_rounded,
                    title: 'Sign out securely',
                    subtitle: 'End your session on this device',
                    accent: colorScheme.error,
                    onTap: onLogout,
                  ),
                ],
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
    this.keyName,
  });

  final Key? keyName;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return ListTile(
      key: keyName,
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
                    if (profile != null && profile!.employeeCode.trim().isNotEmpty)
                      _ProfilePill(
                        icon: Icons.badge_outlined,
                        label: 'ID: ${profile!.employeeCode.trim()}',
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
                          child: _ProfileMetrics(
                            icon: Icons.schedule_rounded,
                            value:
                                employee.assignedShift?.name ?? 'Not assigned',
                            label: 'Shift',
                          ),
                        ),
                        const _MetricDivider(),
                        Expanded(
                          child: _ProfileMetrics(
                            icon: Icons.face_retouching_natural_rounded,
                            value: employee.faceEnrolled ? 'Ready' : 'Pending',
                            label: 'Face ID',
                          ),
                        ),
                        const _MetricDivider(),
                        Expanded(
                          child: _ProfileMetrics(
                            icon: Icons.verified_rounded,
                            value: employee.canMarkAttendance
                                ? 'Allowed'
                                : 'Limited',
                            label: 'Attendance History',
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

class _ProfileMetrics extends StatelessWidget {
  const _ProfileMetrics({required this.icon, required this.value, required this.label});

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
                      label: 'My Profile',
                      onTap: () => onDestinationSelected(3),
                    ),
                    _DrawerMenuTile(
                      icon: Icons.fact_check_rounded,
                      label: 'Attendance History',
                      onTap: () => onDestinationSelected(1),
                    ),
                    _DrawerMenuTile(
                      icon: Icons.event_note_rounded,
                      label: 'Leave & Duty Requests',
                      onTap: () => openRoute(AppRoutes.requests),
                    ),
                    _DrawerMenuTile(
                      icon: Icons.notifications_rounded,
                      label: 'Notifications',
                      onTap: () => openRoute(AppRoutes.notificationPreferences),
                    ),
                    _DrawerMenuTile(
                      icon: Icons.security_rounded,
                      label: 'Security & Devices',
                      onTap: () => openRoute(AppRoutes.securityDevices),
                    ),
                    _DrawerMenuTile(
                      icon: Icons.settings_rounded,
                      label: 'App Settings',
                      onTap: () => onDestinationSelected(4),
                    ),
                    _DrawerMenuTile(
                      icon: Icons.info_outline_rounded,
                      label: 'About TKS Nexa',
                      onTap: () {
                        Navigator.of(context).pop();
                        _showAboutDialog(context);
                      },
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
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 26,
                      child: Image.asset(
                        'assets/images/logo_transparent_for_dark_bg.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Text(
                          'TKS Nexa',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const _DrawerVersionText(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerVersionText extends StatefulWidget {
  const _DrawerVersionText();

  @override
  State<_DrawerVersionText> createState() => _DrawerVersionTextState();
}

class _DrawerVersionTextState extends State<_DrawerVersionText> {
  String _version = 'v1.0.0';

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _version = 'v${info.version} (${info.buildNumber})';
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _version,
      style: TextStyle(
        color: Colors.white.withValues(alpha: .5),
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }
}

void _showAboutDialog(BuildContext context) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;

  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      title: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.7),
              shape: BoxShape.circle,
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Image.asset(
              isDark
                  ? 'assets/images/logo_transparent_for_dark_bg.png'
                  : 'assets/images/logo_transparent_for_light_bg.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Image.asset(
                'assets/images/android-chrome-512x512.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'TKS NEXA',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Cross-Platform Biometric Mobile Attendance',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Divider(),
            const SizedBox(height: 12),
            const _AboutFeatureRow(
              icon: Icons.face_rounded,
              title: 'On-Device Edge Biometrics',
              description: '3D passive liveness detection & neural face vector matching.',
            ),
            const SizedBox(height: 12),
            const _AboutFeatureRow(
              icon: Icons.location_on_rounded,
              title: 'Geofence Verification',
              description: 'High-accuracy polygon campus geofencing & anti-spoofing.',
            ),
            const SizedBox(height: 12),
            const _AboutFeatureRow(
              icon: Icons.security_rounded,
              title: 'Hardware Keystore Security',
              description: 'Cryptographic nonce signatures & Play Integrity attestation.',
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Center(
              child: Column(
                children: [
                  Text(
                    'Engineered & Developed by',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'TheKhanSoft',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'https://tksnexa.me',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

class _AboutFeatureRow extends StatelessWidget {
  const _AboutFeatureRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ],
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
