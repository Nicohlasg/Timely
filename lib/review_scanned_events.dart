import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'models/calendar_event.dart';
import 'state/calendar_state.dart';

class ReviewScannedEventsPage extends StatefulWidget {
  final List<CalendarEvent> scannedEvents;
  const ReviewScannedEventsPage({super.key, required this.scannedEvents});

  @override
  State<ReviewScannedEventsPage> createState() =>
      _ReviewScannedEventsPageState();
}

class _ReviewScannedEventsPageState extends State<ReviewScannedEventsPage> {
  late List<CalendarEvent> _editableEvents;
  late List<CalendarEvent> _filteredEvents;
  late Set<int> _selectedIndices;
  late Map<int, Color> _eventColors;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<Color> _availableColors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.red,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
    Colors.amber,
    Colors.cyan,
    Colors.lime,
    Colors.deepOrange,
  ];

  @override
  void initState() {
    super.initState();
    _editableEvents = List.from(widget.scannedEvents);
    _filteredEvents = List.from(_editableEvents);
    _selectedIndices = List.generate(
      _editableEvents.length,
      (index) => index,
    ).toSet();
    _assignColors();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _filteredEvents = _editableEvents.where((event) {
        return event.title.toLowerCase().contains(_searchQuery) ||
            event.location.toLowerCase().contains(_searchQuery) ||
            DateFormat.yMMMd()
                .format(event.start)
                .toLowerCase()
                .contains(_searchQuery);
      }).toList();
    });
  }

  void _assignColors() {
    _eventColors = {};
    for (int i = 0; i < _editableEvents.length; i++) {
      _eventColors[i] = _availableColors[i % _availableColors.length];
      _editableEvents[i] = _editableEvents[i].copyWith(color: _eventColors[i]);
    }
  }

  void _editEvent(int originalIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _EventDetailEditor(
          event: _editableEvents[originalIndex],
          onSave: (updatedEvent) {
            setState(() {
              _editableEvents[originalIndex] = updatedEvent;
              _onSearchChanged();
            });
          },
        ),
        fullscreenDialog: true,
      ),
    );
  }

  void _proceedToRecurrenceSettings() {
    final selectedEvents = _selectedIndices
        .map((index) => _editableEvents[index])
        .toList();

    if (selectedEvents.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RecurrenceGroupingPage(events: selectedEvents),
          fullscreenDialog: true,
        ),
      );
    }
  }

  int _getOriginalIndex(CalendarEvent event) {
    return _editableEvents.indexWhere(
      (e) =>
          e.start == event.start &&
          e.title == event.title &&
          e.location == event.location,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Review Scanned Events',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ElevatedButton(
              onPressed: _selectedIndices.isNotEmpty
                  ? _proceedToRecurrenceSettings
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                'Next (${_selectedIndices.length})',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/img/background.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.black.withValues(alpha: 0.1)),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white30),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: GoogleFonts.inter(color: Colors.white),
                      decoration: InputDecoration(
                        hintText:
                            'Search events by title, location, or date...',
                        hintStyle: GoogleFonts.inter(color: Colors.white54),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.white70,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.clear,
                                  color: Colors.white70,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Found ${_filteredEvents.length} event(s)',
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredEvents.length,
                    itemBuilder: (context, index) {
                      final event = _filteredEvents[index];
                      final originalIndex = _getOriginalIndex(event);
                      final isSelected = _selectedIndices.contains(
                        originalIndex,
                      );

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white30),
                        ),
                        child: ListTile(
                          leading: Checkbox(
                            value: isSelected,
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  _selectedIndices.add(originalIndex);
                                } else {
                                  _selectedIndices.remove(originalIndex);
                                }
                              });
                            },
                            activeColor: Colors.blue,
                          ),
                          title: RichText(
                            text: TextSpan(
                              children: _highlightSearchText(
                                event.title.isNotEmpty
                                    ? event.title
                                    : 'Untitled Event',
                                _searchQuery,
                              ),
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              RichText(
                                text: TextSpan(
                                  children: _highlightSearchText(
                                    DateFormat.yMMMd().format(event.start),
                                    _searchQuery,
                                  ),
                                ),
                              ),
                              Text(
                                '${DateFormat.jm().format(event.start)} - ${DateFormat.jm().format(event.end)}',
                                style: GoogleFonts.inter(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                              if (event.location.isNotEmpty)
                                RichText(
                                  text: TextSpan(
                                    children: _highlightSearchText(
                                      event.location,
                                      _searchQuery,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: _eventColors[originalIndex],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.white70,
                                ),
                                onPressed: () => _editEvent(originalIndex),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<TextSpan> _highlightSearchText(String text, String query) {
    if (query.isEmpty) {
      return [
        TextSpan(
          text: text,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ];
    }

    final List<TextSpan> spans = [];
    final String lowerText = text.toLowerCase();
    final String lowerQuery = query.toLowerCase();

    int start = 0;
    int index = lowerText.indexOf(lowerQuery, start);

    while (index != -1) {
      if (index > start) {
        spans.add(
          TextSpan(
            text: text.substring(start, index),
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        );
      }

      spans.add(
        TextSpan(
          text: text.substring(index, index + query.length),
          style: GoogleFonts.inter(
            color: Colors.yellow,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            backgroundColor: Colors.yellow.withValues(alpha: 0.3),
          ),
        ),
      );

      start = index + query.length;
      index = lowerText.indexOf(lowerQuery, start);
    }

    if (start < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(start),
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      );
    }

    return spans;
  }
}

class _EventDetailEditor extends StatefulWidget {
  final CalendarEvent event;
  final Function(CalendarEvent) onSave;

  const _EventDetailEditor({required this.event, required this.onSave});

  @override
  State<_EventDetailEditor> createState() => _EventDetailEditorState();
}

class _EventDetailEditorState extends State<_EventDetailEditor> {
  late TextEditingController _titleController;
  late TextEditingController _locationController;
  late DateTime _startDate;
  late DateTime _endDate;

  bool _showStartDatePicker = false;
  bool _showStartTimePicker = false;
  bool _showEndDatePicker = false;
  bool _showEndTimePicker = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.event.title);
    _locationController = TextEditingController(text: widget.event.location);
    _startDate = widget.event.start;
    _endDate = widget.event.end;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _saveEvent() {
    final updatedEvent = widget.event.copyWith(
      title: _titleController.text.isNotEmpty
          ? _titleController.text
          : 'Untitled Event',
      location: _locationController.text,
      start: _startDate,
      end: _endDate,
    );

    widget.onSave(updatedEvent);
    Navigator.of(context).pop();
  }

  void _togglePicker({String type = 'start', bool isDate = true}) {
    setState(() {
      _showStartDatePicker = false;
      _showStartTimePicker = false;
      _showEndDatePicker = false;
      _showEndTimePicker = false;

      if (type == 'start' && isDate) {
        _showStartDatePicker = true;
      } else if (type == 'start' && !isDate) {
        _showStartTimePicker = true;
      } else if (type == 'end' && isDate) {
        _showEndDatePicker = true;
      } else if (type == 'end' && !isDate) {
        _showEndTimePicker = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Edit Event Details',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ElevatedButton(
              onPressed: _saveEvent,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                'Save',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/img/background.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.black.withValues(alpha: 0.1)),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const SizedBox(height: 16),
                _buildSection(
                  title: 'Event Details',
                  children: [
                    _buildTextField(
                      controller: _titleController,
                      label: 'Event Title',
                      hint: 'Enter event title',
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _locationController,
                      label: 'Location',
                      hint: 'Enter location',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildSection(
                  title: 'Date & Time',
                  children: [
                    _buildDateTimeRow(
                      label: 'Start',
                      dateTime: _startDate,
                      showDatePicker: _showStartDatePicker,
                      showTimePicker: _showStartTimePicker,
                      onDateTap: () =>
                          _togglePicker(type: 'start', isDate: true),
                      onTimeTap: () =>
                          _togglePicker(type: 'start', isDate: false),
                      onDateChanged: (date) {
                        setState(() {
                          _startDate = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            _startDate.hour,
                            _startDate.minute,
                          );
                          _togglePicker(type: 'start', isDate: true);
                        });
                      },
                      onTimeChanged: (time) {
                        setState(() {
                          _startDate = DateTime(
                            _startDate.year,
                            _startDate.month,
                            _startDate.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildDateTimeRow(
                      label: 'End',
                      dateTime: _endDate,
                      showDatePicker: _showEndDatePicker,
                      showTimePicker: _showEndTimePicker,
                      onDateTap: () => _togglePicker(type: 'end', isDate: true),
                      onTimeTap: () =>
                          _togglePicker(type: 'end', isDate: false),
                      onDateChanged: (date) {
                        setState(() {
                          _endDate = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            _endDate.hour,
                            _endDate.minute,
                          );
                          _togglePicker(type: 'end', isDate: true);
                        });
                      },
                      onTimeChanged: (time) {
                        setState(() {
                          _endDate = DateTime(
                            _endDate.year,
                            _endDate.month,
                            _endDate.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: GoogleFonts.inter(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: Colors.white54),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.white30),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.blue),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateTimeRow({
    required String label,
    required DateTime dateTime,
    required bool showDatePicker,
    required bool showTimePicker,
    required VoidCallback onDateTap,
    required VoidCallback onTimeTap,
    required Function(DateTime) onDateChanged,
    required Function(TimeOfDay) onTimeChanged,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                label,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: TextButton(
                onPressed: onDateTap,
                style: TextButton.styleFrom(
                  backgroundColor: showDatePicker
                      ? Colors.blue.withValues(alpha: 0.8)
                      : Colors.white.withValues(alpha: 0.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  DateFormat('MMM d, yyyy').format(dateTime),
                  style: GoogleFonts.inter(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextButton(
                onPressed: onTimeTap,
                style: TextButton.styleFrom(
                  backgroundColor: showTimePicker
                      ? Colors.blue.withValues(alpha: 0.8)
                      : Colors.white.withValues(alpha: 0.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  DateFormat.Hm().format(dateTime),
                  style: GoogleFonts.inter(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: Column(
            children: [
              if (showDatePicker)
                _buildInlineDatePicker(
                  onDateChanged: onDateChanged,
                  dateTime: dateTime,
                ),
              if (showTimePicker)
                _buildInlineTimePicker(
                  onTimeChanged: onTimeChanged,
                  dateTime: dateTime,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInlineDatePicker({
    required Function(DateTime) onDateChanged,
    required DateTime dateTime,
  }) {
    return TableCalendar(
      firstDay: DateTime.utc(2020),
      lastDay: DateTime.utc(2030),
      focusedDay: dateTime,
      selectedDayPredicate: (day) => isSameDay(day, dateTime),
      onDaySelected: (selectedDay, focusedDay) => onDateChanged(selectedDay),
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

  Widget _buildInlineTimePicker({
    required Function(TimeOfDay) onTimeChanged,
    required DateTime dateTime,
  }) {
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
                  onTimeChanged(TimeOfDay(hour: index, minute: currentMinute)),
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
                  onTimeChanged(TimeOfDay(hour: currentHour, minute: index)),
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
}

class RecurrenceGroupingPage extends StatefulWidget {
  final List<CalendarEvent> events;

  const RecurrenceGroupingPage({super.key, required this.events});

  @override
  State<RecurrenceGroupingPage> createState() => _RecurrenceGroupingPageState();
}

class _RecurrenceGroupingPageState extends State<RecurrenceGroupingPage> {
  final Map<RepeatRule, List<CalendarEvent>> _eventGroups = {};
  final Map<RepeatRule, Set<int>> _weekdaySelections = {};
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _initializeGroups();
    _startDate = DateTime.now();
    _endDate = DateTime.now().add(const Duration(days: 30));
  }

  void _initializeGroups() {
    for (RepeatRule rule in RepeatRule.values) {
      _eventGroups[rule] = [];
      _weekdaySelections[rule] = {};
    }

    _eventGroups[RepeatRule.never] = List.from(widget.events);
  }

  void _moveEvent(CalendarEvent event, RepeatRule fromRule, RepeatRule toRule) {
    setState(() {
      _eventGroups[fromRule]?.remove(event);
      _eventGroups[toRule]?.add(event);
    });
  }

  Future<void> _saveAllEventsToCalendar() async {
    final calendarState = context.read<CalendarState>();

    // Build list of events to add
    final List<CalendarEvent> toAdd = [];
    for (final entry in _eventGroups.entries) {
      final rule = entry.key;
      for (final ev in entry.value) {
        CalendarEvent updated = ev;
        if (rule != RepeatRule.never) {
          updated = updated.copyWith(repeatRule: rule);
        }
        if (rule == RepeatRule.weekly) {
          // Apply selected weekdays (default to original start weekday if none)
            final sel = _weekdaySelections[rule];
            final weekdays = (sel != null && sel.isNotEmpty)
                ? sel.map((i) => i + 1).toList() // stored index 0=Mon => DateTime.weekday 1=Mon
                : (updated.repeatWeekdays.isNotEmpty
                    ? updated.repeatWeekdays
                    : [updated.start.weekday]);
            updated = updated.copyWith(repeatWeekdays: weekdays);
        }
        toAdd.add(updated);
      }
    }

    // Optional: conflict check (existing stub)
    final conflicts = await _checkForConflictsWithList(toAdd);
    if (conflicts.isNotEmpty && mounted) {
      final proceed = await _showConflictDialog(conflicts);
      if (proceed != true) return;
    }

    for (final ev in toAdd) {
      await calendarState.addEvent(ev);
    }

    if (mounted) Navigator.pop(context);
  }

  Future<List<String>> _checkForConflictsWithList(List<CalendarEvent> newEvents) async {
    final calendarState = context.read<CalendarState>();
    final existing = calendarState.events;
    final conflicts = <String>{};

    // Determine evaluation window
    final DateTime rangeStart = (_startDate ?? DateTime.now()).subtract(const Duration(days: 1));
    final DateTime rangeEnd = (_endDate ?? DateTime.now().add(const Duration(days: 30))).add(const Duration(days: 1));

    // Pre-expand existing events (including their recurrences) within range.
    final List<_OccurrenceRef> existingOccurrences = [];
    for (final ev in existing) {
      existingOccurrences.addAll(_expandEventOccurrences(ev, rangeStart, rangeEnd, limit: 800));
    }

    // Expand new events and compare
    final List<_OccurrenceRef> newOccurrences = [];
    for (final newEv in newEvents) {
      final occs = _expandEventOccurrences(newEv, rangeStart, rangeEnd, limit: 800);
      newOccurrences.addAll(occs);
    }

    bool overlaps(DateTime aStart, DateTime aEnd, DateTime bStart, DateTime bEnd) {
      return aStart.isBefore(bEnd) && aEnd.isAfter(bStart);
    }

    final dateFmt = DateFormat.yMMMd();
    final timeFmt = DateFormat.jm();

    // Check new vs existing
    for (final nOcc in newOccurrences) {
      for (final eOcc in existingOccurrences) {
        if (overlaps(nOcc.start, nOcc.end, eOcc.start, eOcc.end)) {
          conflicts.add('${nOcc.title} (${dateFmt.format(nOcc.start)} ${timeFmt.format(nOcc.start)}) overlaps ${eOcc.title} (${dateFmt.format(eOcc.start)} ${timeFmt.format(eOcc.start)})');
        }
      }
    }

    // Optional: detect conflicts among new occurrences themselves (avoid duplicate pairs)
    for (int i = 0; i < newOccurrences.length; i++) {
      for (int j = i + 1; j < newOccurrences.length; j++) {
        final a = newOccurrences[i];
        final b = newOccurrences[j];
        if (overlaps(a.start, a.end, b.start, b.end)) {
          // Only report if they originate from different source events (ids differ or one is unsaved '')
          if (a.sourceId != b.sourceId) {
            conflicts.add('${a.title} (${dateFmt.format(a.start)} ${timeFmt.format(a.start)}) overlaps ${b.title} (${dateFmt.format(b.start)} ${timeFmt.format(b.start)})');
          }
        }
      }
    }

    return conflicts.take(50).toList();
  }

  // _eventsOverlap removed (legacy single-instance checker) – superseded by expanded occurrence comparison.
  // Expand a single CalendarEvent into concrete occurrences (bounded)
  List<_OccurrenceRef> _expandEventOccurrences(
    CalendarEvent event,
    DateTime rangeStart,
    DateTime rangeEnd, {
    int limit = 500,
  }) {
    final occurrences = <_OccurrenceRef>[];
    DateTime seriesEnd = event.repeatUntil ?? rangeEnd;
    if (seriesEnd.isAfter(rangeEnd)) seriesEnd = rangeEnd;
    final DateTime seriesStart = event.start.isAfter(rangeStart) ? event.start : rangeStart;

    Duration eventDuration = event.end.difference(event.start);
    if (eventDuration.isNegative || eventDuration.inMinutes == 0) {
      eventDuration = const Duration(minutes: 1);
    }

    void addOccurrence(DateTime occStart) {
      if (occurrences.length >= limit) return; // cap
      final occEnd = occStart.add(eventDuration);
      if (occEnd.isBefore(rangeStart) || occStart.isAfter(rangeEnd)) return;
      occurrences.add(_OccurrenceRef(
        sourceId: event.id,
        title: event.title.isNotEmpty ? event.title : 'Untitled',
        start: occStart,
        end: occEnd,
      ));
    }

    switch (event.repeatRule) {
      case RepeatRule.never:
        addOccurrence(event.start);
        break;
      case RepeatRule.daily:
        for (DateTime d = _atStartOfDay(seriesStart); d.isBefore(seriesEnd.add(const Duration(days: 1))); d = d.add(const Duration(days: 1))) {
          final occStart = DateTime(d.year, d.month, d.day, event.start.hour, event.start.minute);
          if (!_isException(event, occStart)) addOccurrence(occStart);
          if (occurrences.length >= limit) break;
        }
        break;
      case RepeatRule.weekly:
        final weekdays = event.repeatWeekdays.isNotEmpty ? event.repeatWeekdays : [event.start.weekday];
        for (DateTime d = _atStartOfDay(seriesStart); d.isBefore(seriesEnd.add(const Duration(days: 1))); d = d.add(const Duration(days: 1))) {
          if (weekdays.contains(d.weekday)) {
            final occStart = DateTime(d.year, d.month, d.day, event.start.hour, event.start.minute);
            if (!_isException(event, occStart)) addOccurrence(occStart);
            if (occurrences.length >= limit) break;
          }
        }
        break;
      case RepeatRule.everyTwoWeeks:
        DateTime anchor = _atStartOfDay(event.start);
        for (DateTime d = _atStartOfDay(seriesStart); d.isBefore(seriesEnd.add(const Duration(days: 1))); d = d.add(const Duration(days: 1))) {
          final diff = d.difference(anchor).inDays;
          if (diff >= 0 && diff % 14 == 0 && d.weekday == event.start.weekday) {
            final occStart = DateTime(d.year, d.month, d.day, event.start.hour, event.start.minute);
            if (!_isException(event, occStart)) addOccurrence(occStart);
          }
          if (occurrences.length >= limit) break;
        }
        break;
      case RepeatRule.monthly:
        DateTime cursor = DateTime(event.start.year, event.start.month, event.start.day, event.start.hour, event.start.minute);
        while (cursor.isBefore(seriesEnd.add(const Duration(days: 1))) && occurrences.length < limit) {
          if (cursor.isAfter(rangeEnd)) break;
            if (cursor.isAfter(rangeStart.subtract(const Duration(days: 1))) && !_isException(event, cursor)) addOccurrence(cursor);
          int year = cursor.year;
          int month = cursor.month + 1;
          if (month > 12) { month = 1; year++; }
          int day = event.start.day;
          final lastDay = DateTime(year, month + 1, 0).day;
          if (day > lastDay) day = lastDay;
          cursor = DateTime(year, month, day, event.start.hour, event.start.minute);
        }
        break;
      case RepeatRule.yearly:
        DateTime cursor = DateTime(event.start.year, event.start.month, event.start.day, event.start.hour, event.start.minute);
        while (cursor.isBefore(seriesEnd.add(const Duration(days: 1))) && occurrences.length < limit) {
          if (cursor.isAfter(rangeEnd)) break;
          if (cursor.isAfter(rangeStart.subtract(const Duration(days: 1))) && !_isException(event, cursor)) addOccurrence(cursor);
          cursor = DateTime(cursor.year + 1, cursor.month, cursor.day, cursor.hour, cursor.minute);
        }
        break;
    }
    return occurrences;
  }

  bool _isException(CalendarEvent event, DateTime occStart) {
    final normalized = DateTime.utc(occStart.year, occStart.month, occStart.day);
    return event.exceptions.any((e) => e.year == normalized.year && e.month == normalized.month && e.day == normalized.day);
  }

  DateTime _atStartOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<bool> _showConflictDialog(List<String> conflicts) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF2D3748).withValues(alpha: 0.95),
            title: Text(
              'Event Conflicts Detected',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'The following conflicts were found:',
                  style: GoogleFonts.inter(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                ...conflicts
                    .take(5)
                    .map(
                      (conflict) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '• $conflict',
                          style: GoogleFonts.inter(
                            color: Colors.red.shade300,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                if (conflicts.length > 5)
                  Text(
                    '... and ${conflicts.length - 5} more conflicts',
                    style: GoogleFonts.inter(
                      color: Colors.red.shade300,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.inter(color: Colors.white70),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  'Continue Anyway',
                  style: GoogleFonts.inter(color: Colors.orange),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Group Recurrence Patterns',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ElevatedButton(
              onPressed: _saveAllEventsToCalendar,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                'Add All',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/img/background.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.black.withValues(alpha: 0.1)),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildDateRangeSection(),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: RepeatRule.values
                        .map((rule) => _buildGroupSection(rule))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangeSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recurrence Period',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _startDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (date != null) {
                      setState(() {
                        _startDate = date;
                      });
                    }
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    _startDate != null
                        ? DateFormat('MMM d, yyyy').format(_startDate!)
                        : 'Start Date',
                    style: GoogleFonts.inter(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextButton(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate:
                          _endDate ??
                          DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (date != null) {
                      setState(() {
                        _endDate = date;
                      });
                    }
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    _endDate != null
                        ? DateFormat('MMM d, yyyy').format(_endDate!)
                        : 'End Date',
                    style: GoogleFonts.inter(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGroupSection(RepeatRule rule) {
    final events = _eventGroups[rule] ?? [];
    final groupColor = _getGroupColor(rule);

    return DragTarget<Map<String, dynamic>>(
      onWillAcceptWithDetails: (data) => true,
      onAcceptWithDetails: (data) {
        final draggedEvent = data.data['event'] as CalendarEvent;
        final fromRule = data.data['fromRule'] as RepeatRule;
        if (fromRule != rule) {
          _moveEvent(draggedEvent, fromRule, rule);
        }
      },
      builder: (context, candidateData, rejectedData) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: candidateData.isNotEmpty
                ? Colors.blue.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: candidateData.isNotEmpty
                  ? Colors.blue
                  : groupColor.withValues(alpha: 0.5),
            ),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: events.isNotEmpty,
              leading: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: groupColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${events.length}',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              title: Text(
                _getRepeatRuleDisplayName(rule),
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              iconColor: Colors.white,
              collapsedIconColor: Colors.white70,
              children: [
                if (rule == RepeatRule.weekly && events.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: _buildWeekdaySelector(rule),
                  ),
                ...events.map((event) => _buildDraggableEventItem(event, rule)),
                if (events.isEmpty)
                  Container(
                    height: 60,
                    margin: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: candidateData.isNotEmpty
                          ? Colors.blue.withValues(alpha: 0.3)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: candidateData.isNotEmpty
                            ? Colors.blue
                            : Colors.white30,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        candidateData.isNotEmpty
                            ? 'Drop here for ${_getRepeatRuleDisplayName(rule).toLowerCase()}'
                            : 'Drop events here to set ${_getRepeatRuleDisplayName(rule).toLowerCase()} recurrence',
                        style: GoogleFonts.inter(
                          color: candidateData.isNotEmpty
                              ? Colors.white
                              : Colors.white60,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWeekdaySelector(RepeatRule rule) {
    if (rule != RepeatRule.weekly) return const SizedBox.shrink();
    final labels = const ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    final selected = _weekdaySelections[rule] ?? <int>{};
    return Wrap(
      spacing: 8,
      children: List.generate(7, (i) {
        final isSel = selected.contains(i);
        return ChoiceChip(
          label: Text(labels[i]),
          selected: isSel,
          onSelected: (val) {
            setState(() {
              final set = _weekdaySelections[rule] ?? <int>{};
              if (val) {
                set.add(i);
              } else {
                set.remove(i);
              }
              _weekdaySelections[rule] = set;
            });
          },
        );
      }),
    );
  }

  Widget _buildDraggableEventItem(CalendarEvent event, RepeatRule currentRule) {
    return Draggable<Map<String, dynamic>>(
      data: {'event': event, 'fromRule': currentRule},
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: event.color.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            event.title,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      childWhenDragging: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white30),
        ),
        child: Text(
          event.title,
          style: GoogleFonts.inter(
            color: Colors.white30,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      child: DragTarget<Map<String, dynamic>>(
        onWillAcceptWithDetails: (data) => true,
        onAcceptWithDetails: (data) {
          final draggedEvent = data.data['event'] as CalendarEvent;
          final fromRule = data.data['fromRule'] as RepeatRule;
          if (fromRule != currentRule) {
            _moveEvent(draggedEvent, fromRule, currentRule);
          }
        },
        builder: (context, candidateData, rejectedData) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: candidateData.isNotEmpty
                  ? Colors.blue.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: candidateData.isNotEmpty ? Colors.blue : Colors.white30,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: event.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${DateFormat.yMMMd().format(event.start)} • ${DateFormat.jm().format(event.start)}',
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.drag_handle, color: Colors.white54, size: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _getGroupColor(RepeatRule rule) {
    switch (rule) {
      case RepeatRule.never:
        return Colors.grey;
      case RepeatRule.daily:
        return Colors.green;
      case RepeatRule.weekly:
        return Colors.blue;
      case RepeatRule.everyTwoWeeks:
        return Colors.purple;
      case RepeatRule.monthly:
        return Colors.orange;
      case RepeatRule.yearly:
        return Colors.red;
    }
  }

  String _getRepeatRuleDisplayName(RepeatRule rule) {
    switch (rule) {
      case RepeatRule.never:
        return 'No Repeat';
      case RepeatRule.daily:
        return 'Daily';
      case RepeatRule.weekly:
        return 'Weekly';
      case RepeatRule.everyTwoWeeks:
        return 'Every Two Weeks';
      case RepeatRule.monthly:
        return 'Monthly';
      case RepeatRule.yearly:
        return 'Yearly';
    }
  }
}

class _OccurrenceRef {
  final String sourceId;
  final String title;
  final DateTime start;
  final DateTime end;
  _OccurrenceRef({
    required this.sourceId,
    required this.title,
    required this.start,
    required this.end,
  });
}
