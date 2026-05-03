import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:optiflow_scheduler/core/models/booking.dart';
import 'package:http/http.dart' as http;
import 'package:optiflow_scheduler/core/models/job.dart';
import 'package:optiflow_scheduler/core/models/machine.dart';

class ApiService {
  static String get baseUrl {
    if (!kIsWeb) {
      // If we are native (e.g. Android Emulator), you might need 10.0.2.2.
      // But for desktop/web, 127.0.0.1 is standard.
      return "https://e22-co2060-optiflow.onrender.com/api";
    }
    return "https://e22-co2060-optiflow.onrender.com/api";
  }

  // ==========================================
  // ENGINE SLICE
  // ==========================================
  Future<Map<String, dynamic>> optimizeJob(String jobId) async {
    try {
      final response = await http.post(Uri.parse("$baseUrl/optimize/$jobId"));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception("Failed to optimize job");
      }
    } catch (e) {
      print("Error optimizing job: $e");
      return {"status": "error"};
    }
  }

  // ==========================================
  // ORDER SLICE
  // ==========================================
  Future<void> createJob(Map<String, dynamic> jobData) async {
    // POST /api/jobs
  }

  Future<void> createTask(Map<String, dynamic> taskData) async {
    // POST /api/tasks
  }

  Future<List<Map<String, dynamic>>> fetchOperationTypes() async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/operation-types"));
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(json.decode(response.body));
      } else {
        throw Exception("Failed to load operation types");
      }
    } catch (e) {
      print("Error fetching operation types: $e");
      return [];
    }
  }

  // ==========================================
  // WORKER SLICE
  // ==========================================
  Future<List<dynamic>> getTasksForResource(String resourceId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/tasks?resource_id=$resourceId"));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception("Failed to load tasks for resource");
      }
    } catch (e) {
      print("Error fetching tasks for resource: $e");
      return [];
    }
  }

  Future<void> updateTaskStatus(String taskId, String status) async {
    // PATCH /api/tasks/{task_id}/status {"status": status}
  }

  // ==========================================
  // ADMIN SLICE
  // ==========================================
  Future<List<Machine>> fetchMachines() async {
    try {
      // Assuming backend maps /resources to machines
      final response = await http.get(Uri.parse("$baseUrl/resources"));

      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);
        List<dynamic> machinesJson = [];
        if (data is List) {
          machinesJson = data.where((m) => m['type'] == 'MACHINE').toList();
        } else if (data is Map) {
          machinesJson = data['resources'] ?? data['machines'] ?? [];
        }
        return machinesJson.map((json) => Machine.fromJson(json)).toList();
      } else {
        throw Exception("Failed to load machines");
      }
    } catch (e) {
      print("Error fetching machines: $e");
      return [];
    }
  }

  Future<void> createResource(Map<String, dynamic> resourceData) async {
    // POST /api/resources
  }

  Future<void> createCapability(Map<String, dynamic> capabilityData) async {
    // POST /api/capabilities
  }

  Future<List<Job>> fetchJobs() async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/jobs"));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> jobsJson = data['jobs'] ?? [];
        return jobsJson.map((json) => Job.fromJson(json)).toList();
      } else {
        throw Exception("Failed to load jobs");
      }
    } catch (e) {
      print("Error fetching jobs: $e");
      return [];
    }
  }

  Future<List<Booking>> fetchBookings() async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/schedule"));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map<Booking>((json) {
          final startTime = json['scheduled_start_time'] != null 
              ? DateTime.parse(json['scheduled_start_time']).toLocal()
              : DateTime.now();
          final endTime = json['scheduled_end_time'] != null 
              ? DateTime.parse(json['scheduled_end_time']).toLocal()
              : startTime.add(const Duration(hours: 1));
          
          final int duration = endTime.difference(startTime).inHours;
          
          return Booking(
            id: json['id']?.toString() ?? '',
            machineId: json['assigned_resource_id']?.toString() ?? '',
            machineName: json['resources']?['name']?.toString() ?? 'Unknown Resource',
            jobTitle: json['jobs']?['title']?.toString() ?? json['name']?.toString() ?? 'Unknown Job',
            userName: 'System', // Hardcoded until user auth is added
            startTime: startTime,
            durationHours: duration > 0 ? duration : 1, // ensure at least 1 hour block for UI visibility
            priority: 'Medium', // Defaulting to Medium
            status: json['status'] == 'CONFLICT' ? 'CONFLICT' : 'CONFIRMED',
          );
        }).toList();
      } else {
        throw Exception("Failed to load schedule");
      }
    } catch (e) {
      print("Error fetching schedule: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchHumanResources() async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/resources"));
      if (response.statusCode == 200) {
        final dynamic raw = json.decode(response.body);
        List<dynamic> data;
        if (raw is List) {
          data = raw;
        } else if (raw is Map) {
          data = raw['resources'] ?? raw['data'] ?? [];
        } else {
          data = [];
        }
        return data
            .where((r) => r['type'] == 'HUMAN')
            .map((e) => e as Map<String, dynamic>)
            .toList();
      }
      return [];
    } catch (e) {
      print("Error fetching human resources: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchAllTasks() async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/tasks"));
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(json.decode(response.body));
      }
      return [];
    } catch (e) {
      print("Error fetching all tasks: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>> fetchDashboardStats() async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/dashboard-stats"));
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return {};
    } catch (e) {
      print("Error fetching dashboard stats: $e");
      return {};
    }
  }

  Future<List<Job>> fetchJobsFiltered(int days) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/analytics-jobs?days=$days"));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((j) => Job.fromJson(j)).toList();
      }
      return [];
    } catch (e) {
      print("Error fetching filtered jobs: $e");
      return [];
    }
  }

  Future<bool> createBooking({
    required String machineId,
    required String userName,
    required String startTime,
    required String endTime,
  }) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/book_machine"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "machine_id": machineId,
          "user_name": userName,
          "start_time": startTime,
          "end_time": endTime,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Error creating booking: $e");
      return false;
    }
  }

  /// Cancels / deletes a booking by ID.
  Future<bool> deleteBooking(String bookingId) async {
    try {
      final response = await http.delete(
        Uri.parse("$baseUrl/bookings/$bookingId"),
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print("Error deleting booking: $e");
      return false;
    }
  }
}
