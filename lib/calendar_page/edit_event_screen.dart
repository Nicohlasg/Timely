import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/calendar_event.dart';
import '../state/calendar_state.dart';
import '../widgets/delete_event_dialog.dart';
import '../widgets/edit_recurring_event_dialog.dart';
import '../widgets/background_container.dart';

class EditEventScreen extends StatefulWidget {
  final CalendarEvent event;
  final CalendarEvent? masterEvent;

  const EditEventScreen({
    super.key,
    required this.event,
    this.masterEvent,
  });

  @override
  _EditEventScreenState createState() => _EditEventScreenState();
}

class _EditEventScreenState extends State<EditEventScreen> {
  late CalendarEvent _event;
  late TextEditingController _titleController;
  late TextEditingController _locationController;
  late FocusNode _titleFocusNode;

  late DateTime _startDate;
  late DateTime _endDate;
  late bool _allDay;
  late Color _color;
  late RepeatRule _repeatRule;
  late DateTime? _repeatUntil;

  bool _showStartDatePicker = false;
  bool _showStartTimePicker = false;
  bool _showEndDatePicker = false;
  bool _showEndTimePicker = false;
  bool _showRepeatUntilDatePicker = false;
  bool _showColorPicker = false;

  final List<List<Color>> _colorPalette = [
    [
      const Color(0xFFFFCDD2),
      const Color(0xFFFFE0B2),
      const Color(0xFFFFF9C4),
      const Color(0xFFC8E6C9),
      const Color(0xFFB3E5FC),
      const Color(0xFFC5CAE9),
      const Color(0xFFE1BEE7),
    ],
    [
      const Color(0xFFEF9A9A),
      const Color(0xFFFFCC80),
      const Color(0xFFFFF59D),
      const Color(0xFFA5D6A7),
      const Color(0xFF81D4FA),
      const Color(0xFF9FA8DA),
      const Color(0xFFCE93D8),
    ],
    [
      const Color(0xFFE57373),
      const Color(0xFFFFB74D),
      const Color(0xFFFFF176),
      const Color(0xFF81C784),
      const Color(0xFF4FC3F7),
      const Color(0xFF7986CB),
      const Color(0xFFBA68C8),
    ],
    [
      const Color(0xFFEF5350),
      const Color(0xFFFFA726),
      const Color(0xFFFFEE58),
      const Color(0xFF66BB6A),
      const Color(0xFF29B6F6),
      const Color(0xFF5C6BC0),
      const Color(0xFFAB47BC),
    ],
    [
      const Color(0xFFD32F2F),
      const Color(0xFFF57C00),
      const Color(0xFFFBC02D),
      const Color(0xFF388E3C),
      const Color(0xFF0288D1),
      const Color(0xFF303F9F),
      const Color(0xFF8E24AA),
    ],
  ];

