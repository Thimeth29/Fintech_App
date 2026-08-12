enum ChatRole { user, bot }

class ChatMessageModel {
  final ChatRole role;
  final String content;
  final DateTime timestamp;

  ChatMessageModel({
    required this.role,
    required this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}
