import 'package:flutter/material.dart';
import 'package:optiflow_scheduler/screens/dashboard/widgets/new_job_order.dart';
import 'package:optiflow_scheduler/utils/app_colors.dart';

class JobsScreen extends StatelessWidget {
  const JobsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 32),
          Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: const NewJobOrder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Jobs",
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 8),
        Text(
          "Manage and create new job orders",
          style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
