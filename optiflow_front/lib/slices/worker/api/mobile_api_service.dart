import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/task_model.dart';

class MobileApiService {
  // Production Render URL and Localhost URLs
  static const String defaultRemoteUrl =
      'https://e22-co2060-optiflow.onrender.com/api';
  static const String defaultLocalUrl = 'http://127.0.0.1:8000/api';
  static const String androidEmulatorUrl = 'http://10.0.2.2:8000/api';

  static String? _resolvedBaseUrl;

  /// Resolves the optimal backend URL (prefers local if active for dev, falls back to remote)
  Future<String> getBaseUrl() async {
    if (_resolvedBaseUrl != null) return _resolvedBaseUrl!;

    final candidateUrls = [
      defaultLocalUrl,
      androidEmulatorUrl,
      defaultRemoteUrl,
    ];

    for (final url in candidateUrls) {
      try {
        final res = await http
            .get(Uri.parse('$url/resources'))
            .timeout(const Duration(milliseconds: 1500));
        if (res.statusCode == 200) {
          _resolvedBaseUrl = url;
          return url;
        }
      } catch (_) {
        // Continue to next candidate
      }
    }

    _resolvedBaseUrl = defaultRemoteUrl;
    return defaultRemoteUrl;
  }

  /// Fetches all human workers from GET /api/resources where type == 'HUMAN'
  Future<List<Map<String, String>>> fetchHumanWorkers() async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await http
          .get(Uri.parse('$baseUrl/resources'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);

        List<dynamic> list = [];
        if (decoded is List) {
          list = decoded;
        } else if (decoded is Map<String, dynamic> &&
            decoded.containsKey('resources')) {
          list = decoded['resources'];
        }

        final humanWorkers =
            list.where((item) => item['type'] == 'HUMAN').toList();

        return humanWorkers.map<Map<String, String>>((item) {
          final rawName = item['name']?.toString() ?? 'Worker';
          final id = item['id']?.toString() ?? '';

          // Extracts display name and role from format "Name (Role)"
          final match = RegExp(r'^(.*?)\s*\((.*?)\)$').firstMatch(rawName);
          final displayName =
              match != null ? match.group(1)!.trim() : rawName.trim();
          final role = match != null
              ? match.group(2)!.trim()
              : (item['role']?.toString() ?? 'Operator');

          return {
            'id': id,
            'name': displayName,
            'role': role,
            'rawName': rawName,
            'status': item['status']?.toString() ?? 'ACTIVE',
          };
        }).toList();
      } else {
        throw Exception(
            'Failed to load workers. Status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error while fetching workers: $e');
    }
  }

  /// Fetches tasks for a specific worker or machine
  Future<List<WorkerTask>> fetchTasks(String resourceId) async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await http
          .get(Uri.parse('$baseUrl/tasks?resource_id=$resourceId'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);

        List<dynamic> tasksList = [];
        if (decoded is Map<String, dynamic> && decoded.containsKey('tasks')) {
          tasksList = decoded['tasks'];
        } else if (decoded is List) {
          tasksList = decoded;
        }

        return tasksList.map((json) => WorkerTask.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load tasks. Status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  /// Updates task status (e.g. SCHEDULED -> IN_PROGRESS -> COMPLETED)
  Future<void> updateTaskStatus(String taskId, String newStatus) async {
    try {
      final baseUrl = await getBaseUrl();
      final response = await http
          .patch(
            Uri.parse('$baseUrl/tasks/$taskId/status'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'status': newStatus}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Failed to update status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}
