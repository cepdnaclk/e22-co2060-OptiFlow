import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:optiflow_scheduler/core/utils/app_colors.dart';

class UtilizationChart extends StatelessWidget {
  final int activeMachines;
  final int idleMachines;
  final int offlineMachines;

  const UtilizationChart({
    super.key,
    required this.activeMachines,
    required this.idleMachines,
    required this.offlineMachines,
  });

  @override
  Widget build(BuildContext context) {
    final int totalMachines = activeMachines + idleMachines + offlineMachines;
    final double activePercentage = totalMachines == 0 ? 0 : (activeMachines / totalMachines) * 100;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Machine Utilization",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Stack(
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 0,
                    centerSpaceRadius: 70,
                    startDegreeOffset: -90,
                    sections: totalMachines == 0 
                      ? [
                          PieChartSectionData(
                            color: AppColors.textSecondary.withOpacity(0.2),
                            value: 100,
                            title: '',
                            radius: 20,
                            showTitle: false,
                          )
                        ]
                      : [
                      if (activeMachines > 0)
                        PieChartSectionData(
                          color: const Color(0xFFD946EF), // Pink
                          value: activeMachines.toDouble(),
                          title: '',
                          radius: 20,
                          showTitle: false,
                        ),
                      if (idleMachines > 0)
                        PieChartSectionData(
                          color: AppColors.warning,
                          value: idleMachines.toDouble(),
                          title: '',
                          radius: 20,
                          showTitle: false,
                        ),
                      if (offlineMachines > 0)
                        PieChartSectionData(
                          color: AppColors.error,
                          value: offlineMachines.toDouble(),
                          title: '',
                          radius: 20,
                          showTitle: false,
                        ),
                    ],
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "${activePercentage.toStringAsFixed(0)}%",
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Text(
                        "Active",
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildLegendItem("Active Machines", "$activeMachines of $totalMachines", AppColors.textPrimary),
          const SizedBox(height: 8),
          _buildLegendItem("Idle", "$idleMachines", AppColors.warning),
          const SizedBox(height: 8),
          _buildLegendItem("Offline", "$offlineMachines", AppColors.error),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