  @override
  void initState() {
    super.initState();
    _event = widget.event;
    _titleController = TextEditingController(text: _event.title);
    _locationController = TextEditingController(text: _event.location);
    _startDate = _event.start;
    _endDate = _event.end;
    _allDay = _event.allDay;
    _color = _event.color;
    _repeatRule = _event.repeatRule;
    _repeatUntil = _event.repeatUntil;
    _titleFocusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_event.title.isEmpty) {
        FocusScope.of(context).requestFocus(_titleFocusNode);
      }
    });
  }

  void _saveEvent() async {
    final calendarState = context.read<CalendarState>();
    DateTime finalStartDate = _startDate;
    DateTime finalEndDate = _endDate;

    if (_allDay) {
      finalStartDate = DateTime(
          finalStartDate.year, finalStartDate.month, finalStartDate.day);
      finalEndDate = DateTime(
          finalEndDate.year, finalEndDate.month, finalEndDate.day, 23, 59);
    }

    final isNewEvent = widget.event.id.isEmpty;
    final isEditingRecurring = widget.masterEvent != null &&
        widget.masterEvent!.repeatRule != RepeatRule.never;

    if (isEditingRecurring) {
      final editScope = await showDialog<EditScope>(
        context: context,
        builder: (context) => EditRecurringEventDialog(
          onConfirm: (scope) => Navigator.of(context).pop(scope),
        ),
      );

      if (editScope == null) return;

      if (editScope == EditScope.allEvents) {
        final masterEvent = widget.masterEvent!;
        final updatedMasterEvent = masterEvent.copyWith(
          title: _titleController.text.isNotEmpty
              ? _titleController.text
              : "Untitled Event",
          location: _locationController.text,
          start: DateTime(
              masterEvent.start.year,
              masterEvent.start.month,
              masterEvent.start.day,
              finalStartDate.hour,
              finalStartDate.minute),
          end: DateTime(masterEvent.start.year, masterEvent.start.month,
              masterEvent.start.day, finalEndDate.hour, finalEndDate.minute),
          allDay: _allDay,
          color: _color,
          repeatRule: _repeatRule,
          repeatUntil: _repeatRule == RepeatRule.never ? null : _repeatUntil,
          clearRepeatUntil: _repeatRule == RepeatRule.never,
        );
        await calendarState.updateEvent(updatedMasterEvent);
      } else {
        final newSingleEvent = CalendarEvent(
          title: _titleController.text.isNotEmpty
              ? _titleController.text
              : "Untitled Event",
          location: _locationController.text,
          start: finalStartDate,
          end: finalEndDate,
          allDay: _allDay,
          color: _color,
          repeatRule: RepeatRule.never,
          userId: calendarState.currentUserId ?? '',
        );
        await calendarState.updateSingleOccurrence(
          masterEvent: widget.masterEvent!,
          occurrenceDate: widget.event.start,
          updatedEvent: newSingleEvent,
        );
      }
    } else {
      final eventToSave = widget.event.copyWith(
        title: _titleController.text.isNotEmpty
            ? _titleController.text
            : "Untitled Event",
        location: _locationController.text,
        start: finalStartDate,
        end: finalEndDate,
        allDay: _allDay,
        color: _color,
        repeatRule: _repeatRule,
        repeatUntil: _repeatRule == RepeatRule.never ? null : _repeatUntil,
        clearRepeatUntil: _repeatRule == RepeatRule.never,
        userId: calendarState.currentUserId,
      );

      if (isNewEvent) {
        await calendarState.addEvent(eventToSave);
      } else {
        await calendarState.updateEvent(eventToSave);
      }
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _togglePicker({
    String type = 'start',
    bool isDate = true,
  }) {
    setState(() {
      bool shouldOpen = true;

      if (type == 'start' && isDate) {
        shouldOpen = !_showStartDatePicker;
        _showStartDatePicker = false;
        _showStartTimePicker = false;
        _showEndDatePicker = false;
        _showEndTimePicker = false;
        _showRepeatUntilDatePicker = false;
        _showStartDatePicker = shouldOpen;
      } else if (type == 'start' && !isDate) {
        shouldOpen = !_showStartTimePicker;
        _showStartDatePicker = false;
        _showStartTimePicker = false;
        _showEndDatePicker = false;
        _showEndTimePicker = false;
        _showRepeatUntilDatePicker = false;
        _showStartTimePicker = shouldOpen;
      } else if (type == 'end' && isDate) {
        shouldOpen = !_showEndDatePicker;
        _showStartDatePicker = false;
        _showStartTimePicker = false;
        _showEndDatePicker = false;
        _showEndTimePicker = false;
        _showRepeatUntilDatePicker = false;
        _showEndDatePicker = shouldOpen;
      } else if (type == 'end' && !isDate) {
        shouldOpen = !_showEndTimePicker;
        _showStartDatePicker = false;
        _showStartTimePicker = false;
        _showEndDatePicker = false;
        _showEndTimePicker = false;
        _showRepeatUntilDatePicker = false;
        _showEndTimePicker = shouldOpen;
      } else if (type == 'repeatUntil' && isDate) {
        shouldOpen = !_showRepeatUntilDatePicker;
        _showStartDatePicker = false;
        _showStartTimePicker = false;
        _showEndDatePicker = false;
        _showEndTimePicker = false;
        _showRepeatUntilDatePicker = false;
        _showRepeatUntilDatePicker = shouldOpen;
      }
    });
  }

  Future<void> _showDeleteDialog() async {
    final calendarState = context.read<CalendarState>();
    final masterEvent = widget.masterEvent ?? _event;
    final isRecurring = masterEvent.repeatRule != RepeatRule.never;

    await showDialog(
      context: context,
      builder: (context) => DeleteEventDialog(
        event: _event,
        masterEvent: masterEvent,
        isRecurring: isRecurring,
        onDelete: (deleteOption) async {
          Navigator.of(context).pop();

          switch (deleteOption) {
            case 'this':
              await calendarState.deleteSingleOccurrence(
                masterEvent,
                _event.start,
              );
              break;
            case 'following':
              await calendarState.deleteThisAndFollowing(
                masterEvent,
                _event.start,
              );
              break;
            case 'all':
              await calendarState.deleteEvent(masterEvent.id);
              break;
          }

          if (mounted) {
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundImageContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            if (widget.event.id.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: _showDeleteDialog,
              ),
            TextButton(
              onPressed: () {
                _saveEvent();
              },
              child: Text(
                'Save',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              const SizedBox(height: 16),
              _buildGlassmorphicContainer(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: _buildGlassmorphicTextField(
                        controller: _titleController,
                        hintText: 'Add Title',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: Colors.white30),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: _buildGlassmorphicTextField(
                        controller: _locationController,
                        hintText: 'Add location',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildGlassmorphicContainer(
                child: Column(
                  children: [
                    _buildAllDaySwitch(),
                    const Divider(height: 1, color: Colors.white30),
                    _buildDateTimeRow(type: 'start'),
                    const Divider(height: 1, color: Colors.white30),
                    _buildDateTimeRow(type: 'end'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildGlassmorphicContainer(
                child: Column(
                  children: [
                    _buildRepeatRow(),
                    if (_repeatRule != RepeatRule.never) ...[
                      const Divider(height: 1, color: Colors.white30),
                      _buildDateTimeRow(type: 'repeatUntil'),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildGlassmorphicContainer(child: _buildColorSelector()),
              const SizedBox(height: 24),
              if (widget.event.id.isNotEmpty)
                Center(
                  child: TextButton.icon(
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete Event'),
                    onPressed: () => _showDeleteDialog(),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red.shade300,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassmorphicContainer({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white30),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildAllDaySwitch() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'All-day',
            style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
          ),
          Switch(
            value: _allDay,
            onChanged: (value) => setState(() {
              _allDay = value;
              if (_allDay) {
                _showStartTimePicker = false;
                _showEndTimePicker = false;
              }
            }),
            activeThumbColor: Colors.blue,
            activeTrackColor: Colors.blue.withValues(alpha: 0.5),
            inactiveThumbColor: Colors.white70,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimeRow({required String type}) {
    DateTime dateTime;
    bool showDatePicker, showTimePicker;
    String label;

    switch (type) {
      case 'start':
        dateTime = _startDate;
        showDatePicker = _showStartDatePicker;
        showTimePicker = _showStartTimePicker;
        label = 'Starts';
        break;
      case 'end':
        dateTime = _endDate;
        showDatePicker = _showEndDatePicker;
        showTimePicker = _showEndTimePicker;
        label = 'Ends';
        break;
      case 'repeatUntil':
        dateTime = _repeatUntil ?? DateTime.now().add(const Duration(days: 30));
        showDatePicker = _showRepeatUntilDatePicker;
        showTimePicker = false;
        label = 'Ends Repeat';
        break;
      default:
        return const SizedBox.shrink();
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  label,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
                ),
              ),
              Expanded(
                flex: 4,
                child: _buildPickerButton(
                  text: DateFormat('d MMM yyyy').format(dateTime),
                  isActive: showDatePicker,
                  onPressed: () => _togglePicker(type: type, isDate: true),
                ),
              ),
              if (type != 'repeatUntil' && !_allDay) ...[
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: _buildPickerButton(
                    text: DateFormat.Hm().format(dateTime),
                    isActive: showTimePicker,
                    onPressed: () => _togglePicker(type: type, isDate: false),
                  ),
                ),
              ] else
                const Expanded(flex: 3, child: SizedBox()),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: Column(
            children: [
              if (showDatePicker) _buildInlineDatePicker(type: type),
              if (!_allDay && showTimePicker)
                _buildInlineTimePicker(type: type),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRepeatRow() {
    return InkWell(
      onTap: _showRepeatRuleDialog,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Repeat',
              style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
            ),
            Row(
              children: [
                Text(
                  _getRepeatRuleDisplayName(_repeatRule),
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: Colors.white70),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorSelector() {
    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _showColorPicker = !_showColorPicker;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Color',
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
                ),
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: _color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white70),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      _showColorPicker
                          ? Icons.arrow_drop_up
                          : Icons.arrow_drop_down,
                      color: Colors.white70,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: SizedBox(
            height: _showColorPicker ? null : 0,
            child: Column(
              children: [
                const Divider(height: 1, color: Colors.white30),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: _colorPalette.expand((row) => row).map((color) {
                      bool isSelected = _color.toARGB32() == color.toARGB32();
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _color = color;
                            _showColorPicker = false;
                          });
                        },
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: Colors.white, width: 2.5)
                                : Border.all(
                                    color: Colors.white.withValues(alpha: 0.5),
                                  ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 20,
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showRepeatRuleDialog() async {
    final result = await showModalBottomSheet<RepeatRule>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2D3748).withValues(alpha: 0.9),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              border: const Border(top: BorderSide(color: Colors.white30)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Repeat Event',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Divider(color: Colors.white30, height: 1),
                  ...RepeatRule.values.map(
                    (rule) => RadioListTile<RepeatRule>(
                      title: Text(
                        _getRepeatRuleDisplayName(rule),
                        style: GoogleFonts.inter(color: Colors.white),
                      ),
                      value: rule,
                      groupValue: _repeatRule,
                      onChanged: (value) => Navigator.of(context).pop(value),
                      activeColor: Colors.blue,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (result != null) {
      setState(() {
        _repeatRule = result;
        if (result != RepeatRule.never && _repeatUntil == null) {
          _repeatUntil = DateTime.now().add(const Duration(days: 30));
        }
      });
    }
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
            ? Colors.blue.withValues(alpha: 0.8)
            : Colors.white.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 8),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildInlineDatePicker({required String type}) {
    DateTime dateTime;
    if (type == 'start') {
      dateTime = _startDate;
    } else if (type == 'end') {
      dateTime = _endDate;
    } else {
      dateTime = _repeatUntil ?? DateTime.now();
    }

    return TableCalendar(
      firstDay: DateTime.utc(2020),
      lastDay: DateTime.utc(2030),
      focusedDay: dateTime,
      selectedDayPredicate: (day) => isSameDay(day, dateTime),
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          DateTime newDate = DateTime(
            selectedDay.year,
            selectedDay.month,
            selectedDay.day,
            dateTime.hour,
            dateTime.minute,
          );
          if (type == 'start') {
            _startDate = newDate;
            if (_endDate.isBefore(_startDate)) {
              _endDate = _startDate.add(const Duration(hours: 1));
            }
          } else if (type == 'end') {
            _endDate = newDate;
            if (_endDate.isBefore(_startDate)) {
              _startDate = _endDate.subtract(const Duration(hours: 1));
            }
          } else {
            _repeatUntil = newDate;
          }
          _togglePicker(type: type, isDate: true);
        });
      },
      calendarStyle: CalendarStyle(
        defaultTextStyle: const TextStyle(color: Colors.white),
        weekendTextStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        outsideTextStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
        selectedDecoration: const BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
        ),
        todayDecoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
      ),
      headerStyle: HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextStyle: GoogleFonts.inter(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        leftChevronIcon: const Icon(Icons.chevron_left, color: Colors.white),
        rightChevronIcon: const Icon(Icons.chevron_right, color: Colors.white),
      ),
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: const TextStyle(color: Colors.white70),
        weekendStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
      ),
    );
  }

  Widget _buildInlineTimePicker({required String type}) {
    DateTime dateTime = type == 'start' ? _startDate : _endDate;
    int currentHour = dateTime.hour;
    int currentMinute = dateTime.minute;

    final hourController = FixedExtentScrollController(
      initialItem: currentHour,
    );
    final minuteController = FixedExtentScrollController(
      initialItem: currentMinute,
    );

    return SizedBox(
      height: 150,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: _buildTimePickerWheel(
              controller: hourController,
              itemCount: 24,
              itemBuilder: (index) => index.toString().padLeft(2, '0'),
              onChanged: (index) =>
                  _updateTime(isStart: type == 'start', hour: index),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                ':',
                style: GoogleFonts.inter(color: Colors.white, fontSize: 24),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: _buildTimePickerWheel(
              controller: minuteController,
              itemCount: 60,
              itemBuilder: (index) => index.toString().padLeft(2, '0'),
              onChanged: (index) =>
                  _updateTime(isStart: type == 'start', minute: index),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimePickerWheel({
    required FixedExtentScrollController controller,
    required int itemCount,
    required String Function(int) itemBuilder,
    required ValueChanged<int> onChanged,
  }) {
    return Expanded(
      child: CupertinoPicker(
        scrollController: controller,
        itemExtent: 40,
        onSelectedItemChanged: onChanged,
        looping: true,
        children: List<Widget>.generate(
          itemCount,
          (index) => Center(
            child: Text(
              itemBuilder(index),
              style: GoogleFonts.inter(color: Colors.white, fontSize: 20),
            ),
          ),
        ),
      ),
    );
  }

  void _updateTime({required bool isStart, int? hour, int? minute}) {
    setState(() {
      DateTime current = isStart ? _startDate : _endDate;
      DateTime newDateTime = DateTime(
        current.year,
        current.month,
        current.day,
        hour ?? current.hour,
        minute ?? current.minute,
      );
      if (isStart) {
        _startDate = newDateTime;
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate.add(const Duration(hours: 1));
        }
      } else {
        _endDate = newDateTime;
        if (_endDate.isBefore(_startDate)) {
          _startDate = _endDate.subtract(const Duration(hours: 1));
        }
      }
    });
  }

  Widget _buildGlassmorphicTextField({
    required TextEditingController controller,
    required String hintText,
    TextStyle? style,
  }) {
    return TextField(
      controller: controller,
      style: style ?? GoogleFonts.inter(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.inter(
          color: Colors.white.withValues(alpha: 0.7),
          fontSize: style?.fontSize,
        ),
        border: InputBorder.none,
      ),
    );
  }

  String _getRepeatRuleDisplayName(RepeatRule rule) {
    switch (rule) {
      case RepeatRule.never:
        return 'Never';
      case RepeatRule.daily:
        return 'Daily';
      case RepeatRule.weekly:
        return 'Weekly';
      case RepeatRule.everyTwoWeeks:
        return 'Every two weeks';
      case RepeatRule.monthly:
        return 'Monthly';
      case RepeatRule.yearly:
        return 'Yearly';
    }
  }
}
