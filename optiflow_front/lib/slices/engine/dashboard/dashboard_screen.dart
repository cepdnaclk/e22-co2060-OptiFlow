import 'package:flutter/material.dart';
import 'package:optiflow_scheduler/slices/engine/dashboard/widgets/activity_section.dart';
import 'package:optiflow_scheduler/core/services/api_service.dart';
import 'package:optiflow_scheduler/slices/engine/dashboard/widgets/revenue_chart.dart';
import 'package:optiflow_scheduler/slices/engine/dashboard/widgets/sidebar.dart';
import 'package:optiflow_scheduler/slices/engine/dashboard/widgets/stat_card.dart';
import 'package:optiflow_scheduler/slices/engine/dashboard/widgets/utilization_chart.dart';
import 'package:optiflow_scheduler/slices/admin/machines_screen.dart';
import 'package:optiflow_scheduler/slices/engine/schedule_screen.dart';
import 'package:optiflow_scheduler/slices/order/placeholder_screen.dart';
import 'package:optiflow_scheduler/slices/engine/jobs_screen.dart';
import 'package:optiflow_scheduler/core/utils/app_colors.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  final ApiService _apiService = ApiService();
  double _totalRevenue = 0;
  int _activeJobsCount = 0;
  double _machineUptime = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    try {
      final jobs = await _apiService.fetchJobs();
      final machines = await _apiService.fetchMachines();

      double revenue = 0;
      int activeJobs = 0;
      for (var job in jobs) {
        revenue += job.price;
        if (job.status == "OPEN" || job.status == "IN_PROGRESS") {
          activeJobs++;
        }
      }

      int activeMachines = machines.where((m) => m.status == "ACTIVE").length;
      double uptime = machines.isEmpty
          ? 0
          : (activeMachines / machines.length) * 100;

      if (mounted) {
        setState(() {
          _totalRevenue = revenue;
          _activeJobsCount = activeJobs;
          _machineUptime = uptime;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching dashboard data: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sidebar
          Sidebar(
            selectedIndex: _selectedIndex,
            onItemSelected: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
          ),
          // Main Content
          Expanded(child: _buildCurrentPage()),
        ],
      ),
    );
  }

  Widget _buildCurrentPage() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardContent();
      case 1:
        return const MachinesScreen();
      case 2:
        return const ScheduleScreen();
      case 3:
        return const JobsScreen();
      case 4:
        return const PlaceholderScreen(
          title: "Team",
          icon: Icons.people_outline,
        );
      case 5:
        return const PlaceholderScreen(
          title: "Analytics",
          icon: Icons.analytics_outlined,
        );
      case 6:
        return const PlaceholderScreen(
          title: "Settings",
          icon: Icons.settings_outlined,
        );
      default:
        return _buildDashboardContent();
    }
  }

  Widget _buildDashboardContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 32),
          _buildStatsRow(),
          const SizedBox(height: 32),
          _buildChartsRow(),
          const SizedBox(height: 32),
          _buildBottomRow(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Dashboard",
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 8),
        Text(
          "Welcome back, John. Here's your shop overview for today.",
          style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: StatCard(
            title: "Today's Revenue",
            value: "\$${_totalRevenue.toStringAsFixed(0)}",
            icon: Icons.attach_money,
            iconColor: Colors.purple,
            percentage: 12.5,
            comparisonText: "vs yesterday",
            isIncreasePositive: true,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: StatCard(
            title: "Active Jobs",
            value: "$_activeJobsCount",
            icon: Icons.inventory_2_outlined,
            iconColor: Colors.blue,
            percentage: 8.2,
            comparisonText: "from last week",
            isIncreasePositive: true,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: StatCard(
            title: "Machine Uptime",
            value: "${_machineUptime.toStringAsFixed(1)}%",
            icon: Icons.print_outlined,
            iconColor: Colors.green,
            percentage: -2.1,
            comparisonText: "vs last week",
            isIncreasePositive: false,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: StatCard(
            title: "Avg Completion",
            value: "4.2h",
            icon: Icons.timer_outlined,
            iconColor: Colors.orange,
            percentage: 15,
            comparisonText: "faster",
            isIncreasePositive: true,
          ),
        ),
      ],
    );
  }

  Widget _buildChartsRow() {
    return const IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 2, child: RevenueChart()),
          SizedBox(width: 16),
          Expanded(flex: 1, child: UtilizationChart()),
        ],
      ),
    );
  }

  Widget _buildBottomRow() {
    return const IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 1, child: LiveAlerts()),
          SizedBox(width: 16),
          Expanded(flex: 2, child: RecentActivity()),
        ],
      ),
    );
  }
}
