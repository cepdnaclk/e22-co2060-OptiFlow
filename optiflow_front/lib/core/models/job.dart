class Job {
  final String id;
  final String title;
  final int price;
  final String status;
  final String deadline;
  final int estimatedHours;
  final String priority;

  Job({
    required this.id,
    required this.title,
    required this.price,
    required this.status,
    required this.deadline,
    required this.estimatedHours,
    this.priority = 'MEDIUM',
  });

  factory Job.fromJson(Map<String, dynamic> json) {
    return Job(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Untitled Job',
      price: json['price'] ?? 0,
      status: json['status'] ?? 'OPEN',
      deadline: json['deadline'] ?? '',
      estimatedHours: json['estimated_hours'] ?? 0,
      priority: json['priority'] ?? 'MEDIUM',
    );
  }
}
