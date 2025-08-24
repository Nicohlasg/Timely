import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/achievement_state.dart';
import '../models/task.dart';
import '../state/task_state.dart';
import '../widgets/background_container.dart';
import '../Theme/app_styles.dart';
import '../utils/widget_utils.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/app_tag.dart';

class AllTasksPage extends StatefulWidget {
  const AllTasksPage({super.key});

  @override
  State<AllTasksPage> createState() => _AllTasksPageState();
}

class _AllTasksPageState extends State<AllTasksPage> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 1));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  // State for filters
  TaskPriority? _priorityFilter;
  String? _categoryFilter;
  List<String> _categories = [];

  Widget _buildFilterBar(List<Task> allTasks) {
    _categories =
        allTasks.map((t) => t.category ?? 'Uncategorized').toSet().toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          _buildFilterChip<TaskPriority?>(
            label: _priorityFilter?.name ?? 'Priority',
            value: null,
            selectedValue: _priorityFilter,
            items: [
              const PopupMenuItem(child: Text('All Priorities'), value: null),
              ...TaskPriority.values
                  .map((p) => PopupMenuItem(child: Text(p.name), value: p)),
            ],
            onSelected: (value) => setState(() => _priorityFilter = value),
          ),
          const SizedBox(width: 8),
          _buildFilterChip<String?>(
            label: _categoryFilter ?? 'Category',
            value: null,
            selectedValue: _categoryFilter,
            items: [
              const PopupMenuItem(child: Text('All Categories'), value: null),
              ..._categories
                  .map((c) => PopupMenuItem(child: Text(c), value: c)),
            ],
            onSelected: (value) => setState(() => _categoryFilter = value),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip<T>({
    required String label,
    required T value,
    required T selectedValue,
    required List<PopupMenuEntry<T>> items,
    required ValueChanged<T> onSelected,
  }) {
    final bool isActive = selectedValue != null;
    return PopupMenuButton<T>(
      onSelected: onSelected,
      itemBuilder: (BuildContext context) => items,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: context.appStyle.surfaceColor,
      child: Chip(
        label: Text(label),
        labelStyle: context.appStyle.bodyStyle
            .copyWith(color: isActive ? Colors.white : Colors.white70),
        backgroundColor: isActive
            ? context.appStyle.primaryColor.withOpacity(0.8)
            : Colors.white.withOpacity(0.1),
        avatar: isActive ? const Icon(Icons.check, size: 16) : null,
        side: BorderSide(
            color: isActive ? Colors.transparent : Colors.white30),
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 7, // Show 7 shimmer cards
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: AppCard(
            child: Row(
              children: [
                WidgetUtils.buildShimmerPlaceholder(
                    width: 24, height: 24, borderRadius: BorderRadius.circular(12)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      WidgetUtils.buildShimmerPlaceholder(height: 16, width: 200),
                      const SizedBox(height: 8),
                      WidgetUtils.buildShimmerPlaceholder(height: 14, width: 150),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundImageContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            'All Tasks',
            style: context.appStyle.headingStyle,
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Stack(
          alignment: Alignment.topCenter,
          children: [
            Consumer<TaskState>(
              builder: (context, taskState, child) {
                if (taskState.isLoading) {
              return _buildLoadingShimmer();
            }

            if (taskState.tasks.isEmpty) {
              return const Center(
                child: Text(
                  'You have no tasks yet!',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              );
            }

            var filteredTasks = taskState.tasks;
            if (_priorityFilter != null) {
              filteredTasks = filteredTasks
                  .where((t) => t.priority == _priorityFilter)
                  .toList();
            }
            if (_categoryFilter != null) {
              filteredTasks = filteredTasks
                  .where((t) => (t.category ?? 'Uncategorized') == _categoryFilter)
                  .toList();
            }

            return Column(
              children: [
                _buildFilterBar(taskState.tasks),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: ListView.builder(
                      key: ValueKey(filteredTasks
                          .map((t) => t.id)
                          .join()), // Key to identify the list state
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filteredTasks.length,
                      itemBuilder: (context, index) {
                        final task = filteredTasks[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: TaskCard(
                            title: task.title,
                            description: task.description.isNotEmpty
                                ? task.description
                                : null,
                            isCompleted: task.isCompleted,
                          onToggle: () async {
                            final isNowComplete = await context
                                .read<TaskState>()
                                .toggleTaskCompletion(task.id);
                            if (isNowComplete) {
                              _confettiController.play();
                              context
                                  .read<AchievementState>()
                                  .unlockAchievement('task_complete');
                            }
                          },
                            trailingWidget: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  task.dueDateText,
                                  style: context.appStyle.bodyStyle,
                                ),
                                const SizedBox(height: 4),
                                if (task.priority == TaskPriority.high)
                                  PriorityTag.high(),
                                if (task.priority == TaskPriority.medium)
                                  PriorityTag.medium(),
                                if (task.priority == TaskPriority.low)
                                  PriorityTag.low(),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        ConfettiWidget(
          confettiController: _confettiController,
          blastDirectionality: BlastDirectionality.explosive,
          shouldLoop: false,
          colors: const [
            Colors.green,
            Colors.blue,
            Colors.pink,
            Colors.orange,
            Colors.purple
          ],
        ),
      ],
      ),
    );
  }
}
