import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../models/task_model.dart';

/// Airbnb-style task card used in both the carousel (IN_PROGRESS) 
/// and the vertical list (SCHEDULED).
class TaskCard extends StatelessWidget {
  final TaskModel task;
  final VoidCallback onTap;
  final bool isCarousel; // Carousel cards have a fixed width

  const TaskCard({
    super.key,
    required this.task,
    required this.onTap,
    this.isCarousel = false,
  });

  Color get _accentColor {
    switch (task.status) {
      case 'IN_PROGRESS': return AppColors.inProgress;
      case 'SCHEDULED':   return AppColors.scheduled;
      case 'COMPLETED':   return AppColors.completed;
      default:            return AppColors.textDisabled;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: isCarousel ? 260 : double.infinity,
        margin: EdgeInsets.only(
          right: isCarousel ? 16 : 0,
          bottom: isCarousel ? 0 : 16,
        ),
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Status badge + time ──────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                StatusBadge(status: task.status),
                Text(
                  task.formattedTime,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Job title ────────────────────────────────────────────────────
            Text(
              task.jobTitle,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),

            // ── Operation type ───────────────────────────────────────────────
            Text(
              task.operationTypeId,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 16),
            const Divider(color: AppColors.divider, height: 1),
            const SizedBox(height: 16),

            // ── Quantity + resource ──────────────────────────────────────────
            Row(
              children: [
                _chip(
                  icon: Icons.inventory_2_outlined,
                  label: '${task.quantityToProcess} units',
                ),
                const SizedBox(width: 8),
                _chip(
                  icon: Icons.precision_manufacturing_outlined,
                  label: task.resourceName,
                ),
              ],
            ),

            // ── Subtle progress bar for in-progress tasks ────────────────────
            if (task.status == 'IN_PROGRESS') ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: null, // indeterminate while "active"
                  backgroundColor: _accentColor.withOpacity(0.15),
                  color: _accentColor,
                  minHeight: 4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip({required IconData icon, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textDisabled),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
