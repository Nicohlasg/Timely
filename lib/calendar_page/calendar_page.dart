import 'dart:math';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../models/calendar_event.dart';
import '../state/calendar_state.dart';
import 'agenda_view.dart';
import 'ai_chat_page.dart';
import 'edit_event_screen.dart';
import '../review_scanned_events.dart';
import 'package:http/http.dart' as http;
import '../widgets/conflict_dialog.dart';
import '../environment.dart';
import '../services/recurrence_service.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage>
    with SingleTickerProviderStateMixin {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _isAgendaView = false;

  late AnimationController _sheetController;
  final double _headerHeight = 175.0;

  Map<String, CalendarEvent>? _draggingEvent;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _sheetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  void _openEditEventScreen(
      BuildContext context,
      CalendarEvent event, {
        CalendarEvent? masterEvent,
      }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            EditEventScreen(event: event, masterEvent: masterEvent),
        fullscreenDialog: true,
      ),
    );
  }

  List<CalendarEvent> _getEventsForDay(DateTime day, List<CalendarEvent> allEvents) =>
      RecurrenceService.eventsForDay(allEvents, day);

  Future<void> _showMonthYearPickerSheet() async {
    int selectedMonth = _focusedDay.month;
    int selectedYear = _focusedDay.year;

    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2D3748).withValues(alpha: 0.95),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return SizedBox(
              height: 300,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.inter(color: Colors.white70),
                          ),
                        ),
              TextButton(
                          onPressed: () {
                            setState(() {
                              final newDay = min(
                                _focusedDay.day,
                                DateUtils.getDaysInMonth(
                                  selectedYear,
                                  selectedMonth,
                                ),
                              );
                              _focusedDay = DateTime(
                                selectedYear,
                                selectedMonth,
                                newDay,
                              );
                              _selectedDay = _focusedDay;
                            });
                            Navigator.pop(context);
                          },
                          child: Text(
                            'Done',
                            style: GoogleFonts.inter(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: CupertinoPicker(
                            scrollController: FixedExtentScrollController(
                              initialItem: selectedYear - 2020,
                            ),
                            itemExtent: 40,
                            onSelectedItemChanged: (int index) {
                              setModalState(() {
                                selectedYear = 2020 + index;
                              });
                            },
                            children: List<Widget>.generate(11, (int index) {
                              return Center(
                                child: Text(
                                  (2020 + index).toString(),
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 20,
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                        Expanded(
                          child: CupertinoPicker(
                            looping: true,
                            scrollController: FixedExtentScrollController(
                              initialItem: selectedMonth - 1,
                            ),
                            itemExtent: 40,
                            onSelectedItemChanged: (int index) {
                              setModalState(() {
                                selectedMonth = index + 1;
                              });
                            },
                            children: List<Widget>.generate(12, (int index) {
                              return Center(
                                child: Text(
                                  DateFormat.MMMM().format(
                                    DateTime(0, index + 1),
                                  ),
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 20,
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFloatingDropZone(Map<String, CalendarEvent>? draggingEvent, List<CalendarEvent> allEvents) {
    if (draggingEvent == null) return const SizedBox.shrink();
    return Positioned(
      right: 24,
      bottom: 24,
      child: DragTarget<Map<String, CalendarEvent>>(
        builder: (context, candidateData, rejectedData) {
          final isActive = candidateData.isNotEmpty;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isActive ? Colors.blue : Colors.white.withValues(alpha: .15),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                if (isActive) BoxShadow(color: Colors.blue.withValues(alpha: 0.3), blurRadius: 16),
              ],
            ),
            child: Icon(Icons.date_range, color: isActive ? Colors.white : Colors.blue, size: 32),
          );
        },
        onWillAcceptWithDetails: (_) => true,
        onAcceptWithDetails: (data) async {
          final picked = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
            builder: (context, child) => Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: Colors.blue, onPrimary: Colors.white,
                  surface: Color(0xFF2D3748), onSurface: Colors.white,
                ),
                dialogTheme: DialogThemeData(backgroundColor: const Color(0xFF2D3748)),
              ),
              child: child!,
            ),
          );
          if (picked != null) {
            final event = data.data['event']!;
            final masterEvent = data.data['masterEvent']!;
            await _handleEventDrop(event, masterEvent, picked, allEvents);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final calendarState = context.watch<CalendarState>();
    final allEvents = calendarState.events;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: _buildAppBar(),
          body: SafeArea(
            top: false,
            child: _isAgendaView
                ? _buildAgendaViewLayout(allEvents)
                : _buildCalendarView(allEvents),
          ),
        ),
        _buildFloatingDropZone(_draggingEvent, allEvents),
      ],
    );
  }

  Widget _buildCalendarView(List<CalendarEvent> allEvents) {
    final selectedEvents = _getEventsForDay(_selectedDay ?? _focusedDay, allEvents);
    final allDayEvents = selectedEvents.where((e) => e.allDay).toList();

    return Column(
      children: [
        _buildTableCalendar(allEvents),
        if (allDayEvents.isNotEmpty) _buildAllDayEventsSection(allDayEvents),
        Expanded(
          child: _buildEventList(
            selectedEvents.where((e) => !e.allDay).toList(),
          ),
        ),
      ],
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: TextButton.icon(
        onPressed: _showMonthYearPickerSheet,
        style: TextButton.styleFrom(padding: EdgeInsets.zero),
        icon: Text(
          DateFormat.yMMMM().format(_focusedDay),
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        label: const Icon(Icons.arrow_drop_down, color: Colors.white),
      ),
      centerTitle: false,
      titleSpacing: 16.0,
      actions: [
        IconButton(
          icon: const Icon(Icons.camera_alt_outlined, color: Colors.white),
          onPressed: _showOcrDialog,
        ),
        IconButton(
          icon: Icon(
            _isAgendaView
                ? Icons.calendar_view_month_outlined
                : Icons.view_agenda_outlined,
            color: Colors.white,
          ),
          onPressed: () => setState(() => _isAgendaView = !_isAgendaView),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.add, color: Colors.white),
          color: const Color(0xFF2D3748).withValues(alpha: 0.85),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Colors.white30),
          ),
          onSelected: (value) {
            if (value == 'manual') {
              final calendarState = context.read<CalendarState>();
              final now = DateTime.now();
              final newEvent = CalendarEvent(
                title: '',
                start: DateTime(now.year, now.month, now.day, now.hour, 0),
                end: DateTime(now.year, now.month, now.day, now.hour + 1, 0),
                userId: calendarState.currentUserId ?? '',
              );
              _openEditEventScreen(context, newEvent);
            } else if (value == 'ai') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AiChatPage()),
              );
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            PopupMenuItem<String>(
              value: 'manual',
              child: ListTile(
                leading: const Icon(Icons.edit_calendar, color: Colors.white70),
                title: Text('Manual Entry',
                    style: GoogleFonts.inter(color: Colors.white)),
              ),
            ),
            PopupMenuItem<String>(
              value: 'ai',
              child: ListTile(
                leading: const Icon(Icons.auto_awesome, color: Colors.white70),
                title: Text('AI Assistant',
                    style: GoogleFonts.inter(color: Colors.white)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTableCalendar(List<CalendarEvent> allEvents) {
    return TableCalendar<CalendarEvent>(
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: _focusedDay,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      onDaySelected: (selectedDay, focusedDay) {
        if (!isSameDay(_selectedDay, selectedDay)) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
        }
      },
      onPageChanged: (focusedDay) {
        setState(() => _focusedDay = focusedDay);
      },
      eventLoader: (day) => _getEventsForDay(day, allEvents),
      calendarFormat: CalendarFormat.month,
      headerVisible: false,
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, day, focusedDay) => _buildCalendarDay(day: day, isSelected: false, isToday: false, allEvents: allEvents),
        todayBuilder: (context, day, focusedDay) => _buildCalendarDay(day: day, isSelected: false, isToday: true, allEvents: allEvents),
        selectedBuilder: (context, day, focusedDay) => _buildCalendarDay(day: day, isSelected: true, isToday: false, allEvents: allEvents),
        markerBuilder: (context, day, events) {
          if (events.isNotEmpty) {
            return Positioned(
              left: 0,
              right: 0,
              bottom: 5,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ...events.take(3).map((event) => Container(
                    width: 7, height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: event.color),
                  )),
                  if (events.length > 3) const Icon(Icons.add, size: 10, color: Colors.white70),
                ],
              ),
            );
          }
          return null;
        },
      ),
      calendarStyle: CalendarStyle(
        defaultTextStyle: const TextStyle(color: Colors.white),
        weekendTextStyle: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
        outsideTextStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        selectedDecoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
        todayDecoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
        todayTextStyle: const TextStyle(color: Colors.white),
      ),
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
        weekendStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
      ),
    );
  }

  Widget _buildCalendarDay({
    required DateTime day,
    required bool isSelected,
    required bool isToday,
    required List<CalendarEvent> allEvents,
  }) {
    return DragTarget<Map<String, CalendarEvent>>(
      builder: (context, candidateData, rejectedData) {
        final isHighlighted = candidateData.isNotEmpty;
        return Container(
          margin: const EdgeInsets.all(4.0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected ? Colors.blue : isToday ? Colors.white.withValues(alpha: 0.2) : isHighlighted ? Colors.blue.withValues(alpha: 0.5) : null,
          ),
          child: Center(
            child: Text(
              '${day.day}',
              style: TextStyle(color: Colors.white, fontSize: isSelected ? 16.0 : 14.0),
            ),
          ),
        );
      },
      onWillAcceptWithDetails: (data) => true,
      onAcceptWithDetails: (details) {
        final data = details.data;
        final event = data['event']!;
        final masterEvent = data['masterEvent']!;
        _handleEventDrop(event, masterEvent, day, allEvents);
      },
    );
  }


  Widget _buildAgendaViewLayout(List<CalendarEvent> allEvents) {
    final positionAnimation = Tween(begin: _headerHeight, end: 0.0).animate(
      CurvedAnimation(parent: _sheetController, curve: Curves.easeInOut),
    );

    return Stack(
      children: [
        AnimatedBuilder(
          animation: _sheetController,
          child: _buildAgendaHeader(allEvents),
          builder: (context, child) {
            return Opacity(
              opacity: (1.0 - _sheetController.value).clamp(0.0, 1.0),
              child: child,
            );
          },
        ),
        AnimatedBuilder(
          animation: positionAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, positionAnimation.value),
              child: child,
            );
          },
          child: AgendaView(
            sheetController: _sheetController,
            headerHeight: _headerHeight,
            selectedDay: _selectedDay ?? DateTime.now(),
            getEventsForDay: (day) => _getEventsForDay(day, allEvents),
            onEditEvent: (event, {masterEvent}) =>
                _openEditEventScreen(context, event, masterEvent: masterEvent),
          ),
        ),
      ],
    );
  }

  Widget _buildAgendaHeader(List<CalendarEvent> allEvents) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (index) {
              final firstDayOfWeek = (_selectedDay ?? DateTime.now()).subtract(
                Duration(days: (_selectedDay ?? DateTime.now()).weekday % 7),
              );
              final day = firstDayOfWeek.add(Duration(days: index));
              final isSelected = isSameDay(day, _selectedDay);

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDay = day;
                    _focusedDay = day;
                  });
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat.E().format(day).substring(0, 1),
                      style: GoogleFonts.inter(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: isSelected
                          ? const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      )
                          : null,
                      child: Center(
                        child: Text(
                          '${day.day}',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Divider(color: Colors.white30, height: 1),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4.0, 8.0, 4.0, 8.0),
          child: Row(
            children: List.generate(7, (index) {
              final firstDayOfWeek = (_selectedDay ?? DateTime.now()).subtract(
                Duration(days: (_selectedDay ?? DateTime.now()).weekday % 7),
              );
              final day = firstDayOfWeek.add(Duration(days: index));
              final events = _getEventsForDay(day, allEvents);

              return Expanded(
                child: SizedBox(
                  height: (24.0 + 4.0) * 3,
                  child: ScrollConfiguration(
                    behavior: _NoScrollbarBehavior(),
                    child: ListView.builder(
                      itemCount: events.length,
                      itemBuilder: (context, i) {
                        return _buildEventSnippetBar(events[i]);
                      },
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }


  Widget _buildEventSnippetBar(CalendarEvent event) {
    return GestureDetector(
      onTap: () => _openEditEventScreen(context, event),
      child: Container(
        height: 24,
        margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
        padding: const EdgeInsets.symmetric(horizontal: 6.0),
        decoration: BoxDecoration(
          color: event.color.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(4.0),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            event.title,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.fade,
            softWrap: false,
            maxLines: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildAllDayEventsSection(List<CalendarEvent> allDayEvents) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: allDayEvents.map((event) {
          final masterEvent = context.read<CalendarState>().events.firstWhere(
            (e) => e.id == event.id,
            orElse: () => event,
          );
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Container(width: 5, color: event.color),
            title: Text(
              event.title,
              style: GoogleFonts.inter(color: Colors.white),
            ),
            onTap: () =>
                _openEditEventScreen(context, event, masterEvent: masterEvent),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEventList(List<CalendarEvent> timedEvents) {
    if (timedEvents.isEmpty) {
      return Center(
        child: Text(
          'No timed events for this day.',
          style: GoogleFonts.inter(color: Colors.white70),
        ),
      );
    }
    return ScrollConfiguration(
      behavior: _NoScrollbarBehavior(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        itemCount: timedEvents.length,
        itemBuilder: (context, index) {
          final event = timedEvents[index];
          final masterEvent = context.read<CalendarState>().events.firstWhere(
            (e) => e.id == event.id,
            orElse: () => event,
          );
          return _buildDraggableEventTile(event, masterEvent);
        },
      ),
    );
  }

  Widget _buildDraggableEventTile(
    CalendarEvent event,
    CalendarEvent masterEvent,
  ) {
    final eventData = {'event': event, 'masterEvent': masterEvent};

    return LongPressDraggable<Map<String, CalendarEvent>>(
      data: eventData,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: 200,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: event.color.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            event.title,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildEventTile(event, masterEvent),
      ),
      child: _buildEventTile(event, masterEvent),
      onDragStarted: () {
        setState(() {
          _draggingEvent = eventData;
        });
      },
      onDraggableCanceled: (_, __) {
        setState(() {
          _draggingEvent = null;
        });
      },
      onDragEnd: (_) {
        setState(() {
          _draggingEvent = null;
        });
      },
    );
  }

  Widget _buildEventTile(CalendarEvent event, CalendarEvent masterEvent) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: () =>
            _openEditEventScreen(context, event, masterEvent: masterEvent),
        leading: Container(width: 5, color: event.color),
        title: Text(
          event.title,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        subtitle: Text(
          '${DateFormat.Hm().format(event.start)} - ${DateFormat.Hm().format(event.end)}',
          style: GoogleFonts.inter(color: Colors.white70),
        ),
      ),
    );
  }

  Future<void> _handleEventDrop(
      CalendarEvent event,
      CalendarEvent masterEvent,
      DateTime newDate,
      List<CalendarEvent> allEvents,
      ) async {
    final calendarState = context.read<CalendarState>();
    final isRecurring = masterEvent.repeatRule != RepeatRule.never;
    final newStart = DateTime(
        newDate.year, newDate.month, newDate.day, event.start.hour,
        event.start.minute);
    final newEnd = newStart.add(event.end.difference(event.start));

    final eventsOnNewDay = _getEventsForDay(newDate, allEvents);
    final conflictingEvent = eventsOnNewDay.firstWhere(
          (e) =>
      e.id != event.id && newStart.isBefore(e.end) && newEnd.isAfter(e.start),
      orElse: () =>
          CalendarEvent(
          id: '', title: '', start: DateTime.now(), end: DateTime.now()),
    );

    if (conflictingEvent.id.isNotEmpty && mounted) {
      final continueAnyway = await showDialog<bool>(
        context: context,
        builder: (context) =>
            ConflictDialog(conflictingEventTitle: conflictingEvent.title),
      ) ?? false;
      if (!continueAnyway) return;
    }

    if (isRecurring) {
      final newSingleEvent = masterEvent.copyWith(
        id: '',
        start: newStart,
        end: newEnd,
        repeatRule: RepeatRule.never,
        repeatUntil: null,
        clearRepeatUntil: true,
        exceptions: [],
        userId: calendarState.currentUserId ?? '',
      );
      await calendarState.updateSingleOccurrence(
        masterEvent: masterEvent,
        occurrenceDate: event.start,
        updatedEvent: newSingleEvent,
      );
    } else {
      final updatedEvent = event.copyWith(start: newStart, end: newEnd);
      await calendarState.updateEvent(updatedEvent);
    }
    if (mounted) setState(() {});
  }

  Future<List<CalendarEvent>> _processImageWithAI(XFile imageFile) async {
    final cloudFunctionUrl = AppEnv.ocrFunctionUrl;
    if (cloudFunctionUrl.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OCR_FUNCTION_URL not configured')),
        );
      }
      return [];
    }

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(cloudFunctionUrl),
      );

      if (kIsWeb) {
        final imageBytes = await imageFile.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            imageBytes,
            filename: imageFile.name,
          ),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath('file', imageFile.path),
        );
      }

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final List<dynamic> eventData = jsonDecode(responseBody);

        return eventData.map((data) {
          return CalendarEvent(
            title: data['title'] ?? 'Untitled Event',
            start: DateTime.parse(data['start']),
            end: DateTime.parse(data['end']),
            location: data['location'] ?? '',
          );
        }).toList();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Server Error: ${response.statusCode}')),
          );
        }
        return [];
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error processing image: $e')));
      }
      return [];
    }
  }

  Future<void> _showOcrDialog() async {
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: const Color(0xFF2D3748).withValues(alpha: 0.95),
            border: Border.all(color: Colors.white30),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Scan Your Schedule',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Use your camera or upload a photo to automatically extract your schedule information.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 14, color: Colors.white70),
              ),
              const SizedBox(height: 24),
              const Icon(
                Icons.document_scanner_outlined,
                color: Colors.white,
                size: 60,
              ),
              const SizedBox(height: 8),
              Text(
                'Take a photo or upload',
                style: GoogleFonts.inter(fontSize: 14, color: Colors.white70),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.camera_alt, color: Colors.white),
                      label: Text(
                        'Take Photo',
                        style: GoogleFonts.inter(color: Colors.white),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        _pickAndProcessImage(ImageSource.camera);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(
                        Icons.upload_file,
                        color: Colors.white70,
                      ),
                      label: Text(
                        'Upload File',
                        style: GoogleFonts.inter(color: Colors.white70),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        _pickAndProcessImage(ImageSource.gallery);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndProcessImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? imageFile = await picker.pickImage(source: source);

    if (imageFile == null) return;
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final scannedEvents = await _processImageWithAI(imageFile);

    if (!mounted) return;
    Navigator.of(context).pop();

    if (scannedEvents.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ReviewScannedEventsPage(scannedEvents: scannedEvents),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not detect any events in the image.'),
        ),
      );
    }
  }
}

class _NoScrollbarBehavior extends ScrollBehavior {
  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
