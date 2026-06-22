class ChatMessage {
  final String message;
  final bool isDriver; // true = driver, false = user
  final DateTime time;

  ChatMessage({
    required this.message,
    required this.isDriver,
    required this.time,
  });
}