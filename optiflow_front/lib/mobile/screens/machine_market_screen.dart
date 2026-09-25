import 'package:flutter/material.dart';
import 'package:optiflow_scheduler/core/services/supabase_service.dart';
import '../core/app_theme.dart';
import '../models/machine_model.dart';
import '../widgets/machine_card.dart';
import '../widgets/shimmer_card.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MachineMarketScreen — visual grid of all factory machines.
/// Tapping a card opens the booking sheet.
/// ─────────────────────────────────────────────────────────────────────────────
class MachineMarketScreen extends StatefulWidget {
  const MachineMarketScreen({super.key});

  @override
  State<MachineMarketScreen> createState() => MachineMarketScreenState();
}

class MachineMarketScreenState extends State<MachineMarketScreen> {
  List<MachineModel> _machines = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMachines();
  }

  Future<void> _loadMachines() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      // Fetch machines directly from Supabase — no FastAPI needed.
      final raw = await SupabaseService.instance.fetchMachines();
      final machines = raw.map(MachineModel.fromJson).toList();
      if (mounted) setState(() { _machines = machines; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  /// Called from QR scan flow — opens the booking sheet for a specific machine ID.
  Future<void> openBookingSheetForId(String machineId) async {
    final machine = _machines.firstWhere(
      (m) => m.id == machineId,
      orElse: () => MachineModel(
        id: machineId, name: 'Scanned Machine', status: 'Unknown'),
    );
    _openBookingSheet(machine);
  }

  void _openBookingSheet(MachineModel machine) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MachineBookingSheet(
        machine: machine,
        onBookingDone: _loadMachines,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _loadMachines,
        color: AppColors.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── AppBar ───────────────────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 110,
              pinned: true,
              backgroundColor: AppColors.background,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 24, bottom: 16),
                expandedTitleScale: 1.3,
                title: const Text(
                  'Machine Shop',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ),

            // ── Subtitle ─────────────────────────────────────────────────────
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: Text(
                  'Reserve a machine slot for your next run.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            // ── Loading ──────────────────────────────────────────────────────
            if (_loading) const ShimmerGrid()

            // ── Error ────────────────────────────────────────────────────────
            else if (_error != null)
              SliverFillRemaining(child: _errorState())

            // ── Grid ─────────────────────────────────────────────────────────
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.82,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => MachineCard(
                      machine: _machines[i],
                      onTap: () => _openBookingSheet(_machines[i]),
                    ),
                    childCount: _machines.length,
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _errorState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_rounded,
              size: 60, color: AppColors.textDisabled),
          const SizedBox(height: 20),
          const Text('Unable to load machines',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text(_error!.replaceFirst('Exception: ', ''),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textSecondary, height: 1.5)),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: _loadMachines,
            style: AppTheme.pillButtonStyle(),
            child: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}
