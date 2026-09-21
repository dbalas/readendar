// ISBN barcode scanner (spec §17). Reads a book's EAN-13 barcode on-device
// (ML Kit on Android, Vision on iOS), validates it as a book ISBN, and pops
// with the normalized ISBN-13. Manual entry opens an ISBN field and pops the
// same way. Returns null when the user backs out of the scanner.

import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/utils/isbn.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/core/widgets/rd_icon_button.dart';
import 'package:readendar/core/widgets/toast.dart';
import 'package:readendar/features/search/isbn_manual_entry_sheet.dart';

class IsbnScannerScreen extends StatefulWidget {
  const IsbnScannerScreen({super.key});

  @override
  State<IsbnScannerScreen> createState() => _IsbnScannerScreenState();
}

class _IsbnScannerScreenState extends State<IsbnScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.ean13],
  );

  // Guards against popping more than once when several frames decode the same
  // barcode before the route finishes closing.
  bool _handled = false;
  // Ignore camera frames while the typed-ISBN sheet is open so a late decode
  // cannot dismiss the field.
  bool _enteringManually = false;
  DateTime? _lastHintAt;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled || _enteringManually) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;
      final isbn = normalizeScannedIsbn(raw);
      if (isbn != null) {
        _handled = true;
        Navigator.of(context).pop(isbn);
        return;
      }
    }
    // A code was read but it isn't a book ISBN — keep scanning, hint sparingly.
    _maybeShowNotABookHint();
  }

  void _maybeShowNotABookHint() {
    final now = DateTime.now();
    if (_lastHintAt != null &&
        now.difference(_lastHintAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastHintAt = now;
    final l = AppL10n.of(context);
    showRdToast(
      context,
      message: l.scanIsbnNotABook,
      duration: const Duration(milliseconds: 1500),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(l.scanIsbnTitle),
        actions: [
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, _) {
              final on = state.torchState == TorchState.on;
              if (state.torchState == TorchState.unavailable) {
                return const SizedBox.shrink();
              }
              return RdIconButton(
                tooltip: l.scanIsbnTorch,
                icon: on ? LucideIcons.zap : LucideIcons.zapOff,
                onPressed: _controller.toggleTorch,
              );
            },
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) =>
                _ScannerError(error: error, onManualEntry: _manualEntry),
          ),
          const _ViewfinderOverlay(),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomBar(
              instruction: l.scanIsbnInstruction,
              manualLabel: l.scanIsbnManualEntry,
              onManualEntry: _manualEntry,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _manualEntry() async {
    if (_handled || _enteringManually) return;
    _enteringManually = true;
    try {
      final isbn = await showIsbnManualEntrySheet(context);
      if (!mounted) return;
      if (isbn == null) return;
      _handled = true;
      Navigator.of(context).pop(isbn);
    } finally {
      _enteringManually = false;
    }
  }
}

/// Translucent overlay with a centered framing window.
class _ViewfinderOverlay extends StatelessWidget {
  const _ViewfinderOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          width: 280,
          height: 150,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.9),
              width: 3,
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.instruction,
    required this.manualLabel,
    required this.onManualEntry,
  });

  final String instruction;
  final String manualLabel;
  final VoidCallback onManualEntry;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                instruction,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(height: 16),
              RdButton.plain(
                onPressed: onManualEntry,
                icon: LucideIcons.keyboard,
                label: manualLabel,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown when the camera can't start — most importantly when the user denied
/// camera permission. Offers a deep-link to Settings and a manual fallback.
class _ScannerError extends StatelessWidget {
  const _ScannerError({required this.error, required this.onManualEntry});

  final MobileScannerException error;
  final VoidCallback onManualEntry;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: Colors.black,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.cameraOff, color: Colors.white, size: 48),
            const SizedBox(height: 16),
            Text(
              denied ? l.scanPermissionTitle : l.scanIsbnTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (denied) ...[
              const SizedBox(height: 8),
              Text(
                l.scanPermissionBody,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 20),
              RdButton.primary(
                onPressed: openAppSettings,
                icon: LucideIcons.settings,
                label: l.scanPermissionOpenSettings,
              ),
            ],
            const SizedBox(height: 12),
            RdButton.plain(
              onPressed: onManualEntry,
              icon: LucideIcons.keyboard,
              label: l.scanIsbnManualEntry,
            ),
          ],
        ),
      ),
    );
  }
}
