class ChatMessage {
  final String text;
  final bool isUser;
  final List<Map<String, dynamic>>? actions;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.actions,
  });
}