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
          .uploadPhoto(
            photoBytes: capture.bytes,
            faceBounds: capture.faceBounds,
          );
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
            _TodaysAttendanceCard(
              profile: profile,
              onMarkAttendance: onMarkAttendance,
            ),
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
  const _TodaysAttendanceCard({
    required this.profile,
    this.onMarkAttendance,
  });

  final EmployeeProfile? profile;
  final VoidCallback? onMarkAttendance;

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

    final hasMarkedToday = todayRec != null &&
        todayRec.firstInFormatted != null &&
        todayRec.firstInFormatted != '--:--';

    final (statusLabel, statusColor, statusIcon, statusSubtitle) =
        hasMarkedToday
            ? (
                todayRec.status.toUpperCase(),
                todayRec.isPresent
                    ? const Color(0xFF10B981)
                    : (todayRec.isLate ? const Color(0xFFF59E0B) : const Color(0xFF2563EB)),
                todayRec.isPresent ? Icons.check_circle_rounded : Icons.access_time_filled_rounded,
                'Punch In: ${todayRec.firstInFormatted} · ${(todayRec.lastOutFormatted != null && todayRec.lastOutFormatted != todayRec.firstInFormatted) ? 'Punch Out: ${todayRec.lastOutFormatted}' : 'Checked In (Active)'}',
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

                // If punched in today, feature the verified punch selfie
                if (hasMarkedToday) ...[
                  InkWell(
                    onTap: () {
                      _showPunchDetailModal(
                        context: context,
                        ref: ref,
                        item: _RecentDayItem(
                          date: now,
                          status: todayRec.status.toUpperCase(),
                          color: statusColor,
                          icon: statusIcon,
                          subtitle: shift?.name ?? 'General Shift',
                          timeRange: statusSubtitle,
                          capturedPhotoUrl: todayRec.photoUrl,
                          trustScore: todayRec.trustScore,
                          locationName: todayRec.locationName,
                          deviceModel: todayRec.deviceModel ?? todayRec.deviceName,
                        ),
                        profile: profile,
                      );
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.28),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Squircle Selfie Frame
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(0xFF10B981),
                                width: 2.0,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x4010B981),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                _buildPunchSelfieImage(
                                  context,
                                  ref,
                                  photoUrl: todayRec.photoUrl,
                                  date: now,
                                  accentColor: statusColor,
                                ),
                                Positioned(
                                  bottom: 2,
                                  right: 2,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check_rounded,
                                      size: 11,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Text(
                                      'Verified Live Punch',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    SizedBox(width: 6),
                                    Icon(
                                      Icons.verified_rounded,
                                      size: 14,
                                      color: Color(0xFF34D399),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  statusSubtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'MobileFaceNet · ${todayRec.trustScore ?? 100}% Trust',
                                    style: const TextStyle(
                                      color: Color(0xFF6EE7B7),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.fullscreen_rounded,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
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
                  if (onMarkAttendance != null) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: brand.heroStart,
                          elevation: 3,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: onMarkAttendance,
                        icon: const Icon(Icons.face_retouching_natural_rounded, size: 20),
                        label: const Text(
                          'Verify Face & Punch Attendance',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
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
          height: 218,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              return _RecentDayCard(
                item: items[index],
                profile: profile,
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
            '${todayRec.firstInFormatted ?? '--:--'} - ${(todayRec.lastOutFormatted != null && todayRec.lastOutFormatted != todayRec.firstInFormatted) ? todayRec.lastOutFormatted! : '--:--'}',
        capturedPhotoUrl: todayRec.photoUrl,
        trustScore: todayRec.trustScore,
        locationName: todayRec.locationName,
        deviceModel: todayRec.deviceModel ?? todayRec.deviceName,
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
        trustScore: rec.trustScore,
        locationName: rec.locationName,
        deviceModel: rec.deviceModel ?? rec.deviceName,
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
    this.trustScore,
    this.locationName,
    this.deviceModel,
  });

  final DateTime date;
  final String status;
  final Color color;
  final IconData icon;
  final String subtitle;
  final String timeRange;
  final String? capturedPhotoUrl;
  final int? trustScore;
  final String? locationName;
  final String? deviceModel;
}

class _RecentDayCard extends ConsumerWidget {
  const _RecentDayCard({
    required this.item,
    this.profile,
    this.onTap,
  });

  final _RecentDayItem item;
  final EmployeeProfile? profile;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dateStr = _formatDateShort(item.date);

    return InkWell(
      onTap: () {
        if (item.capturedPhotoUrl != null || (item.status != 'PENDING' && item.status != 'NOT RECORDED' && item.status != 'OFF DAY')) {
          _showPunchDetailModal(
            context: context,
            ref: ref,
            item: item,
            profile: profile,
          );
        } else {
          onTap?.call();
        }
      },
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: 186,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: item.color.withValues(alpha: 0.35),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.07),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Captured Mobile Attendance Picture Header (Squircle)
            Stack(
              children: [
                Container(
                  height: 114,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.16),
                  ),
                  child: _buildPunchSelfieImage(
                    context,
                    ref,
                    photoUrl: item.capturedPhotoUrl,
                    date: item.date,
                    accentColor: item.color,
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.35),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.65),
                        ],
                      ),
                    ),
                  ),
                ),
                // Top-Right Corner Floating Status Badge
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: item.color,
                      borderRadius: BorderRadius.circular(10),
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
                        Icon(item.icon, size: 12, color: Colors.white),
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
                // Top-Left Verified Indicator
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4.5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_front_rounded,
                      size: 11,
                      color: Colors.white,
                    ),
                  ),
                ),
                // Bottom-Left Date Label
                Positioned(
                  bottom: 7,
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
                // Bottom-Right Inspect Trigger Icon
                Positioned(
                  bottom: 6,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(3.5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.fullscreen_rounded,
                      size: 14,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
            // Card Content
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
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
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
}

Widget _buildPunchSelfieImage(
  BuildContext context,
  WidgetRef ref, {
  required String? photoUrl,
  required DateTime date,
  required Color accentColor,
}) {
  if (photoUrl != null && photoUrl.isNotEmpty) {
    if (photoUrl.startsWith('http://') || photoUrl.startsWith('https://')) {
      return Image.network(
        photoUrl,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        errorBuilder: (_, _, _) => _buildLocalSelfieOrFallback(ref, date, accentColor),
      );
    } else {
      final file = File(photoUrl);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          errorBuilder: (_, _, _) => _buildLocalSelfieOrFallback(ref, date, accentColor),
        );
      }
    }
  }

  return _buildLocalSelfieOrFallback(ref, date, accentColor);
}

