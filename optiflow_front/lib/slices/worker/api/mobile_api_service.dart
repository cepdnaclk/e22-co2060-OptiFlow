import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/task_model.dart';

class MobileApiService {
  // Use 10.0.2.2 for Android Emulator, or localhost / specific IP for physical devices.
  static const String baseUrl = 'https://e22-co2060-optiflow.onrender.com/api';

  Future<List<WorkerTask>> fetchTasks(String resourceId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/tasks?resource_id=$resourceId'));

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

  Future<void> updateTaskStatus(String taskId, String newStatus) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/tasks/$taskId/status'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'status': newStatus}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}
