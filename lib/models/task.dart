import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum TaskPriority { low, medium, high }

class Task {
  final String id;
  final String userId;
  final String title;
  final String description;
  final DateTime dueDate;
  final TaskPriority priority;
  final bool isCompleted;
  final DateTime createdAt;
  final String? category;
  final List<String> tags;

  Task({
    this.id = '',
    required this.userId,
    required this.title,
    this.description = '',
    required this.dueDate,
    this.priority = TaskPriority.medium,
    this.isCompleted = false,
    required this.createdAt,
    this.category,
    this.tags = const [],
  });

  Task copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    DateTime? dueDate,
    TaskPriority? priority,
    bool? isCompleted,
    DateTime? createdAt,
    String? category,
    List<String>? tags,
  }) {
    return Task(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      category: category ?? this.category,
      tags: tags ?? this.tags,
    );
  }

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'title': title,
    'description': description,
    'dueDate': dueDate.toIso8601String(),
    'priority': priority.name,
    'isCompleted': isCompleted,
    'createdAt': createdAt.toIso8601String(),
    'category': category,
    'tags': tags,
  };

  static Task fromDoc(DocumentSnapshot doc) {
    final data = doc.data()! as Map<String, dynamic>;

    DateTime parseDateTime(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        return DateTime.parse(value);
      } else {
        throw ArgumentError('Invalid date format');
      }
    }

    return Task(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? 'Untitled Task',
      description: data['description'] ?? '',
      dueDate: parseDateTime(data['dueDate']),
      priority: TaskPriority.values.firstWhere(
        (e) => e.name == data['priority'],
        orElse: () => TaskPriority.medium,
      ),
      isCompleted: data['isCompleted'] ?? false,
      createdAt: parseDateTime(data['createdAt']),
      category: data['category'],
      tags: List<String>.from(data['tags'] ?? []),
    );
  }

  String get dueDateIso => dueDate.toIso8601String();
  String get createdAtIso => createdAt.toIso8601String();

  Color get priorityColor {
    switch (priority) {
      case TaskPriority.high:
        return Colors.red;
      case TaskPriority.medium:
        return Colors.orange;
      case TaskPriority.low:
        return Colors.green;
    }
  }

  bool get isOverdue => !isCompleted && dueDate.isBefore(DateTime.now());
  bool get isDueToday => !isCompleted && isSameDay(dueDate, DateTime.now());
  bool get isDueTomorrow => !isCompleted && isSameDay(dueDate, DateTime.now().add(const Duration(days: 1)));

  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String get dueDateText {
    if (isOverdue) return 'Overdue';
    if (isDueToday) return 'Today';
    if (isDueTomorrow) return 'Tomorrow';
    
    final now = DateTime.now();
    final difference = dueDate.difference(now).inDays;
    
    if (difference < 7) {
      return 'In $difference days';
    } else if (difference < 30) {
      final weeks = (difference / 7).floor();
      return 'In $weeks weeks';
    } else {
      return '${dueDate.day}/${dueDate.month}/${dueDate.year}';
    }
  }
}
