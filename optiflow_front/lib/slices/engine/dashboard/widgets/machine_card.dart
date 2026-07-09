import 'package:flutter/material.dart';
import 'package:optiflow_scheduler/core/models/machine.dart';
import 'package:optiflow_scheduler/core/utils/app_colors.dart';

class MachineCard extends StatelessWidget {
  final Machine machine;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const MachineCard({super.key, required this.machine, this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLight.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopRow(),
          const SizedBox(height: 20),
          _buildStatusBadge(), // status badge in its own row
          const SizedBox(height: 20),
          _buildSpecsGrid(),
          const SizedBox(height: 20),
          Divider(height: 1, color: AppColors.surfaceLight.withOpacity(0.5)),
          const SizedBox(height: 16),
          _buildFooterStats(),
        ],
      ),
    );
  }

  Widget _buildTopRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _getStatusColor(machine.status).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.print, color: _getStatusColor(machine.status), size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                machine.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                machine.type,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        // 3-dot menu
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: AppColors.textSecondary, size: 20),
          color: AppColors.surfaceLight,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: (val) {
            if (val == 'edit') onEdit?.call();
            if (val == 'delete') onDelete?.call();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Row(children: [
              Icon(Icons.edit_rounded, size: 16, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Edit Machine', style: TextStyle(color: AppColors.textPrimary)),
            ])),
            const PopupMenuItem(value: 'delete', child: Row(children: [
              Icon(Icons.delete_outline, size: 16, color: AppColors.error),
              SizedBox(width: 8),
              Text('Remove', style: TextStyle(color: AppColors.error)),
            ])),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusBadge() {
    Color color;
    String label;
    IconData icon;

    switch (machine.status) {
      case 'ACTIVE':
        color = AppColors.success;
        label = 'Active';
        icon = Icons.play_circle_fill;
        break;
      case 'IDLE':
        color = AppColors.warning;
        label = 'Idle';
        icon = Icons.pause_circle_filled;
        break;
      case 'MAINTENANCE':
        color = AppColors.info;
        label = 'Maintenance';
        icon = Icons.build_circle;
        break;
      case 'OFFLINE':
        color = AppColors.error;
        label = 'Offline';
        icon = Icons.cancel;
        break;
      default:
        color = AppColors.textSecondary;
        label = machine.status;
        icon = Icons.circle;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }



  Widget _buildSpecsGrid() {
    // Show real data: machine type and a note about capabilities
    return Row(
      children: [
        _buildSpecItem('Type', machine.type.isEmpty ? 'Machine' : machine.type),
        const SizedBox(width: 16),
        _buildSpecItem('Utilization', '${machine.utilization}%'),
      ],
    );
  }

  Widget _buildSpecItem(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildFooterStats() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildStat("Utilization", "${machine.utilization}%"),
        _buildStat("Completed Jobs", "${machine.completedJobs}"),
      ],
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case "ACTIVE":
        return const Color(0xFFD946EF); // Pink
      case "MAINTENANCE":
        return AppColors.warning;
      case "BROKEN":
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }
}
