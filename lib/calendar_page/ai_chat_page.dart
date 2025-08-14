import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../environment.dart';
import '../models/calendar_event.dart';
import '../models/chat_message.dart';
import '../state/calendar_state.dart';
import '../widgets/background_container.dart';

class AiChatPage extends StatefulWidget {
  const AiChatPage({super.key});

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  final String _cloudFunctionUrl = AppEnv.chatFunctionUrl;

  @override
  void initState() {
    super.initState();
    _messages.add(ChatMessage(
      text: "Hello! I can help you create, update, or delete events. "
          "\n\nFor example, try: 'Cancel my 9am meeting on Monday, and add a new project review for 4pm.'",
      isUser: false,
    ));
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final calendarState = context.read<CalendarState>();

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isLoading = true;
    });
    _textController.clear();
    _scrollToBottom();

    final now = DateTime.now();
    final upcomingEvents = calendarState.events
        .where((event) => event.end.isAfter(now))
        .take(50)
        .map((event) => event.toJson())
        .toList();

    try {
      if (_cloudFunctionUrl.isEmpty) {
        throw Exception("Missing CHAT_FUNCTION_URL.");
      }

      final response = await http.post(
        Uri.parse(_cloudFunctionUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'prompt': text,
          'current_events': upcomingEvents,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = data['reply'] as String? ?? "Sorry, I couldn't process that.";
        final actions = (data['actions'] as List<dynamic>?)
            ?.map((e) => e as Map<String, dynamic>)
            .toList();

        setState(() {
          _messages.add(ChatMessage(text: reply, isUser: false, actions: actions));
        });
      } else {
        throw Exception('Failed to get response from AI. Status code: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(text: "Sorry, an error occurred: ${e.toString()}", isUser: false));
      });
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  Future<void> _executeCalendarActions(List<Map<String, dynamic>> actions) async {
    final calendarState = context.read<CalendarState>();
    int successCount = 0;
    String summary = "";

    for (final actionData in actions) {
      try {
        final actionType = actionData['action'];

        switch(actionType) {
          case 'CREATE':
            final eventData = actionData['event'];
            final newEvent = CalendarEvent(
              title: eventData['title'] ?? 'Untitled Event',
              location: eventData['location'] ?? '',
              start: DateTime.parse(eventData['start']),
              end: DateTime.parse(eventData['end']),
              userId: calendarState.currentUserId ?? '',
            );
            await calendarState.addEvent(newEvent);
            successCount++;
            summary += "Created '${newEvent.title}'.\n";
            break;

          case 'UPDATE':
            final eventId = actionData['event_id'];
            final updates = actionData['updates'] as Map<String, dynamic>;
            final originalEvent = calendarState.events.firstWhere((e) => e.id == eventId);

            final updatedEvent = originalEvent.copyWith(
              title: updates['title'] ?? originalEvent.title,
              location: updates['location'] ?? originalEvent.location,
              start: updates['start'] != null ? DateTime.parse(updates['start']) : originalEvent.start,
              end: updates['end'] != null ? DateTime.parse(updates['end']) : originalEvent.end,
            );
            await calendarState.updateEvent(updatedEvent);
            successCount++;
            summary += "Updated '${originalEvent.title}'.\n";
            break;

          case 'DELETE':
            final eventId = actionData['event_id'];
            final eventTitle = calendarState.events.firstWhere((e) => e.id == eventId).title;
            await calendarState.deleteEvent(eventId);
            successCount++;
            summary += "Deleted '$eventTitle'.\n";
            break;
        }
      } catch (e) {
        print("Error processing action: $e");
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$successCount action(s) completed!'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundImageContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('AI Calendar Assistant', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16.0),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  return _buildChatMessageBubble(message);
                },
              ),
            ),
            if (_isLoading) const LinearProgressIndicator(),
            _buildTextInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildChatMessageBubble(ChatMessage message) {
    final calendarState = context.read<CalendarState>();
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: message.isUser ? Colors.blue.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message.text, style: GoogleFonts.inter(color: Colors.white, fontSize: 16)),
            if (message.actions != null && message.actions!.isNotEmpty) ...[
              const Divider(color: Colors.white30, height: 24),
              Text( "Proposed Changes:", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...message.actions!.map((action) {
                String title = "";
                IconData icon = Icons.help;
                Color color = Colors.grey;

                switch(action['action']) {
                  case 'CREATE':
                    title = "Create: ${action['event']['title']}";
                    icon = Icons.add;
                    color = Colors.lightBlue;
                    break;
                  case 'UPDATE':
                    final eventId = action['event_id'];
                    final originalTitle = calendarState.events.firstWhere((e) => e.id == eventId).title;
                    title = "Update: $originalTitle";
                    icon = Icons.edit;
                    color = Colors.orange;
                    break;
                  case 'DELETE':
                    final eventId = action['event_id'];
                    final originalTitle = calendarState.events.firstWhere((e) => e.id == eventId).title;
                    title = "Delete: $originalTitle";
                    icon = Icons.delete;
                    color = Colors.redAccent;
                    break;
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Row(
                    children: [
                      Icon(icon, color: color, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(title, style: GoogleFonts.inter(color: Colors.white))),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),
              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Confirm Changes'),
                  onPressed: () => _executeCalendarActions(message.actions!),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                ),
              )
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildTextInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      margin: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white30),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.multiline,
              minLines: 1,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Describe your changes...',
                hintStyle: TextStyle(color: Colors.white70),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, color: Colors.white),
            onPressed: _isLoading ? null : _sendMessage,
          ),
        ],
      ),
    );
  }
}
