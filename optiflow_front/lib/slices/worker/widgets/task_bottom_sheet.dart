import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/task_model.dart';
import '../api/mobile_api_service.dart';

class TaskBottomSheet extends StatefulWidget {
  final WorkerTask task;
  final VoidCallback onTaskUpdated;

  const TaskBottomSheet({
    super.key,
    required this.task,
    required this.onTaskUpdated,
  });

  @override
  State<TaskBottomSheet> createState() => _TaskBottomSheetState();
}

class _TaskBottomSheetState extends State<TaskBottomSheet> {
  bool _isLoading = false;
  final MobileApiService _apiService = MobileApiService();

  String _formatTime(DateTime? dt) {
    if (dt == null) return 'Not Scheduled';
    return DateFormat('MMM d, yyyy - h:mm a').format(dt);
  }

  Future<void> _updateStatus(String newStatus) async {
    HapticFeedback.lightImpact();
    setState(() => _isLoading = true);
    try {
      await _apiService.updateTaskStatus(widget.task.id, newStatus);
      if (mounted) {
        widget.onTaskUpdated();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Task marked as $newStatus'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF2B2B2B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildActionButton() {
    if (widget.task.status == 'SCHEDULED') {
      return SizedBox(
        width: double.infinity,
        height: 64,
        child: ElevatedButton(
          onPressed: _isLoading ? null : () => _updateStatus('IN_PROGRESS'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2B2B2B), // Premium Black
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(32),
            ),
            elevation: 0,
          ),
          child: _isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text(
                  'Start Task',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
        ),
      );
    } else if (widget.task.status == 'IN_PROGRESS') {
      return SizedBox(
        width: double.infinity,
        height: 64,
        child: ElevatedButton(
          onPressed: _isLoading ? null : () => _updateStatus('COMPLETED'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(
              0xFF4A90E2,
            ), // Airbnbish Blue/Action Color
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(32),
            ),
            elevation: 0,
          ),
          child: _isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text(
                  'Complete Task',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
        ),
      );
    } else {
      return Container(
        width: double.infinity,
        height: 64,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(32),
        ),
        alignment: Alignment.center,
        child: const Text(
          'Completed',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.all(24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              '${widget.task.quantityToProcess} Units',
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
                color: Color(0xFF2B2B2B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.task.jobTitle,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 32),
            _buildDetailRow(
              Icons.precision_manufacturing_outlined,
              'Operation',
              widget.task.operationTypeId,
            ),
            const SizedBox(height: 20),
            _buildDetailRow(
              Icons.access_time_rounded,
              'Scheduled',
              _formatTime(widget.task.scheduledStartTime),
            ),
            const SizedBox(height: 20),
            _buildDetailRow(
              Icons.precision_manufacturing_rounded,
              'Resource',
              widget.task.resourceName,
            ),
            const SizedBox(height: 40),
            _buildActionButton(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: Colors.grey[800], size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF2B2B2B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
