import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/task.dart';
import '../state/task_state.dart';
import '../widgets/background_container.dart';
import '../Theme/app_styles.dart';
import '../widgets/common/app_button.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/app_tag.dart';
import '../widgets/common/bouncy_button.dart';

class AddTaskPage extends StatefulWidget {
  const AddTaskPage({super.key});

  @override
  State<AddTaskPage> createState() => _AddTaskPageState();
}

class _AddTaskPageState extends State<AddTaskPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  TaskPriority _selectedPriority = TaskPriority.medium;

  final List<String> _categoryOptions = [
    'Personal',
    'Work',
    'Health',
    'Education',
    'Social',
    'Custom'
  ];
  late String _selectedCategory;
  final _customCategoryController = TextEditingController();

  DateTime _dueDate = DateTime.now();
  bool _showDatePicker = false;
  bool _showTimePicker = false;

  @override
  void initState() {
    super.initState();
    _selectedCategory = _categoryOptions.first;
    _titleController.addListener(_onFormChanged);
    _descriptionController.addListener(_onFormChanged);
    _customCategoryController.addListener(_onFormChanged);
  }

  @override
  void dispose() {
    _titleController.removeListener(_onFormChanged);
    _descriptionController.removeListener(_onFormChanged);
    _customCategoryController.removeListener(_onFormChanged);
    _titleController.dispose();
    _descriptionController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }

  void _onFormChanged() {
    setState(() {
      // This empty call is enough to trigger a rebuild for the live preview
    });
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      style: context.appStyle.bodyStyle.copyWith(color: Colors.white),
      maxLines: maxLines,
      validator: (value) {
        if (label == 'Task Title' && (value == null || value.isEmpty)) {
          return 'Please enter a title';
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: context.appStyle.bodyStyle.copyWith(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white30),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.appStyle.primaryColor),
        ),
      ),
    );
  }

  Widget _buildPrioritySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Priority',
          style: context.appStyle.bodyStyle
              .copyWith(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<TaskPriority>(
            segments: const [
              ButtonSegment(
                  value: TaskPriority.low,
                  label: Text('Low'),
                  icon: Icon(Icons.arrow_downward, size: 18)),
              ButtonSegment(
                  value: TaskPriority.medium,
                  label: Text('Medium'),
                  icon: Icon(Icons.remove, size: 18)),
              ButtonSegment(
                  value: TaskPriority.high,
                  label: Text('High'),
                  icon: Icon(Icons.arrow_upward, size: 18)),
            ],
            selected: {_selectedPriority},
            onSelectionChanged: (Set<TaskPriority> newSelection) {
              setState(() {
                _selectedPriority = newSelection.first;
              });
            },
            style: SegmentedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.1),
              foregroundColor: Colors.white70,
              selectedForegroundColor: Colors.white,
              selectedBackgroundColor:
                  _getPriorityColor(context, _selectedPriority).withOpacity(0.8),
              side: const BorderSide(color: Colors.white30),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category',
          style: context.appStyle.bodyStyle
              .copyWith(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedCategory,
          items: _categoryOptions
              .map((category) => DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  ))
              .toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedCategory = value;
              });
            }
          },
          style: context.appStyle.bodyStyle.copyWith(color: Colors.white),
          dropdownColor: context.appStyle.surfaceColor,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white30),
            ),
          ),
        ),
        if (_selectedCategory == 'Custom') ...[
          const SizedBox(height: 16),
          _buildTextField(
            controller: _customCategoryController,
            label: 'Custom Category Name',
          ),
        ],
      ],
    );
  }

  Color _getPriorityColor(BuildContext context, TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return context.appStyle.errorColor;
      case TaskPriority.medium:
        return context.appStyle.warningColor;
      case TaskPriority.low:
        return context.appStyle.successColor;
    }
  }

  void _togglePicker({bool isDate = true}) {
    setState(() {
      if (isDate) {
        _showTimePicker = false;
        _showDatePicker = !_showDatePicker;
      } else {
        _showDatePicker = false;
        _showTimePicker = !_showTimePicker;
      }
    });
  }

  Widget _buildDateTimePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Due Date',
          style: context.appStyle.bodyStyle
              .copyWith(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: _buildPickerButton(
                text: DateFormat('d MMM yyyy').format(_dueDate),
                isActive: _showDatePicker,
                onPressed: () => _togglePicker(isDate: true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: _buildPickerButton(
                text: DateFormat.Hm().format(_dueDate),
                isActive: _showTimePicker,
                onPressed: () => _togglePicker(isDate: false),
              ),
            ),
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: Column(
            children: [
              if (_showDatePicker) _buildInlineDatePicker(),
              if (_showTimePicker) _buildInlineTimePicker(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPickerButton({
    required String text,
    required bool isActive,
    required VoidCallback onPressed,
  }) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: isActive
            ? context.appStyle.primaryColor.withOpacity(0.8)
            : Colors.white.withOpacity(0.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 12),
        minimumSize: const Size(double.infinity, 50),
      ),
      child: Text(
        text,
        style: context.appStyle.bodyStyle.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildInlineDatePicker() {
    return TableCalendar(
      firstDay: DateTime.utc(2020),
      lastDay: DateTime.utc(2030),
      focusedDay: _dueDate,
      selectedDayPredicate: (day) => isSameDay(day, _dueDate),
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _dueDate = DateTime(
            selectedDay.year,
            selectedDay.month,
            selectedDay.day,
            _dueDate.hour,
            _dueDate.minute,
          );
          _togglePicker(isDate: true); // Close picker after selection
        });
      },
      calendarStyle: CalendarStyle(
        defaultTextStyle: const TextStyle(color: Colors.white),
        weekendTextStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
        outsideTextStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
        selectedDecoration: BoxDecoration(
          color: context.appStyle.primaryColor,
          shape: BoxShape.circle,
        ),
        todayDecoration: BoxDecoration(
          color: Colors.white.withOpacity(0.3),
          shape: BoxShape.circle,
        ),
      ),
      headerStyle: HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextStyle: context.appStyle.headingStyle.copyWith(fontSize: 16),
        leftChevronIcon: const Icon(Icons.chevron_left, color: Colors.white),
        rightChevronIcon: const Icon(Icons.chevron_right, color: Colors.white),
      ),
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: const TextStyle(color: Colors.white70),
        weekendStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
      ),
    );
  }

  Widget _buildInlineTimePicker() {
    final hourController = FixedExtentScrollController(
      initialItem: _dueDate.hour,
    );
    final minuteController = FixedExtentScrollController(
      initialItem: _dueDate.minute,
    );

    return SizedBox(
      height: 150,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildTimePickerWheel(
            controller: hourController,
            itemCount: 24,
            onChanged: (hour) => _updateTime(hour: hour),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(':', style: context.appStyle.headingStyle),
          ),
          _buildTimePickerWheel(
            controller: minuteController,
            itemCount: 60,
            onChanged: (minute) => _updateTime(minute: minute),
          ),
        ],
      ),
    );
  }

  Widget _buildTimePickerWheel({
    required FixedExtentScrollController controller,
    required int itemCount,
    required ValueChanged<int> onChanged,
  }) {
    return Expanded(
      child: CupertinoPicker(
        scrollController: controller,
        itemExtent: 40,
        onSelectedItemChanged: onChanged,
        looping: true,
        selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
          background: context.appStyle.primaryColor.withOpacity(0.2),
        ),
        children: List<Widget>.generate(
          itemCount,
          (index) => Center(
            child: Text(
              index.toString().padLeft(2, '0'),
              style: context.appStyle.bodyStyle.copyWith(fontSize: 20, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  void _updateTime({int? hour, int? minute}) {
    setState(() {
      _dueDate = DateTime(
        _dueDate.year,
        _dueDate.month,
        _dueDate.day,
        hour ?? _dueDate.hour,
        minute ?? _dueDate.minute,
      );
    });
  }

  Widget _buildLivePreview() {
    final previewTask = Task(
      title: _titleController.text.isEmpty
          ? "Your New Task"
          : _titleController.text,
      description: _descriptionController.text,
      priority: _selectedPriority,
      dueDate: _dueDate,
      category: _selectedCategory == 'Custom'
          ? _customCategoryController.text
          : _selectedCategory,
      userId: '', // Dummy data
      createdAt: DateTime.now(), // Dummy data
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Live Preview',
          style: context.appStyle.bodyStyle
              .copyWith(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TaskCard(
          title: previewTask.title,
          description: previewTask.description,
          isCompleted: false,
          onToggle: null, // Not interactive
          trailingWidget: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                previewTask.dueDateText,
                style: context.appStyle.bodyStyle,
              ),
              const SizedBox(height: 4),
              if (previewTask.priority == TaskPriority.high) PriorityTag.high(),
              if (previewTask.priority == TaskPriority.medium)
                PriorityTag.medium(),
              if (previewTask.priority == TaskPriority.low) PriorityTag.low(),
            ],
          ),
        ),
      ],
    );
  }

  void _saveTask() async {
    if (_formKey.currentState!.validate()) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in to add a task.')),
        );
        return;
      }

      final newTask = Task(
        title: _titleController.text,
        description: _descriptionController.text,
        priority: _selectedPriority,
        dueDate: _dueDate,
        category: _selectedCategory == 'Custom'
            ? _customCategoryController.text
            : _selectedCategory,
        userId: user.uid,
        createdAt: DateTime.now(),
      );

      try {
        await context.read<TaskState>().addTask(newTask);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Task saved successfully!')),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save task: $e')),
          );
        }
      }
    }
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: AppButton(
            text: 'Cancel',
            onPressed: () => Navigator.of(context).pop(),
            type: AppButtonType.outlined,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: BouncyButton(
            onPressed: _saveTask,
            child: AppButton(
              text: 'Save Task',
              onPressed: _saveTask,
              type: AppButtonType.primary,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundImageContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            'Add New Task',
            style: context.appStyle.headingStyle,
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildTextField(
                controller: _titleController,
                label: 'Task Title',
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _descriptionController,
                label: 'Description (Optional)',
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              _buildPrioritySelector(),
              const SizedBox(height: 24),
              _buildCategorySelector(),
              const SizedBox(height: 24),
              _buildDateTimePicker(),
              const SizedBox(height: 32),
              const Divider(color: Colors.white30),
              const SizedBox(height: 16),
              _buildLivePreview(),
              const SizedBox(height: 24),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }
}
