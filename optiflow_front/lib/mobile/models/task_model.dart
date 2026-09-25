import 'package:intl/intl.dart';

/// Represents a task assigned to a factory worker.
class TaskModel {
  final String id;
  final String status;           // SCHEDULED | IN_PROGRESS | COMPLETED
  final String jobTitle;
  final String operationTypeId;
  final String resourceName;
  final int quantityToProcess;
  final DateTime? scheduledStart;

  const TaskModel({
    required this.id,
    required this.status,
    required this.jobTitle,
    required this.operationTypeId,
    required this.resourceName,
    required this.quantityToProcess,
    this.scheduledStart,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    DateTime? parsedTime;
    try {
      final raw = json['scheduled_start_time'];
      if (raw != null) parsedTime = DateTime.parse(raw).toLocal();
    } catch (_) {}

    return TaskModel(
      id: json['id']?.toString() ?? '',
      status: json['status'] ?? 'SCHEDULED',
      jobTitle: json['jobs']?['title'] ?? json['job_title'] ?? 'Untitled Job',
      operationTypeId: json['operation_type_id']?.toString() ?? 'Operation',
      resourceName: json['resources']?['name'] ?? json['resource_name'] ?? 'Machine',
      quantityToProcess: json['quantity_to_process'] ?? 0,
      scheduledStart: parsedTime,
    );
  }

  /// Returns e.g. "2:30 PM" or "Not scheduled"
  String get formattedTime {
    if (scheduledStart == null) return 'Not scheduled';
    return DateFormat('h:mm a').format(scheduledStart!);
  }

  String get formattedDate {
    if (scheduledStart == null) return '';
    return DateFormat('MMM d, yyyy').format(scheduledStart!);
  }
}
