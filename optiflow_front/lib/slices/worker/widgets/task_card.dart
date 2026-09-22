import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task_model.dart';
import 'task_bottom_sheet.dart';

class TaskCard extends StatelessWidget {
  final WorkerTask task;
  final VoidCallback onTaskUpdated;

  const TaskCard({super.key, required this.task, required this.onTaskUpdated});

  String _formatTime(DateTime? dt) {
    if (dt == null) return 'Not Scheduled';
    return DateFormat('MMM d, h:mm a').format(dt);
  }

  Color _getStatusColor() {
    switch (task.status) {
      case 'SCHEDULED':
        return const Color(0xFFF5A623); // Warning/Orange
      case 'IN_PROGRESS':
        return const Color(0xFF4A90E2); // Blue
      case 'COMPLETED':
        return const Color(0xFF7ED321); // Green
      default:
        return Colors.grey;
    }
  }

  void _showBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          TaskBottomSheet(task: task, onTaskUpdated: onTaskUpdated),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();
    final isHorizontal = task.status == 'IN_PROGRESS';

    return GestureDetector(
      onTap: () => _showBottomSheet(context),
      child: Container(
        width: isHorizontal ? 280 : double.infinity,
        margin: EdgeInsets.only(
          bottom: isHorizontal ? 0 : 16,
          right: isHorizontal ? 16 : 0,
        ),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    task.status.replaceAll('_', ' '),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Icon(Icons.more_horiz, color: Colors.grey[400]),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              task.jobTitle,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF2B2B2B),
                letterSpacing: -0.5,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.precision_manufacturing_outlined,
                  size: 16,
                  color: Colors.grey[500],
                ),
                const SizedBox(width: 8),
                Text(
                  task.operationTypeId,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFFF0F0F0), height: 1),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 16,
                  color: Colors.grey[500],
                ),
                const SizedBox(width: 8),
                Text(
                  _formatTime(task.scheduledStartTime),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
