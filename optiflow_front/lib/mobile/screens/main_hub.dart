import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../core/api_service.dart';
import '../core/app_theme.dart';
import '../core/auth_service.dart';
import '../widgets/machine_card.dart';
import '../models/machine_model.dart';
import 'home_screen.dart';
import 'job_market_screen.dart';
import 'machine_market_screen.dart';
import 'login_screen.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MainHub — the shell that owns the BottomNavigationBar and the FAB.
///
/// Navigation items:
///   0 — HomeScreen     (My Tasks)
///   1 — JobMarketScreen (Job Market)
///   2 — MachineMarketScreen (Machine Shop)
///
/// FAB — QR code scanner that resolves a machine_id and opens its booking sheet.
/// ─────────────────────────────────────────────────────────────────────────────
class MainHub extends StatefulWidget {
  const MainHub({super.key});

  @override
  State<MainHub> createState() => _MainHubState();
}

class _MainHubState extends State<MainHub> {
  int _currentIndex = 0;

  // Keep a GlobalKey for MachineMarketScreen so we can call its method from FAB.
  final _machineScreenKey = GlobalKey<MachineMarketScreenState>();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const HomeScreen(),
      const JobMarketScreen(),
      MachineMarketScreen(key: _machineScreenKey),
    ];
  }

  // ── QR Scan FAB ──────────────────────────────────────────────────────────
  void _openQrScanner() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QrScanSheet(
        onMachineIdScanned: _handleQrMachineId,
      ),
    );
  }

  Future<void> _handleQrMachineId(String machineId) async {
    // Try to find the machine in the existing list first.
    // If the machine screen is not active, fetch directly.
    final machineState = _machineScreenKey.currentState;
    if (machineState != null) {
      // Switch to Machine tab and open booking sheet.
      setState(() => _currentIndex = 2);
      // Give the screen a frame to rebuild, then open the sheet.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        machineState.openBookingSheetForId(machineId);
      });
    } else {
      // Fallback: fetch machine directly and show booking sheet inline.
      try {
        final raw = await ApiService.instance.fetchMachineById(machineId);
        final machine = raw != null
            ? MachineModel.fromJson(raw)
            : MachineModel(
                id: machineId,
                name: 'Scanned Machine',
                status: 'Unknown',
              );
        if (mounted) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => MachineBookingSheet(
              machine: machine,
              onBookingDone: () {},
            ),
          );
        }
      } catch (_) {}
    }
  }

  // ── Sign Out ─────────────────────────────────────────────────────────────
  void _signOut() async {
    await AuthService.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),

      // ── QR Floating Action Button ─────────────────────────────────────────
      floatingActionButton: FloatingActionButton(
        onPressed: _openQrScanner,
        backgroundColor: AppColors.primary,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.qr_code_scanner_rounded,
            color: Colors.white, size: 26),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // ── Bottom Navigation Bar ─────────────────────────────────────────────
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: BottomAppBar(
            color: Colors.white,
            elevation: 0,
            notchMargin: 8,
            shape: const CircularNotchedRectangle(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Left items
                  _NavItem(
                    index: 0, currentIndex: _currentIndex,
                    icon: Icons.check_circle_outline_rounded,
                    activeIcon: Icons.check_circle_rounded,
                    label: 'My Tasks',
                    onTap: () => setState(() => _currentIndex = 0),
                  ),
                  _NavItem(
                    index: 1, currentIndex: _currentIndex,
                    icon: Icons.work_outline_rounded,
                    activeIcon: Icons.work_rounded,
                    label: 'Job Market',
                    onTap: () => setState(() => _currentIndex = 1),
                  ),

                  // Center spacer for FAB notch
                  const SizedBox(width: 56),

                  // Right items
                  _NavItem(
                    index: 2, currentIndex: _currentIndex,
                    icon: Icons.precision_manufacturing_outlined,
                    activeIcon: Icons.precision_manufacturing_rounded,
                    label: 'Machines',
                    onTap: () => setState(() => _currentIndex = 2),
                  ),
                  _NavItem(
                    index: 3, currentIndex: _currentIndex,
                    icon: Icons.person_outline_rounded,
                    activeIcon: Icons.person_rounded,
                    label: 'Profile',
                    onTap: () => _showProfileSheet(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showProfileSheet() {
    HapticFeedback.lightImpact();
    final name = AuthService.instance.displayName;
    final email = AuthService.instance.currentUser?.email ?? '';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetHandle(),
            const SizedBox(height: 24),
            CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.primary.withOpacity(0.12),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'W',
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(name,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text(email,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 32),
            const Divider(color: AppColors.divider),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton.icon(
                onPressed: _signOut,
                icon: const Icon(Icons.logout_rounded,
                    color: AppColors.offline),
                label: const Text('Sign Out',
                    style: TextStyle(
                        color: AppColors.offline, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.offline, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Nav item helper
// ─────────────────────────────────────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  final int index;
  final int currentIndex;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final VoidCallback onTap;

  const _NavItem({
    required this.index,
    required this.currentIndex,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == currentIndex;
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? AppColors.primary : AppColors.textDisabled,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? AppColors.primary : AppColors.textDisabled,
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QR Scanner Sheet — Feature B
// ─────────────────────────────────────────────────────────────────────────────
class _QrScanSheet extends StatefulWidget {
  final ValueChanged<String> onMachineIdScanned;
  const _QrScanSheet({required this.onMachineIdScanned});

  @override
  State<_QrScanSheet> createState() => _QrScanSheetState();
}

class _QrScanSheetState extends State<_QrScanSheet> {
  bool _scanned = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: MobileScanner(
              onDetect: (capture) {
                if (_scanned) return;
                final barcode = capture.barcodes.firstOrNull;
                if (barcode?.rawValue != null) {
                  setState(() => _scanned = true);
                  HapticFeedback.mediumImpact();
                  Navigator.of(context).pop();
                  widget.onMachineIdScanned(barcode!.rawValue!);
                }
              },
            ),
          ),
          // Overlay UI
          Positioned.fill(
            child: Column(
              children: [
                const SheetHandle(),
                const SizedBox(height: 16),
                const Text(
                  'Scan Machine QR Code',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                // Scan frame overlay
                Center(
                  child: Container(
                    width: 220, height: 220,
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: AppColors.primary, width: 3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel',
                        style: TextStyle(
                            color: Colors.white60,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Helper extension for safe firstOrNull
extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}

