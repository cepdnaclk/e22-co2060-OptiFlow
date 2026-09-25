class Booking {
  final String id;
  final String machineId;
  final String machineName;
  final String jobTitle;
  final String userName;
  final DateTime startTime; // e.g. 2026-02-16 09:00
  final DateTime endTime;
  final String priority; // "High", "Medium", "Low"
  final String status; // "CONFIRMED", "CONFLICT"

  Booking({
    required this.id,
    required this.machineId,
    required this.machineName,
    required this.jobTitle,
    required this.userName,
    required this.startTime,
    required this.endTime,
    required this.priority,
    this.status = "CONFIRMED",
  });

  // Calculate durationMinutes helper
  int get durationMinutes => endTime.difference(startTime).inMinutes;
}
