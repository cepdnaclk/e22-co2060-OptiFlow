import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'theme.dart';

class WorkerDashboardScreen extends StatefulWidget {
  final String workerId;
  
  // Replace with actual worker ID lookup logic once auth is implemented
  const WorkerDashboardScreen({super.key, this.workerId = 'worker_123'});

  @override
  State<WorkerDashboardScreen> createState() => _WorkerDashboardScreenState();
}

class _WorkerDashboardScreenState extends State<WorkerDashboardScreen> {
  List<dynamic> tasks = [];
  bool isLoading = true;
  String? errorMessage;

  // Use 10.0.2.2 for Android Emulator to connect to localhost:8000
  final String baseUrl = 'https://e22-co2060-optiflow.onrender.com/api';

  @override
  void initState() {
    super.initState();
    fetchTasks();
  }

  Future<void> fetchTasks() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await http.get(Uri.parse('$baseUrl/tasks?resource_id=${widget.workerId}'));
      
      if (response.statusCode == 200) {
        setState(() {
          tasks = json.decode(response.body);
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Failed to load tasks. Status: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error connecting to server. Is the Python backend running?\nDetails: $e';
        isLoading = false;
      });
    }
  }

  Future<void> updateTaskStatus(String taskId, String newStatus) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/tasks/$taskId/status'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'status': newStatus}),
      );

      if (response.statusCode == 200) {
        // Refresh the task list immediately after a successful update
        fetchTasks();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Task marked as $newStatus'),
              backgroundColor: MobileTheme.emeraldGreen,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update status: ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MobileTheme.bgColor,
      appBar: AppBar(
        backgroundColor: MobileTheme.surfaceColor,
        elevation: 0,
        title: const Text(
          'My Tasks', 
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: MobileTheme.neonBlue),
            onPressed: fetchTasks,
          )
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: MobileTheme.neonBlue));
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
               Icon(Icons.wifi_off_rounded, color: Colors.white.withOpacity(0.5), size: 64),
              const SizedBox(height: 16),
              Text(
                errorMessage!, 
                style: const TextStyle(color: Colors.white70), 
                textAlign: TextAlign.center
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: fetchTasks,
                style: ElevatedButton.styleFrom(
                  backgroundColor: MobileTheme.surfaceColor,
                  side: const BorderSide(color: MobileTheme.neonBlue),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                icon: const Icon(Icons.refresh, color: MobileTheme.neonBlue),
                label: const Text('Retry Connection', style: TextStyle(color: MobileTheme.neonBlue)),
              ),
            ],
          ),
        ),
      );
    }

    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 80, color: MobileTheme.emeraldGreen.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text(
              'No tasks assigned right now.\nTake a break!', 
              style: TextStyle(color: Colors.grey, fontSize: 18),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: fetchTasks,
      color: MobileTheme.neonBlue,
      backgroundColor: MobileTheme.surfaceColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          final task = tasks[index];
          return _buildTaskCard(task);
        },
      ),
    );
  }

  Widget _buildTaskCard(dynamic task) {
    // Parse the data out of the JSON response safely
    final String taskId = task['id']?.toString() ?? '';
    final String jobTitle = task['job_title'] ?? 'Unknown Job';
    final String opType = task['operation_type_id'] ?? 'Unknown Operation';
    final String status = task['status'] ?? 'PENDING';
    final String scheduledTime = task['scheduled_start_time'] ?? '';

    // Format the date into something readable
    String formattedTime = 'Not Scheduled';
    if (scheduledTime.isNotEmpty) {
      try {
        final DateTime dt = DateTime.parse(scheduledTime).toLocal();
        // Basic formatting (e.g. "2026-04-30 14:30")
        formattedTime = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (e) {
        formattedTime = scheduledTime; // fallback if parsing fails
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: GlassContainer(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Title and Status Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    jobTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusBadge(status),
              ],
            ),
            const Divider(color: Colors.white12, height: 24),
            
            // Row 2: Operation Details
            Row(
              children: [
                const Icon(Icons.build_circle_outlined, color: Colors.grey, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Operation: $opType',
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Row 3: Schedule Details
            Row(
              children: [
                const Icon(Icons.access_time, color: Colors.grey, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Scheduled: $formattedTime',
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ),
              ],
            ),
            
            // Row 4: Action Buttons
            if (status == 'SCHEDULED' || status == 'IN_PROGRESS') ...[
              const SizedBox(height: 16),
              _buildActionButtons(taskId, status),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color badgeColor;
    switch (status) {
      case 'SCHEDULED':
        badgeColor = Colors.orangeAccent;
        break;
      case 'IN_PROGRESS':
        badgeColor = MobileTheme.neonBlue;
        break;
      case 'COMPLETED':
        badgeColor = MobileTheme.emeraldGreen;
        break;
      default:
        badgeColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withOpacity(0.5), width: 1),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(color: badgeColor, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildActionButtons(String taskId, String status) {
    if (status == 'SCHEDULED') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => updateTaskStatus(taskId, 'IN_PROGRESS'),
          icon: const Icon(Icons.play_arrow, color: Colors.white),
          label: const Text('Start Task', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: MobileTheme.neonBlue.withOpacity(0.8),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      );
    } else if (status == 'IN_PROGRESS') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => updateTaskStatus(taskId, 'COMPLETED'),
          icon: const Icon(Icons.check_circle_outline, color: Colors.black),
          label: const Text('Complete Task', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: MobileTheme.emeraldGreen,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
