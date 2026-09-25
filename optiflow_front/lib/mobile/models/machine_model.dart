/// Represents a factory machine/resource in the Machine Shop.
class MachineModel {
  final String id;
  final String name;
  final String status;  // "Active" | "OFFLINE" | etc.
  final String? imageUrl;
  final double? pricePerHour;

  const MachineModel({
    required this.id,
    required this.name,
    required this.status,
    this.imageUrl,
    this.pricePerHour,
  });

  factory MachineModel.fromJson(Map<String, dynamic> json) {
    return MachineModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? 'Unnamed Machine',
      status: json['status'] ?? 'Unknown',
      imageUrl: json['image_url'],
      pricePerHour: (json['price_per_hour'] as num?)?.toDouble(),
    );
  }

  bool get isOnline =>
      status.toLowerCase() != 'offline' && status.toLowerCase() != 'maintenance';
}
