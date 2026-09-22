class WorkerTask {
  final String id;
  final String status;
  final DateTime? scheduledStartTime;
  final int quantityToProcess;
  final String jobTitle;
  final String resourceName;
  final String operationTypeId;

  WorkerTask({
    required this.id,
    required this.status,
    this.scheduledStartTime,
    required this.quantityToProcess,
    required this.jobTitle,
    required this.resourceName,
    required this.operationTypeId,
  });

  factory WorkerTask.fromJson(Map<String, dynamic> json) {
    DateTime? parsedTime;
    if (json['scheduled_start_time'] != null) {
      try {
        parsedTime = DateTime.parse(json['scheduled_start_time']).toLocal();
      } catch (e) {
        // Fallback or leave null if parsing fails
      }
    }

    return WorkerTask(
      id: json['id']?.toString() ?? '',
      status: json['status'] ?? 'PENDING',
      scheduledStartTime: parsedTime,
      quantityToProcess: json['quantity_to_process'] ?? 0,
      jobTitle: json['jobs']?['title'] ?? json['job_title'] ?? 'Unknown Job',
      resourceName: json['resources']?['name'] ?? 'Unknown Resource',
      operationTypeId:
          json['operation_type_id']?.toString() ?? 'Unknown Operation',
    );
  }
}
