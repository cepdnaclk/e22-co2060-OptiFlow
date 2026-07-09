import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:optiflow_scheduler/core/utils/app_colors.dart';
import 'package:optiflow_scheduler/slices/engine/dashboard/widgets/stat_card.dart';
import 'package:optiflow_scheduler/core/services/api_service.dart';
import 'package:optiflow_scheduler/core/models/machine.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  int _totalJobs = 0;
  String _selectedFilter = 'Last 30 Days';
  
  // Job Status Counts
  int _completedJobs = 0;
  int _inProgressJobs = 0;
  int _pendingJobs = 0;
  int _failedJobs = 0;
  
  double _oeeScore = 0.0;
  double _defectRate = 0.0;
  double _leadTime = 0.0;
  List<Machine> _machines = [];

  int get _filterDays {
    switch (_selectedFilter) {
      case 'Last 7 Days': return 7;
      case 'This Year': return 365;
      default: return 30;
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchAnalyticsData();
  }

  Future<void> _fetchAnalyticsData() async {
    setState(() { _isLoading = true; });
    try {
      final jobs = await _apiService.fetchJobsFiltered(_filterDays);
      
      int completed = 0;
      int inProgress = 0;
      int pending = 0;
      int failed = 0;

      for (var job in jobs) {
        if (job.status == 'COMPLETED') {
          completed++;
        } else if (job.status == 'IN_PROGRESS' || job.status == 'TAKEN') {
          inProgress++;
        } else if (job.status == 'DRAFT' || job.status == 'OPEN' || job.status == 'REVIEW') {
          pending++;
        } else {
          failed++;
        }
      }
      
      final machinesList = await _apiService.fetchMachines();

      if (mounted) {
        setState(() {
          _totalJobs = jobs.length;
          _completedJobs = completed;
          _inProgressJobs = inProgress;
          _pendingJobs = pending;
          _failedJobs = failed;
          
          if (_totalJobs > 0) {
            _oeeScore = (completed / _totalJobs) * 100;
            _defectRate = (failed / _totalJobs) * 100;
            _leadTime = _totalJobs < 5 ? 2.4 : 1.8; // Estimated lead time logic
          } else {
            _oeeScore = 0;
            _defectRate = 0;
            _leadTime = 0;
          }
          
          _machines = machinesList;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching analytics data: \$e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 32),
          _buildSummaryStats(),
          const SizedBox(height: 32),
          _buildChartsRow(),
          const SizedBox(height: 32),
          _buildDetailedMetrics(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Analytics & Reports",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "Deep dive into shop performance and historical data.",
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.textSecondary.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(12),
            color: AppColors.surfaceLight.withOpacity(0.3),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedFilter,
              dropdownColor: AppColors.surface,
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
              items: <String>['Last 7 Days', 'Last 30 Days', 'This Year']
                  .map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null && val != _selectedFilter) {
                  setState(() { _selectedFilter = val; });
                  _fetchAnalyticsData();
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryStats() {
    return Row(
      children: [
        Expanded(
          child: StatCard(
            title: "Total Orders Processed",
            value: "$_totalJobs",
            icon: Icons.assignment_turned_in,
            iconColor: Colors.blue,
            percentage: 12.5,
            comparisonText: "vs last month",
            isIncreasePositive: true,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: StatCard(
            title: "Average Lead Time",
            value: "${_leadTime.toStringAsFixed(1)} Days",
            icon: Icons.timelapse,
            iconColor: Colors.orange,
            percentage: -5.2,
            comparisonText: "vs last month",
            isIncreasePositive: true, // Decreased lead time is good
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: StatCard(
            title: "Defect Rate",
            value: "${_defectRate.toStringAsFixed(1)}%",
            icon: Icons.bug_report,
            iconColor: Colors.red,
            percentage: -0.1,
            comparisonText: "vs last month",
            isIncreasePositive: true, // Decreased defect rate is good
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: StatCard(
            title: "OEE Score",
            value: "${_oeeScore.toStringAsFixed(0)}%",
            icon: Icons.speed,
            iconColor: Colors.green,
            percentage: 4.3,
            comparisonText: "vs last month",
            isIncreasePositive: true,
          ),
        ),
      ],
    );
  }

  Widget _buildChartsRow() {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 2, child: _buildEfficiencyChart()),
          const SizedBox(width: 16),
          Expanded(flex: 1, child: _buildJobStatusDistribution()),
        ],
      ),
    );
  }

  Widget _buildEfficiencyChart() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLight.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Overall Equipment Effectiveness (OEE) Trend",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          AspectRatio(
            aspectRatio: 2.0,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: AppColors.textSecondary.withOpacity(0.1),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const style = TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        );
                        String text;
                        switch (value.toInt()) {
                          case 1:
                            text = 'Week 1';
                            break;
                          case 2:
                            text = 'Week 2';
                            break;
                          case 3:
                            text = 'Week 3';
                            break;
                          case 4:
                            text = 'Week 4';
                            break;
                          default:
                            return Container();
                        }
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          space: 8,
                          child: Text(text, style: style),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          "${value.toInt()}%",
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 1,
                maxX: 4,
                minY: 50,
                maxY: 100,
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(1, 75),
                      FlSpot(2, 82),
                      FlSpot(3, 78),
                      FlSpot(4, 88),
                    ],
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primary.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobStatusDistribution() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLight.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Job Status Distribution",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 60,
                    sections: _totalJobs == 0 
                      ? [
                          PieChartSectionData(
                            color: AppColors.textSecondary.withOpacity(0.2),
                            value: 100,
                            title: '0%',
                            radius: 30,
                            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                          )
                        ]
                      : [
                      if (_completedJobs > 0)
                        PieChartSectionData(
                          color: AppColors.success,
                          value: _completedJobs.toDouble(),
                          title: '${((_completedJobs / _totalJobs) * 100).toStringAsFixed(0)}%',
                          radius: 30,
                          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      if (_inProgressJobs > 0)
                        PieChartSectionData(
                          color: AppColors.warning,
                          value: _inProgressJobs.toDouble(),
                          title: '${((_inProgressJobs / _totalJobs) * 100).toStringAsFixed(0)}%',
                          radius: 30,
                          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      if (_pendingJobs > 0)
                        PieChartSectionData(
                          color: AppColors.primary,
                          value: _pendingJobs.toDouble(),
                          title: '${((_pendingJobs / _totalJobs) * 100).toStringAsFixed(0)}%',
                          radius: 30,
                          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      if (_failedJobs > 0)
                        PieChartSectionData(
                          color: AppColors.error,
                          value: _failedJobs.toDouble(),
                          title: '${((_failedJobs / _totalJobs) * 100).toStringAsFixed(0)}%',
                          radius: 30,
                          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                    ],
                  ),
                ),
                Text(
                  "$_totalJobs\nJobs",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLegendItem("Completed", AppColors.success),
              _buildLegendItem("In Progress", AppColors.warning),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLegendItem("Pending", AppColors.primary),
              _buildLegendItem("Failed", AppColors.error),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedMetrics() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLight.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Machine Performance Breakdown",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          DataTable(
            columns: const [
              DataColumn(label: Text("Machine Name", style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text("Uptime", style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text("Output Volume", style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text("Efficiency", style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text("Status", style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: _machines.isEmpty 
              ? [
                  const DataRow(cells: [
                    DataCell(Text("No Machines Found")),
                    DataCell(Text("-")),
                    DataCell(Text("-")),
                    DataCell(Text("-")),
                    DataCell(Text("-")),
                  ])
                ]
              : _machines.map((m) {
                  final uptime = m.status == "ACTIVE" ? "98.5%" : m.status == "IDLE" ? "85.2%" : "60.0%";
                  final output = m.status == "ACTIVE" ? "4,520 units" : m.status == "IDLE" ? "1,200 units" : "450 units";
                  final efficiency = m.status == "ACTIVE" ? "92%" : m.status == "IDLE" ? "78%" : "55%";
                  final statusText = m.status == "ACTIVE" ? "Optimal" : m.status == "IDLE" ? "Needs Maint." : "Under Repair";
                  final color = m.status == "ACTIVE" ? AppColors.success : m.status == "IDLE" ? AppColors.warning : AppColors.error;
                  return _buildDataRow(m.name, uptime, output, efficiency, statusText, color);
                }).toList(),
          ),
        ],
      ),
    );
  }

  DataRow _buildDataRow(String name, String uptime, String output, String efficiency, String status, Color statusColor) {
    return DataRow(
      cells: [
        DataCell(Text(name, style: const TextStyle(fontWeight: FontWeight.w600))),
        DataCell(Text(uptime)),
        DataCell(Text(output)),
        DataCell(Text(efficiency)),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              status,
              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }
}
