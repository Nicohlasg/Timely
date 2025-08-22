import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter/cupertino.dart';
import '../models/calendar_event.dart';
import '../models/user_profile_data.dart';
import '../services/firebase_friend_service.dart';
import '../widgets/background_container.dart';
import '../widgets/conflict_dialog.dart';

// NOTE: This UI is heavily based on EditEventScreen.
// In a future refactor, you could extract the form into a shared widget.
class ProposeEventPage extends StatefulWidget {
  final UserProfileData recipientProfile;
  const ProposeEventPage({super.key, required this.recipientProfile});

  @override
  State<ProposeEventPage> createState() => _ProposeEventPageState();
}

class _ProposeEventPageState extends State<ProposeEventPage> {
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  var _startDate = DateTime.now().add(const Duration(hours: 1));
  var _endDate = DateTime.now().add(const Duration(hours: 2));
  bool _isProposing = false;
  bool _allDay = false;

  // Inline expanding pickers (same UX as EditEventScreen)
  bool _showStartDatePicker = false;
  bool _showStartTimePicker = false;
  bool _showEndDatePicker = false;
  bool _showEndTimePicker = false;

  Future<void> _proposeEvent() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title for the proposal.')),
      );
      return;
    }

    setState(() => _isProposing = true);

    final eventToPropose = CalendarEvent(
      title: _titleController.text,
      location: _locationController.text,
      start: _startDate,
      end: _endDate,
    );
    
    // In a real app, inject this service via Provider
    final service = FirebaseFriendService();
    final result = await service.proposeEvent(
      recipientId: widget.recipientProfile.uid,
      event: eventToPropose,
    );

    if (!mounted) return;
    setState(() => _isProposing = false);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Proposal sent to ${widget.recipientProfile.firstName}!')),
      );
      Navigator.of(context).pop();
    } else {
      if (result['reason'] == 'conflict') {
        showDialog(
          context: context,
          builder: (context) => ConflictDialog(
            conflictingEventTitle: result['conflictingEventTitle'] ?? 'an existing event',
          ),
        );
      } else {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send proposal: ${result['reason']}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundImageContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Propose to ${widget.recipientProfile.firstName}', style: GoogleFonts.inter()),
          actions: [
            _isProposing
                ? const Padding(padding: EdgeInsets.all(16.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                : TextButton(
                    onPressed: _proposeEvent,
                    child: Text('Propose', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Simplified form for proposal
             _buildGlassmorphicContainer(
                child: Column(
                  children: [
                     Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: TextField(
                        controller: _titleController,
                        autofocus: true,
                        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        decoration: InputDecoration(hintText: 'Proposal Title', hintStyle: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.7)), border: InputBorder.none),
                      ),
                    ),
                    const Divider(height: 1, color: Colors.white30),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: TextField(
                        controller: _locationController,
                         style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
                        decoration: InputDecoration(hintText: 'Add location', hintStyle: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.7)), border: InputBorder.none),
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
              )
          ],
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
          const Text('All-day', style: TextStyle(color: Colors.white, fontSize: 16)),
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
          ),
        ],
      ),
    );
  }

  void _togglePicker({required String type, required bool isDate}) {
    setState(() {
      bool shouldOpen;
      if (type == 'start' && isDate) {
        shouldOpen = !_showStartDatePicker;
        _showStartDatePicker = false;
        _showStartTimePicker = false;
        _showEndDatePicker = false;
        _showEndTimePicker = false;
        _showStartDatePicker = shouldOpen;
      } else if (type == 'start' && !isDate) {
        shouldOpen = !_showStartTimePicker;
        _showStartDatePicker = false;
        _showStartTimePicker = false;
        _showEndDatePicker = false;
        _showEndTimePicker = false;
        _showStartTimePicker = shouldOpen;
      } else if (type == 'end' && isDate) {
        shouldOpen = !_showEndDatePicker;
        _showStartDatePicker = false;
        _showStartTimePicker = false;
        _showEndDatePicker = false;
        _showEndTimePicker = false;
        _showEndDatePicker = shouldOpen;
      } else {
        shouldOpen = !_showEndTimePicker;
        _showStartDatePicker = false;
        _showStartTimePicker = false;
        _showEndDatePicker = false;
        _showEndTimePicker = false;
        _showEndTimePicker = shouldOpen;
      }
    });
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
      default:
        dateTime = _endDate;
        showDatePicker = _showEndDatePicker;
        showTimePicker = _showEndTimePicker;
        label = 'Ends';
        break;
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 16)),
              ),
              Expanded(
                flex: 4,
                child: _buildPickerButton(
                  text: DateFormat('d MMM yyyy').format(dateTime),
                  isActive: showDatePicker,
                  onPressed: () => _togglePicker(type: type, isDate: true),
                ),
              ),
              if (!_allDay) ...[
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
              if (!_allDay && showTimePicker) _buildInlineTimePicker(type: type),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPickerButton({required String text, required bool isActive, required VoidCallback onPressed}) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: isActive ? Colors.blue.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 8),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildInlineDatePicker({required String type}) {
    final dateTime = type == 'start' ? _startDate : _endDate;
    return TableCalendar(
      firstDay: DateTime.utc(2020),
      lastDay: DateTime.utc(2035),
      focusedDay: dateTime,
      selectedDayPredicate: (day) => isSameDay(day, dateTime),
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          final newDate = DateTime(selectedDay.year, selectedDay.month, selectedDay.day, dateTime.hour, dateTime.minute);
          if (type == 'start') {
            _startDate = newDate;
            if (_endDate.isBefore(_startDate)) {
              _endDate = _startDate.add(const Duration(hours: 1));
            }
          } else {
            _endDate = newDate;
            if (_endDate.isBefore(_startDate)) {
              _startDate = _endDate.subtract(const Duration(hours: 1));
            }
          }
          _togglePicker(type: type, isDate: true);
        });
      },
      calendarStyle: CalendarStyle(
        defaultTextStyle: const TextStyle(color: Colors.white),
        weekendTextStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        outsideTextStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
        selectedDecoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
        todayDecoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.3), shape: BoxShape.circle),
      ),
      headerStyle: HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        leftChevronIcon: const Icon(Icons.chevron_left, color: Colors.white),
        rightChevronIcon: const Icon(Icons.chevron_right, color: Colors.white),
      ),
      daysOfWeekStyle: const DaysOfWeekStyle(
        weekdayStyle: TextStyle(color: Colors.white70),
        weekendStyle: TextStyle(color: Colors.white70),
      ),
    );
  }

  Widget _buildInlineTimePicker({required String type}) {
    final dateTime = type == 'start' ? _startDate : _endDate;
    final hourController = FixedExtentScrollController(initialItem: dateTime.hour);
    final minuteController = FixedExtentScrollController(initialItem: dateTime.minute);

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
              onChanged: (index) => _updateTime(isStart: type == 'start', hour: index),
            ),
          ),
          const Expanded(child: Center(child: Text(':', style: TextStyle(color: Colors.white, fontSize: 24)))),
          Expanded(
            flex: 2,
            child: _buildTimePickerWheel(
              controller: minuteController,
              itemCount: 60,
              itemBuilder: (index) => index.toString().padLeft(2, '0'),
              onChanged: (index) => _updateTime(isStart: type == 'start', minute: index),
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
            child: Text(itemBuilder(index), style: const TextStyle(color: Colors.white, fontSize: 20)),
          ),
        ),
      ),
    );
  }

  void _updateTime({required bool isStart, int? hour, int? minute}) {
    setState(() {
      final current = isStart ? _startDate : _endDate;
      final newDateTime = DateTime(
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
}