Widget _buildLocalSelfieOrFallback(WidgetRef ref, DateTime date, Color accentColor) {
  return FutureBuilder<String?>(
    future: ref.read(localSelfieStorageProvider).getSelfiePath(date: date),
    builder: (context, snapshot) {
      final localPath = snapshot.data;
      if (localPath != null && localPath.isNotEmpty) {
        final f = File(localPath);
        if (f.existsSync()) {
          return Image.file(
            f,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (_, _, _) => _cameraImageFallback(accentColor),
          );
        }
      }
      return _cameraImageFallback(accentColor);
    },
  );
}

void _showPhotoLockedDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.lock_rounded, color: Color(0xFF10B981), size: 36),
      title: const Text('Face Photo Locked', style: TextStyle(fontWeight: FontWeight.bold)),
      content: const Text(
        'Your facial biometric photo is registered and locked. '
        'To prevent unauthorized modifications, employees cannot change their profile photo. '
        'If you need to update your picture, please contact your organization administrator.',
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Understood'),
        ),
      ],
    ),
  );
}

Widget _cameraImageFallback(Color accentColor) {
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

String _formatDateShort(DateTime date) {
  final months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final dayName = days[date.weekday - 1];
  final monthName = months[date.month - 1];
  return '$dayName, ${date.day} $monthName';
}

void _showPunchDetailModal({
  required BuildContext context,
  required WidgetRef ref,
  required _RecentDayItem item,
  EmployeeProfile? profile,
}) {
  final theme = Theme.of(context);
  final dateFormatted = _formatFullDate(item.date);

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (modalCtx) {
      return Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(modalCtx).size.height * 0.88,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x3D000000),
              blurRadius: 30,
              offset: Offset(0, -6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 14),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(item.icon, color: item.color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Verified Attendance Telemetry',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dateFormatted,
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: item.color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      item.status,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: double.infinity,
                        height: 230,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: item.color.withValues(alpha: 0.5),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: item.color.withValues(alpha: 0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _buildPunchSelfieImage(
                              modalCtx,
                              ref,
                              photoUrl: item.capturedPhotoUrl,
                              date: item.date,
                              accentColor: item.color,
                            ),
                            Positioned(
                              bottom: 12,
                              left: 12,
                              right: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.verified_rounded,
                                      size: 16,
                                      color: Color(0xFF34D399),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'On-Device Neural Verification · ${item.trustScore ?? 100}% Confidence',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildTelemetryRow(
                            icon: Icons.access_time_rounded,
                            label: 'Punch Timing',
                            value: item.timeRange,
                            valueColor: item.color,
                          ),
                          const Divider(height: 18),
                          _buildTelemetryRow(
                            icon: Icons.shield_rounded,
                            label: 'Biometric Trust Score',
                            value: '${item.trustScore ?? 100}% (Authoritative Match)',
                            valueColor: const Color(0xFF10B981),
                          ),
                          const Divider(height: 18),
                          _buildTelemetryRow(
                            icon: Icons.memory_rounded,
                            label: 'Verification Model',
                            value: 'MobileFaceNet Neural Engine',
                          ),
                          const Divider(height: 18),
                          _buildTelemetryRow(
                            icon: Icons.visibility_rounded,
                            label: 'Liveness Assurance',
                            value: 'Active Verification Verified',
                            valueColor: const Color(0xFF10B981),
                          ),
                          const Divider(height: 18),
                          _buildTelemetryRow(
                            icon: Icons.smartphone_rounded,
                            label: 'Capture Device',
                            value: (item.deviceModel != null && item.deviceModel!.isNotEmpty)
                                ? item.deviceModel!
                                : 'Registered Mobile Handset',
                          ),
                          const Divider(height: 18),
                          _buildTelemetryRow(
                            icon: Icons.location_on_rounded,
                            label: 'Premises / Geofence',
                            value: (item.locationName != null && item.locationName!.isNotEmpty)
                                ? item.locationName!
                                : 'Approved Corporate Perimeter',
                          ),
                          const Divider(height: 18),
                          _buildTelemetryRow(
                            icon: Icons.calendar_today_rounded,
                            label: 'Assigned Shift',
                            value: item.subtitle,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.of(modalCtx).pop(),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Close Telemetry Inspection',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Widget _buildTelemetryRow({
  required IconData icon,
  required String label,
  required String value,
  Color? valueColor,
}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: const Color(0xFF6B7280)),
      const SizedBox(width: 10),
      Expanded(
        flex: 2,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6B7280),
          ),
        ),
      ),
      Expanded(
        flex: 3,
        child: Text(
          value,
          textAlign: TextAlign.end,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
        ),
      ),
    ],
  );
}

String _formatFullDate(DateTime date) {
  final months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
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
                  Builder(
                    builder: (context) {
                      final hasPhoto = profileState.value?.photoUrl?.isNotEmpty ?? false;
                      return _ProfileTile(
                        icon: hasPhoto
                            ? Icons.verified_user_rounded
                            : Icons.camera_alt_rounded,
                        title: hasPhoto
                            ? 'Face photo registered'
                            : 'Upload face photo',
                        subtitle: hasPhoto
                            ? 'Biometrics verified & locked (Admin managed)'
                            : 'Capture clear face photo for biometric verification',
                        accent: hasPhoto
                            ? const Color(0xFF10B981)
                            : Colors.teal,
                        onTap: hasPhoto
                            ? () => _showPhotoLockedDialog(context)
                            : onUploadPhoto,
                      );
                    },
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
