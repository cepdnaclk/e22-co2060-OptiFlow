import 'dart:async';
import 'package:flutter/material.dart';
import 'package:optiflow_scheduler/slices/engine/dashboard/widgets/activity_section.dart';
import 'package:optiflow_scheduler/core/services/supabase_service.dart';
import 'package:optiflow_scheduler/slices/engine/dashboard/widgets/op_type_chart.dart';
import 'package:optiflow_scheduler/slices/engine/dashboard/widgets/sidebar.dart';
import 'package:optiflow_scheduler/slices/engine/dashboard/widgets/stat_card.dart';
import 'package:optiflow_scheduler/slices/engine/dashboard/widgets/utilization_chart.dart';
import 'package:optiflow_scheduler/slices/admin/machines_screen.dart';
import 'package:optiflow_scheduler/slices/engine/schedule_screen.dart';
import 'package:optiflow_scheduler/slices/engine/jobs_screen.dart';
import 'package:optiflow_scheduler/core/utils/app_colors.dart';
import 'package:optiflow_scheduler/slices/admin/team_screen.dart';
import 'package:optiflow_scheduler/slices/engine/analytics_screen.dart';
import 'package:optiflow_scheduler/slices/admin/settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;

  // Stats
  int    _totalJobs       = 0;
  int    _totalTasks      = 0;
  int    _pendingTasks    = 0;
  double _machineUptime   = 0;
  int    _activeMachines  = 0;
  int    _idleMachines    = 0;
  int    _offlineMachines = 0;
  Map<String, int> _tasksByOpType = {};
  bool   _isLoading = true;

  // Live clock
  late Timer _clockTimer;
  DateTime _now = DateTime.now();



  @override
  void initState() {
    super.initState();
    _fetchDashboardData();

    _clockTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) { if (mounted) setState(() => _now = DateTime.now()); },
    );
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  Future<void> _fetchDashboardData() async {
    final stats = await SupabaseService.instance.fetchDashboardStats();
    if (mounted) {
      setState(() {
        _totalJobs       = stats['total_jobs']       as int? ?? 0;
        _totalTasks      = stats['total_tasks']      as int? ?? 0;
        _pendingTasks    = stats['pending_tasks']    as int? ?? 0;
        _machineUptime   = (stats['uptime_pct'] as num?)?.toDouble() ?? 0.0;
        _activeMachines  = stats['active_machines']  as int? ?? 0;
        _idleMachines    = stats['idle_machines']    as int? ?? 0;
        _offlineMachines = (stats['offline_machines'] as List?)?.length ?? 0;
        _tasksByOpType   = Map<String, int>.from(stats['tasks_by_op_type'] ?? {});
        _isLoading       = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Sidebar(
            selectedIndex: _selectedIndex,
            onItemSelected: (i) => setState(() => _selectedIndex = i),
          ),
          Expanded(child: _buildCurrentPage()),
        ],
      ),
    );
  }

  Widget _buildCurrentPage() {
    switch (_selectedIndex) {
      case 0: return _buildCommandCenter();
      case 1: return const MachinesScreen();
      case 2: return const ScheduleScreen();
      case 3: return const JobsScreen();
      case 4: return const TeamScreen();
      case 5: return const AnalyticsScreen();
      case 6: return const SettingsScreen();
      default: return _buildCommandCenter();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // COMMAND CENTER MAIN CONTENT
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildCommandCenter() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
            SizedBox(height: 16),
            Text('Initialising Command Center…',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildTopBar(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                _buildMachineStatusStrip(),
                const SizedBox(height: 24),
                _buildStatsRow(),
                const SizedBox(height: 24),
                _buildChartsRow(),
                const SizedBox(height: 24),
                _buildBottomRow(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Top Bar ──────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    final timeStr = _formatTime(_now);
    final dateStr = _formatDate(_now);

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        children: [
          // Page title
          const Text(
            'Command Center',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.matteBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
              border:
                  Border.all(color: AppColors.matteBlue.withOpacity(0.3)),
            ),
            child: const Text(
              'LIVE',
              style: TextStyle(
                color: AppColors.matteBlue,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const Spacer(),
          // Refresh
          IconButton(
            onPressed: () {
              setState(() => _isLoading = true);
              SupabaseService.instance.invalidateCache();
              _fetchDashboardData();
            },
            icon: const Icon(Icons.refresh_rounded,
                color: AppColors.textSecondary, size: 18),
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 8),
          // Clock
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                timeStr,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  fontFamily: 'monospace',
                  letterSpacing: 1,
                ),
              ),
              Text(
                dateStr,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Machine Status Strip ─────────────────────────────────────────────────

  Widget _buildMachineStatusStrip() {
    final metrics = [
      (_activeMachines,  'ACTIVE',   AppColors.matteGreen),
      (_idleMachines,    'IDLE',     AppColors.matteAmber),
      (_offlineMachines, 'OFFLINE',  AppColors.matteRed),
    ];

    return Row(
      children: metrics.map((m) {
        final count = m.$1;
        final label = m.$2;
        final color = m.$3;
        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: _MachineStatusPill(count: count, label: label, color: color),
        );
      }).toList(),
    );
  }

  // ── Stats Row ────────────────────────────────────────────────────────────

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: StatCard(
            title: 'Total Jobs',
            value: '$_totalJobs',
            icon: Icons.inventory_2_rounded,
            iconColor: AppColors.secondary,
            percentage: 0,
            comparisonText: 'in system',
            isIncreasePositive: true,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: StatCard(
            title: 'Pending Tasks',
            value: '$_pendingTasks',
            icon: Icons.hourglass_top_rounded,
            iconColor: AppColors.matteAmber,
            percentage: 0,
            comparisonText: 'awaiting scheduling',
            isIncreasePositive: false,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: StatCard(
            title: 'Machine Uptime',
            value: '${_machineUptime.toStringAsFixed(0)}%',
            icon: Icons.precision_manufacturing_rounded,
            iconColor: AppColors.matteBlue,
            percentage: 0,
            comparisonText: 'fleet active',
            isIncreasePositive: true,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: StatCard(
            title: 'Total Tasks',
            value: '$_totalTasks',
            icon: Icons.account_tree_rounded,
            iconColor: AppColors.matteGreen,
            percentage: 0,
            comparisonText: 'across all jobs',
            isIncreasePositive: true,
          ),
        ),
      ],
    );
  }

  // ── Charts Row ───────────────────────────────────────────────────────────

  Widget _buildChartsRow() {
    return SizedBox(
      height: 340,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: OpTypeChart(tasksByOpType: _tasksByOpType),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: UtilizationChart(
              activeMachines:  _activeMachines,
              idleMachines:    _idleMachines,
              offlineMachines: _offlineMachines,
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom Row ───────────────────────────────────────────────────────────

  Widget _buildBottomRow() {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          Expanded(flex: 1, child: LiveAlerts()),
          SizedBox(width: 16),
          Expanded(flex: 2, child: RecentActivity()),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    final wd = days[dt.weekday - 1];
    return '$wd ${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Machine Status Pill — top strip showing live counts with neon glow
// ─────────────────────────────────────────────────────────────────────────────
class _MachineStatusPill extends StatelessWidget {
  final int count;
  final String label;
  final Color color;

  const _MachineStatusPill({
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Solid dot
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${count}',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
