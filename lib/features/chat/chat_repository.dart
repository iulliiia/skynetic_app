import 'dart:async';
import 'dart:convert';

import 'package:skynetic_app/core/api/api_client.dart';
import 'package:skynetic_app/core/auth/token_storage.dart';
import 'package:skynetic_app/features/chat/chat_models.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Live connection to one case room. [events] ends when the socket closes.
abstract class ChatConnection {
  Stream<ChatEvent> get events;
  void markRead();
  Future<void> close();
}

/// Messaging endpoints + socket.
abstract class ChatRepository {
  Future<List<ChatMessage>> history(String requestId, {DateTime? before});
  Future<ChatMessage> send(String requestId, String body, String clientMessageId);
  Future<void> markRead(String requestId);
  Future<Map<String, int>> unreadByRequest();
  Future<ChatConnection> connect(String requestId);
}

class ApiChatRepository implements ChatRepository {
  final ApiClient _client;
  final TokenStorage _storage;
  ApiChatRepository(this._client, this._storage);

  @override
  Future<List<ChatMessage>> history(String requestId, {DateTime? before}) async {
    final res = await _client.getJson('/review-requests/$requestId/messages', query: {
      if (before != null) 'before': before.toUtc().toIso8601String(),
      'limit': 100,
    });
    return (res['items'] as List? ?? const []).cast<Map<String, dynamic>>().map(ChatMessage.fromJson).toList();
  }

  @override
  Future<ChatMessage> send(String requestId, String body, String clientMessageId) async => ChatMessage.fromJson(
        await _client.postJson('/review-requests/$requestId/messages', body: {'body': body, 'client_message_id': clientMessageId}),
      );

  @override
  Future<void> markRead(String requestId) => _client.postJson('/review-requests/$requestId/messages/read');

  @override
  Future<Map<String, int>> unreadByRequest() async {
    final res = await _client.getJson('/messages/unread');
    return (res['by_request'] as Map? ?? const {}).map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
  }

  @override
  Future<ChatConnection> connect(String requestId) async {
    // A cheap authenticated call first: it refreshes an expired access token
    // through the interceptor, so the socket upgrade carries a valid one.
    await _client.getJson('/messages/unread');
    final tokens = await _storage.read();
    final uri = Uri.parse('${_client.baseUrl}/api/v1/ws').replace(scheme: _client.baseUrl.startsWith('https') ? 'wss' : 'ws');
    final channel = IOWebSocketChannel.connect(
      uri,
      headers: {'Authorization': 'Bearer ${tokens?.accessToken}'},
      pingInterval: const Duration(seconds: 25),
    );
    await channel.ready;
    channel.sink.add(jsonEncode({'type': 'subscribe', 'request_id': requestId}));
    return _SocketConnection(channel, requestId);
  }
}

class _SocketConnection implements ChatConnection {
  final WebSocketChannel _channel;
  final String _requestId;
  _SocketConnection(this._channel, this._requestId);

  @override
  Stream<ChatEvent> get events => _channel.stream.map((raw) {
        try {
          return ChatEvent.fromJson(jsonDecode(raw as String) as Map<String, dynamic>);
        } catch (_) {
          return const ChatEvent(type: 'error', code: 'bad_frame');
        }
      });

  @override
  void markRead() => _channel.sink.add(jsonEncode({'type': 'read', 'request_id': _requestId}));

  @override
  Future<void> close() => _channel.sink.close();
}
