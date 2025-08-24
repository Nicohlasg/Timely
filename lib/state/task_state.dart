import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/task.dart';

class TaskState extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription? _authSub;
  StreamSubscription? _taskSub;
  List<Task> _tasks = [];
  bool _isLoading = true;

  List<Task> get tasks => _tasks;
  bool get isLoading => _isLoading;

  // Get upcoming tasks (not completed, due within 7 days)
  List<Task> get upcomingTasks {
    final now = DateTime.now();
    final sevenDaysFromNow = now.add(const Duration(days: 7));
    
    return _tasks
        .where((task) => !task.isCompleted && task.dueDate.isBefore(sevenDaysFromNow))
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  // Get overdue tasks
  List<Task> get overdueTasks {
    return _tasks
        .where((task) => !task.isCompleted && task.isOverdue)
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  // Get today's tasks
  List<Task> get todaysTasks {
    return _tasks
        .where((task) => !task.isCompleted && task.isDueToday)
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  TaskState() {
    _authSub = _auth.authStateChanges().listen((user) {
      if (user == null) {
        _tasks = [];
        _taskSub?.cancel();
        _isLoading = false;
        notifyListeners();
        return;
      }
      _attach(user.uid);
    });
    if (_auth.currentUser != null) {
      _attach(_auth.currentUser!.uid);
    } else {
      _isLoading = false;
    }
  }

  void _attach(String uid) {
    _isLoading = true;
    notifyListeners();
    _taskSub?.cancel();
    _taskSub = FirebaseFirestore.instance
        .collection('tasks')
        .where('userId', isEqualTo: uid)
        .orderBy('dueDate', descending: false)
        .snapshots()
        .listen((snapshot) {
      _tasks = snapshot.docs.map((d) => Task.fromDoc(d)).toList();
      _isLoading = false;
      notifyListeners();
    }, onError: (e) {
      debugPrint('Tasks stream error: $e');
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> addTask(Task task) async {
    if (_auth.currentUser == null) {
      throw Exception('No user is currently signed in');
    }

    final taskWithUserId = task.copyWith(userId: _auth.currentUser!.uid);
    await FirebaseFirestore.instance
        .collection('tasks')
        .add(taskWithUserId.toJson());
  }

  Future<void> updateTask(Task task) async {
    if (_auth.currentUser == null) {
      throw Exception('No user is currently signed in');
    }

    if (task.userId != _auth.currentUser!.uid) {
      throw Exception('Cannot update a task that belongs to another user');
    }

    await FirebaseFirestore.instance
        .collection('tasks')
        .doc(task.id)
        .update(task.toJson());
  }

  Future<void> deleteTask(String taskId) async {
    if (_auth.currentUser == null) {
      throw Exception('No user is currently signed in');
    }

    await FirebaseFirestore.instance
        .collection('tasks')
        .doc(taskId)
        .delete();
  }

  Future<bool> toggleTaskCompletion(String taskId) async {
    if (_auth.currentUser == null) {
      throw Exception('No user is currently signed in');
    }

    final task = _tasks.firstWhere((t) => t.id == taskId);
    if (task.userId != _auth.currentUser!.uid) {
      throw Exception('Cannot update a task that belongs to another user');
    }

    final updatedTask = task.copyWith(isCompleted: !task.isCompleted);
    await updateTask(updatedTask);
    return updatedTask.isCompleted;
  }

  // Method to create sample tasks for demonstration
  Future<void> createSampleTasks() async {
    if (_auth.currentUser == null) return;

    final now = DateTime.now();
    final sampleTasks = [
      Task(
        userId: _auth.currentUser!.uid,
        title: "Finish UI Design",
        description: "Complete the calendar app UI design",
        dueDate: now.add(const Duration(days: 1)),
        priority: TaskPriority.high,
        createdAt: now,
        category: "Work",
      ),
      Task(
        userId: _auth.currentUser!.uid,
        title: "Read Chapter 4",
        description: "Complete reading assignment for History class",
        dueDate: now.add(const Duration(days: 2)),
        priority: TaskPriority.medium,
        createdAt: now,
        category: "Study",
      ),
      Task(
        userId: _auth.currentUser!.uid,
        title: "Grocery Shopping",
        description: "Buy groceries for the week",
        dueDate: now.add(const Duration(hours: 4)),
        priority: TaskPriority.low,
        createdAt: now,
        category: "Personal",
      ),
    ];

    for (final task in sampleTasks) {
      await addTask(task);
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _taskSub?.cancel();
    super.dispose();
  }
}
