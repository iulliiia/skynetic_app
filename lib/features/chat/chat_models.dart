/// One message of a case conversation.
class ChatMessage {
  final String id;
  final String requestId;
  final String senderUserId;
  final String senderRole; // patient | doctor
  final String body;
  final String clientMessageId;
  final DateTime createdAt;
  final DateTime? readAt;

  /// Client-side delivery state for optimistic sends.
  final bool pending;
  final bool failed;

  const ChatMessage({
    required this.id,
    required this.requestId,
    required this.senderUserId,
    required this.senderRole,
    required this.body,
    required this.clientMessageId,
    required this.createdAt,
    this.readAt,
    this.pending = false,
    this.failed = false,
  });

  ChatMessage copyWith({bool? pending, bool? failed, DateTime? readAt}) => ChatMessage(
        id: id, requestId: requestId, senderUserId: senderUserId, senderRole: senderRole, body: body,
        clientMessageId: clientMessageId, createdAt: createdAt, readAt: readAt ?? this.readAt,
        pending: pending ?? this.pending, failed: failed ?? this.failed,
      );

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] as String,
        requestId: j['request_id'] as String,
        senderUserId: j['sender_user_id'] as String,
        senderRole: j['sender_role'] as String? ?? '',
        body: j['body'] as String,
        clientMessageId: j['client_message_id'] as String? ?? '',
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
        readAt: j['read_at'] is String ? DateTime.tryParse(j['read_at'] as String)?.toLocal() : null,
      );
}

/// Frame received on the socket.
class ChatEvent {
  final String type; // message | read | subscribed | error | pong
  final String? requestId;
  final ChatMessage? message;
  final String? readerUserId;
  final String? code;
  final String? error;

  const ChatEvent({required this.type, this.requestId, this.message, this.readerUserId, this.code, this.error});

  factory ChatEvent.fromJson(Map<String, dynamic> j) => ChatEvent(
        type: j['type'] as String? ?? '',
        requestId: j['request_id'] as String?,
        message: j['message'] is Map<String, dynamic> ? ChatMessage.fromJson(j['message'] as Map<String, dynamic>) : null,
        readerUserId: j['reader_user_id'] as String?,
        code: j['code'] as String?,
        error: j['error'] as String?,
      );
}
