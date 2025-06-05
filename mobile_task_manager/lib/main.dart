import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(TaskManagerApp());

class Task {
  String title;
  bool isCompleted;

  Task({required this.title, this.isCompleted = false});

  Map<String, dynamic> toJson() => {
        'title': title,
        'isCompleted': isCompleted,
      };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        title: json['title'],
        isCompleted: json['isCompleted'],
      );
}

enum FilterStatus { all, completed, pending }

class TaskManagerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Manager',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: TaskManagerPage(),
    );
  }
}

class TaskManagerPage extends StatefulWidget {
  @override
  State<TaskManagerPage> createState() => _TaskManagerPageState();
}

class _TaskManagerPageState extends State<TaskManagerPage>
    with SingleTickerProviderStateMixin {
  List<Task> tasks = [];
  FilterStatus filterStatus = FilterStatus.all;

  final TextEditingController _taskController = TextEditingController();

  late final AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _loadTasksFromStorage();
    _animationController =
        AnimationController(vsync: this, duration: Duration(milliseconds: 300));
  }

  Future<void> _loadTasksFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final String? tasksString = prefs.getString('tasks');
    if (tasksString != null) {
      final List<dynamic> jsonList = jsonDecode(tasksString);
      setState(() {
        tasks = jsonList.map((json) => Task.fromJson(json)).toList();
      });
    }
  }

  Future<void> _saveTasksToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonString = jsonEncode(tasks.map((t) => t.toJson()).toList());
    await prefs.setString('tasks', jsonString);
  }

  void _addTask(String title) {
    if (title.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Task title cannot be empty')),
      );
      return;
    }
    setState(() {
      tasks.add(Task(title: title));
    });
    _taskController.clear();
    Navigator.of(context).pop();
    _saveTasksToStorage();
  }

  void _toggleTask(int index) {
    setState(() {
      tasks[index].isCompleted = !tasks[index].isCompleted;
    });
    _saveTasksToStorage();
  }

  void _deleteTask(int index) {
    setState(() {
      tasks.removeAt(index);
    });
    _saveTasksToStorage();
  }

  void _showAddTaskDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add New Task'),
        content: TextField(
          controller: _taskController,
          autofocus: true,
          maxLength: 50,
          decoration: InputDecoration(
            hintText: 'Enter task title',
            counterText: '',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onSubmitted: _addTask,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _taskController.clear();
            },
            child: Text('Cancel'),
          ),
          ElevatedButton.icon(
            icon: Icon(Icons.add_task),
            label: Text('Add'),
            onPressed: () => _addTask(_taskController.text),
          ),
        ],
      ),
    );
  }

  List<Task> get filteredTasks {
    switch (filterStatus) {
      case FilterStatus.completed:
        return tasks.where((t) => t.isCompleted).toList();
      case FilterStatus.pending:
        return tasks.where((t) => !t.isCompleted).toList();
      case FilterStatus.all:
      default:
        return tasks;
    }
  }

  Widget _buildFilterChip(
      String label, FilterStatus status, int count, Color color) {
    final isSelected = filterStatus == status;
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          SizedBox(width: 6),
          CircleAvatar(
            radius: 10,
            backgroundColor: isSelected ? Colors.white : color.withOpacity(0.7),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? color : Colors.white,
              ),
            ),
          )
        ],
      ),
      selected: isSelected,
      onSelected: (_) {
        setState(() => filterStatus = status);
      },
      selectedColor: color,
      backgroundColor: color.withOpacity(0.2),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : color,
        fontWeight: FontWeight.w600,
      ),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      pressElevation: 4,
      shadowColor: Colors.black54,
    );
  }

  Future<void> _refreshTasks() async {
    // Here we simply reload from storage for demo,
    // but can be enhanced for real backend sync.
    await _loadTasksFromStorage();
  }

  @override
  void dispose() {
    _taskController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Widget _buildTaskItem(Task task, int realIndex) {
    return Dismissible(
      key: Key(task.title + realIndex.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.redAccent,
        alignment: Alignment.centerRight,
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Icon(Icons.delete_forever, color: Colors.white, size: 30),
      ),
      onDismissed: (_) => _deleteTask(realIndex),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        leading: AnimatedSwitcher(
          duration: Duration(milliseconds: 300),
          transitionBuilder: (child, animation) =>
              ScaleTransition(scale: animation, child: child),
          child: Checkbox(
            key: ValueKey(task.isCompleted),
            value: task.isCompleted,
            onChanged: (_) => _toggleTask(realIndex),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            fontSize: 18,
            decoration:
                task.isCompleted ? TextDecoration.lineThrough : null,
            color: task.isCompleted ? Colors.grey[600] : Colors.black87,
          ),
        ),
        trailing: Icon(Icons.drag_handle, color: Colors.grey[400]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allCount = tasks.length;
    final completedCount = tasks.where((t) => t.isCompleted).length;
    final pendingCount = allCount - completedCount;

    return Scaffold(
      appBar: AppBar(
        title: Text('Task Manager'),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  _buildFilterChip('All', FilterStatus.all, allCount,
                      Colors.deepPurple),
                  SizedBox(width: 10),
                  _buildFilterChip('Completed', FilterStatus.completed,
                      completedCount, Colors.green),
                  SizedBox(width: 10),
                  _buildFilterChip('Pending', FilterStatus.pending,
                      pendingCount, Colors.orange),
                ],
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshTasks,
        child: filteredTasks.isEmpty
            ? ListView(
                physics: AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: 120),
                  Center(
                    child: Text(
                      'No tasks here.\nTap "+" to add new tasks.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, color: Colors.grey[600]),
                    ),
                  ),
                ],
              )
            : ListView.builder(
                physics: AlwaysScrollableScrollPhysics(),
                itemCount: filteredTasks.length,
                itemBuilder: (ctx, i) {
                  final task = filteredTasks[i];
                  final realIndex = tasks.indexOf(task);
                  return _buildTaskItem(task, realIndex);
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTaskDialog,
        label: Text('Add Task'),
        icon: Icon(Icons.add),
        extendedPadding: EdgeInsets.symmetric(horizontal: 20),
        elevation: 6,
      ),
    );
  }
}
