import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

class TaskItem {
  final String id;
  TextEditingController nameController;
  TextEditingController quantityController;
  String operationType;
  List<String> dependsOn;

  TaskItem({
    required this.id,
    required this.nameController,
    required this.quantityController,
    required this.operationType,
    required this.dependsOn,
  });
}

class NewJobOrder extends StatefulWidget {
  const NewJobOrder({super.key});

  @override
  State<NewJobOrder> createState() => _NewJobOrderState();
}

class _NewJobOrderState extends State<NewJobOrder> {
  final TextEditingController _jobNameController = TextEditingController();
  final TextEditingController _clientNameController = TextEditingController();
  final TextEditingController _totalQuantityController = TextEditingController();
  String _priority = 'Medium';
  DateTime? _deadline;

  final List<TaskItem> _tasks = [];
  int _taskIdCounter = 1;

  final Color _navyBlue = const Color(0xFF000080);
  final Color _purpleAccent = const Color(0xFF6A0DAD);

  void _addTask() {
    setState(() {
      _tasks.add(
        TaskItem(
          id: 'T${_taskIdCounter++}',
          nameController: TextEditingController(),
          quantityController: TextEditingController(),
          operationType: 'Printing',
          dependsOn: [],
        ),
      );
    });
  }

  void _removeTask(int index) {
    setState(() {
      final removedTaskId = _tasks[index].id;
      _tasks.removeAt(index);
      // Remove dependency references to the deleted task
      for (var task in _tasks) {
        task.dependsOn.remove(removedTaskId);
      }
    });
  }

