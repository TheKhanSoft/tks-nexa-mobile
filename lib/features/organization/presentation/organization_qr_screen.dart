import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:tks_nexa_attendance/app/app_router.dart';
import 'package:tks_nexa_attendance/features/organization/application/organization_providers.dart';
import 'package:tks_nexa_attendance/features/organization/presentation/failure_message.dart';

class OrganizationQrScreen extends ConsumerStatefulWidget {
  const OrganizationQrScreen({super.key});

  @override
  ConsumerState<OrganizationQrScreen> createState() =>
      _OrganizationQrScreenState();
}

class _OrganizationQrScreenState extends ConsumerState<OrganizationQrScreen> {
  final _scannerController = MobileScannerController(
    autoStart: false,
    formats: const [BarcodeFormat.qrCode],
  );
  bool _scanning = false;
  bool _resolving = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _startScanning() {
    setState(() => _scanning = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scannerController.start();
    });
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_resolving || capture.barcodes.isEmpty) return;
    final value = capture.barcodes.first.rawValue;
    if (value == null || value.trim().isEmpty) return;
    setState(() => _resolving = true);
    await _scannerController.stop();
    final organization = await ref
        .read(organizationLookupProvider.notifier)
        .resolveByCode(value);
    if (!mounted) return;
    if (organization != null) {
      try {
        await ref
            .read(organizationSessionProvider.notifier)
            .select(organization);
        if (mounted) context.go(AppRoutes.login);
      } on Object {
        if (mounted) setState(() => _resolving = false);
      }
      return;
    }
    setState(() => _resolving = false);
    await _scannerController.start();
  }

  @override
  Widget build(BuildContext context) {
    final lookup = ref.watch(organizationLookupProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Organization QR')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_scanning) ...[
                const Spacer(),
                const Icon(Icons.qr_code_scanner, size: 88),
                const SizedBox(height: 24),
                Text(
                  'Camera access',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'The camera is used only to read the organization code. '
                  'No image is stored or uploaded.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: _startScanning,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Open camera'),
                ),
                const Spacer(),
              ] else ...[
                Text(
                  'Place the QR code inside the frame',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        MobileScanner(
                          controller: _scannerController,
                          onDetect: _onDetect,
                        ),
                        IgnorePointer(
                          child: Center(
                            child: Container(
                              width: 230,
                              height: 230,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                          ),
                        ),
                        if (_resolving)
                          const ColoredBox(
                            color: Color(0x88000000),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                      ],
                    ),
                  ),
                ),
                if (lookup.hasError) ...[
                  const SizedBox(height: 12),
                  Text(
                    safeFailureMessage(lookup.error!),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
