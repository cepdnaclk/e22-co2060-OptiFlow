import 'package:intl/intl.dart';

/// Extended Booking model that carries task-level break and duration fields
/// returned by the /api/schedule endpoint.
///
/// Null-safe: every new field has a safe default so that old database rows
/// that predate the migration still parse without crashing.
class Booking {
  final String id;
  final String machineId;
  final String machineName;
  final String jobTitle;
  final String jobPriority;
  final String taskName;
  final int quantity;
  final String userName;
  final DateTime startTime;
  final DateTime processingEndTime;   // scheduled_end_time  (processing only)
  final DateTime? restEndTime;        // scheduled_rest_end_time (after break)
  final int durationHours;            // kept for Gantt block width compat
  final int processingMinutes;        // exact processing duration in minutes
  final bool breakEnabled;
  final String? breakType;            // "MACHINE" or null
  final int breakDurationMinutes;
  final String priority;              // backward-compat alias for jobPriority
  final String status;                // "CONFIRMED" | "CONFLICT"
  final String taskStatus;            // from tasks.status

  Booking({
    required this.id,
    required this.machineId,
    required this.machineName,
    required this.jobTitle,
    this.jobPriority = 'MEDIUM',
    this.taskName = '',
    this.quantity = 0,
    required this.userName,
    required this.startTime,
    required this.processingEndTime,
    this.restEndTime,
    required this.durationHours,
    this.processingMinutes = 0,
    this.breakEnabled = false,
    this.breakType,
    this.breakDurationMinutes = 0,
    required this.priority,
    this.status = 'CONFIRMED',
    this.taskStatus = 'SCHEDULED',
  });

  /// Backward-compat getter — Gantt blocks use this.
  DateTime get endTime => processingEndTime;

  /// Resource-available time: rest end if break is enabled, else processing end.
  DateTime get resourceAvailableTime =>
      (breakEnabled && restEndTime != null) ? restEndTime! : processingEndTime;

  static final _fmt = DateFormat('h:mm a');

  String get formattedStart => _fmt.format(startTime);
  String get formattedProcessingEnd => _fmt.format(processingEndTime);
  String get formattedRestEnd =>
      restEndTime != null ? _fmt.format(restEndTime!) : formattedProcessingEnd;
}