  Future<void> _selectDeadline(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _navyBlue,
              onPrimary: Colors.white,
              onSurface: _navyBlue,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _deadline) {
      setState(() {
        _deadline = picked;
      });
    }
  }

  Future<void> _showMultiSelect(
    BuildContext context,
    TaskItem currentTask,
  ) async {
    int currentIndex = _tasks.indexOf(currentTask);
    List<TaskItem> availableTasks = _tasks.sublist(0, currentIndex);

    if (availableTasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No previous tasks available to depend on.'),
          backgroundColor: _navyBlue,
        ),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: Text(
                'Select Dependencies',
                style: TextStyle(color: _navyBlue, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: ListBody(
                  children: availableTasks.map((task) {
                    final isChecked = currentTask.dependsOn.contains(task.id);
                    final titleText = task.nameController.text.isNotEmpty
                        ? task.nameController.text
                        : 'Unnamed Task (${task.id})';
                    return CheckboxListTile(
                      title: Text(
                        titleText,
                        style: TextStyle(color: _navyBlue),
                      ),
                      value: isChecked,
                      activeColor: _purpleAccent,
                      checkColor: Colors.white,
                      onChanged: (bool? value) {
                        setDialogState(() {
                          if (value == true) {
                            currentTask.dependsOn.add(task.id);
                          } else {
                            currentTask.dependsOn.remove(task.id);
                          }
                        });
                        setState(() {});
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Done',
                    style: TextStyle(
                      color: _purpleAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submitOrder() async {
    // Helper to get operation ID based on string value
    int getOperationTypeId(String op) {
      switch (op) {
        case 'Printing': return 1;
        case 'Folding': return 2;
        case 'Binding': return 3;
        case 'Cutting': return 4;
        default: return 1;
      }
    }

    // Build tasks array
    List<Map<String, dynamic>> tasksData = [];
    for (var task in _tasks) {
      tasksData.add({
        'name': task.nameController.text,
        // Converted to string to satisfy FastAPI backend requirements
        'operation_type_id': getOperationTypeId(task.operationType).toString(),
        'quantity_to_process': int.tryParse(task.quantityController.text) ?? 
                               int.tryParse(_totalQuantityController.text) ?? 0,
      });
    }

    // Build dependencies array
    List<Map<String, dynamic>> dependencies = [];
    for (int i = 0; i < _tasks.length; i++) {
      var task = _tasks[i];
      for (var depId in task.dependsOn) {
        int predIndex = _tasks.indexWhere((t) => t.id == depId);
        if (predIndex != -1) {
          dependencies.add({
            'predecessor_index': predIndex,
            'successor_index': i,
            'mandatory_wait_minutes': 0,
          });
        }
      }
    }

    // Prepare the final payload
    Map<String, dynamic> orderData = {
      "title": _jobNameController.text,
      "client_name": _clientNameController.text,
      "total_quantity": int.tryParse(_totalQuantityController.text) ?? 0,
      "deadline": "2026-03-27T10:00:00", // Dummy date as requested
      "created_by": "11111111-1111-1111-1111-111111111111", // Dummy UUID as requested
      "tasks": tasksData,
      "dependencies": dependencies,
    };

    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/create_job'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(orderData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('--- Success (200 OK) ---');
        print(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Job Order Submitted Successfully!'),
              backgroundColor: _purpleAccent,
            ),
          );
        }
      } else {
        print('--- Error: ${response.statusCode} ---');
        print(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to submit: ${response.statusCode}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('--- Exception caught ---');
      print(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _jobNameController.dispose();
    _clientNameController.dispose();
    _totalQuantityController.dispose();
    for (var task in _tasks) {
      task.nameController.dispose();
      task.quantityController.dispose();
    }
    super.dispose();
  }

  InputDecoration _customInputDecoration(String label, String? hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: _navyBlue.withOpacity(0.8)),
      hintStyle: TextStyle(color: Colors.grey.shade400),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: _navyBlue.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: _purpleAccent, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      filled: true,
      fillColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'New Job Order',
            style: TextStyle(
              color: _navyBlue,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),

          // --- SECTION 1: ORDER DETAILS ---
          Text(
            'Section 1: Order Details',
            style: TextStyle(
              color: _purpleAccent,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Divider(),
          const SizedBox(height: 16),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 1,
                child: TextField(
                  controller: _jobNameController,
                  style: TextStyle(color: _navyBlue),
                  decoration: _customInputDecoration(
                    'Job Name',
                    'e.g., 500 Diaries',
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: TextField(
                  controller: _clientNameController,
                  style: TextStyle(color: _navyBlue),
                  decoration: _customInputDecoration(
                    'Client Name',
                    'e.g., Acme Corp',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 1,
                child: TextField(
                  controller: _totalQuantityController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: _navyBlue),
                  decoration: _customInputDecoration(
                    'Total Quantity',
                    'e.g., 500',
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: DropdownButtonFormField<String>(
                  initialValue: _priority,
                  decoration: _customInputDecoration('Priority', null),
                  dropdownColor: Colors.white,
                  items: ['High', 'Medium', 'Low'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value, style: TextStyle(color: _navyBlue)),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      _priority = newValue!;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: GestureDetector(
                  onTap: () => _selectDeadline(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: _navyBlue.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _deadline == null
                              ? 'Deadline'
                              : DateFormat('MMM d, yyyy').format(_deadline!),
                          style: TextStyle(
                            color: _deadline == null
                                ? _navyBlue.withOpacity(0.8)
                                : _navyBlue,
                            fontSize: 16,
                          ),
                        ),
                        Icon(
                          Icons.calendar_today,
                          color: _purpleAccent,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // --- SECTION 2: DYNAMIC TASK SEQUENCE BUILDER ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Section 2: Task Sequence (DAG)',
                style: TextStyle(
                  color: _purpleAccent,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _addTask,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  'Add Task',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navyBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 16),

          if (_tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Center(
                child: Text(
                  'No tasks added yet. Click "Add Task" to begin.',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),

          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _tasks.length,
            itemBuilder: (context, index) {
              final task = _tasks[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: _navyBlue.withOpacity(0.1)),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade50,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 8, right: 16),
                      child: CircleAvatar(
                        backgroundColor: _purpleAccent.withOpacity(0.2),
                        radius: 16,
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: _purpleAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: task.nameController,
                        style: TextStyle(color: _navyBlue),
                        decoration: _customInputDecoration(
                          'Task Name',
                          'e.g., Print Cover',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: task.quantityController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: _navyBlue),
                        decoration: _customInputDecoration(
                          'Qty',
                          'e.g., 500',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<String>(
                        initialValue: task.operationType,
                        decoration: _customInputDecoration(
                          'Operation Type',
                          null,
                        ),
                        dropdownColor: Colors.white,
                        items: ['Printing', 'Folding', 'Binding', 'Cutting']
                            .map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(
                                  value,
                                  style: TextStyle(color: _navyBlue),
                                ),
                              );
                            })
                            .toList(),
                        onChanged: (newValue) {
                          setState(() {
                            task.operationType = newValue!;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: GestureDetector(
                        onTap: () => _showMultiSelect(context, task),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _navyBlue.withOpacity(0.3),
                            ),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.white,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  task.dependsOn.isEmpty
                                      ? 'Depends On'
                                      : '${task.dependsOn.length} Selected',
                                  style: TextStyle(
                                    color: task.dependsOn.isEmpty
                                        ? _navyBlue.withOpacity(0.8)
                                        : _navyBlue,
                                    fontSize: 16,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(Icons.arrow_drop_down, color: _navyBlue),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                      ),
                      onPressed: () => _removeTask(index),
                      tooltip: 'Remove Task',
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          Center(
            child: ElevatedButton(
              onPressed: _submitOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: _purpleAccent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 4,
              ),
              child: const Text(
                'Submit Order',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
