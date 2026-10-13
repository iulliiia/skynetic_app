import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skynetic_app/core/api/api_error.dart';
import 'package:skynetic_app/core/auth/auth_controller.dart';
import 'package:skynetic_app/core/providers.dart';
import 'package:skynetic_app/features/chat/chat_models.dart';
import 'package:skynetic_app/features/chat/chat_repository.dart';
import 'package:uuid/uuid.dart';

class ChatState {
  final List<ChatMessage> messages;
  final bool loading;
  final bool connected;
  final String? error; // last error to surface (snackbar)

  const ChatState({this.messages = const [], this.loading = true, this.connected = false, this.error});

  ChatState copyWith({List<ChatMessage>? messages, bool? loading, bool? connected, String? error, bool clearError = false}) =>
      ChatState(
        messages: messages ?? this.messages,
        loading: loading ?? this.loading,
        connected: connected ?? this.connected,
        error: clearError ? null : (error ?? this.error),
      );
}

/// One conversation: history + live events + optimistic sending with
/// reconnection. Messages are deduplicated by server id and client id.
class ChatController extends Notifier<ChatState> {
  ChatController(this.requestId);
  final String requestId;

  ChatConnection? _conn;
  StreamSubscription<ChatEvent>? _sub;
  Timer? _reconnect;
  int _attempt = 0;
  bool _disposed = false;

  ChatRepository get _repo => ref.read(chatRepositoryProvider);
  String get _me => ref.read(authControllerProvider).user?.id ?? '';

  @override
  ChatState build() {
    ref.onDispose(() {
      _disposed = true;
      _reconnect?.cancel();
      _sub?.cancel();
      _conn?.close();
    });
    Future.microtask(_start);
    return const ChatState();
  }

  Future<void> _start() async {
    await refreshHistory();
    await _connect();
  }

  /// Reloads the history (also used after a reconnect).
  Future<void> refreshHistory() async {
    try {
      final items = await _repo.history(requestId);
      if (_disposed) return;
      // keep optimistic messages that are still pending/failed
      final local = state.messages.where((m) => m.pending || m.failed).toList();
      state = state.copyWith(messages: _merge(items, local), loading: false, clearError: true);
      await _repo.markRead(requestId).catchError((_) {});
    } on ApiException catch (e) {
      if (!_disposed) state = state.copyWith(loading: false, error: e.message);
    } catch (_) {
      if (!_disposed) state = state.copyWith(loading: false, error: 'Conversația nu a putut fi încărcată.');
    }
  }

  Future<void> _connect() async {
    if (_disposed) return;
    try {
      _conn = await _repo.connect(requestId);
      if (_disposed) {
        await _conn?.close();
        return;
      }
      _attempt = 0;
      state = state.copyWith(connected: true);
      _sub = _conn!.events.listen(_onEvent, onDone: _scheduleReconnect, onError: (_) => _scheduleReconnect());
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _sub?.cancel();
    _sub = null;
    state = state.copyWith(connected: false);
    final delay = Duration(seconds: min(30, 1 << min(_attempt, 5)));
    _attempt++;
    _reconnect?.cancel();
    _reconnect = Timer(delay, () async {
      await refreshHistory(); // catch up on anything missed while offline
      await _connect();
    });
  }

  void _onEvent(ChatEvent e) {
    switch (e.type) {
      case 'message':
        if (e.message != null) {
          state = state.copyWith(messages: _merge(state.messages, [e.message!]));
          if (e.message!.senderUserId != _me) _conn?.markRead();
        }
      case 'read':
        if (e.readerUserId != null && e.readerUserId != _me) {
          final now = DateTime.now();
          state = state.copyWith(
            messages: state.messages.map((m) => m.senderUserId == _me && m.readAt == null ? m.copyWith(readAt: now) : m).toList(),
          );
        }
      case 'error':
        if (e.code != 'bad_frame') state = state.copyWith(error: e.error ?? 'Eroare de conexiune.');
      default:
        break;
    }
  }

  /// Sends optimistically; the server echo (same client id) replaces the
  /// pending bubble. Failures keep the bubble with a retry affordance.
  Future<void> send(String text) async {
    final body = text.trim();
    if (body.isEmpty) return;
    final clientId = const Uuid().v4();
    final optimistic = ChatMessage(
      id: 'local-$clientId', requestId: requestId, senderUserId: _me,
      senderRole: ref.read(authControllerProvider).isDoctor ? 'doctor' : 'patient',
      body: body, clientMessageId: clientId, createdAt: DateTime.now(), pending: true,
    );
    state = state.copyWith(messages: [...state.messages, optimistic], clearError: true);
    await _deliver(optimistic);
  }

  Future<void> retry(ChatMessage failed) async {
    state = state.copyWith(messages: state.messages.map((m) => m.clientMessageId == failed.clientMessageId ? m.copyWith(pending: true, failed: false) : m).toList());
    await _deliver(failed);
  }

  Future<void> _deliver(ChatMessage m) async {
    try {
      final saved = await _repo.send(requestId, m.body, m.clientMessageId);
      if (_disposed) return;
      state = state.copyWith(messages: _merge(state.messages, [saved]));
    } on ApiException catch (e) {
      if (_disposed) return;
      state = state.copyWith(
        messages: state.messages.map((x) => x.clientMessageId == m.clientMessageId ? x.copyWith(pending: false, failed: true) : x).toList(),
        error: e.message,
      );
    } catch (_) {
      if (_disposed) return;
      state = state.copyWith(
        messages: state.messages.map((x) => x.clientMessageId == m.clientMessageId ? x.copyWith(pending: false, failed: true) : x).toList(),
        error: 'Mesajul nu a putut fi trimis.',
      );
    }
  }

  void clearError() => state = state.copyWith(clearError: true);

  /// Merges by server id, replacing optimistic bubbles with the same client id.
  static List<ChatMessage> _merge(List<ChatMessage> base, List<ChatMessage> incoming) {
    final byId = <String, ChatMessage>{};
    final byClient = <String, String>{}; // clientId → key
    void put(ChatMessage m) {
      final key = m.id.startsWith('local-') ? 'c:${m.clientMessageId}' : m.id;
      if (!m.id.startsWith('local-') && m.clientMessageId.isNotEmpty) {
        final localKey = byClient[m.clientMessageId];
        if (localKey != null && localKey != key) byId.remove(localKey);
      }
      if (m.clientMessageId.isNotEmpty) {
        // a server copy wins over a local one
        if (byClient[m.clientMessageId] != null && !byClient[m.clientMessageId]!.startsWith('c:') && key.startsWith('c:')) return;
        byClient[m.clientMessageId] = key;
      }
      byId[key] = m;
    }
    base.forEach(put);
    incoming.forEach(put);
    final list = byId.values.toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }
}

final chatControllerProvider = NotifierProvider.family<ChatController, ChatState, String>(ChatController.new);

/// Unread messages per request, for badges.
final unreadMessagesProvider = FutureProvider<Map<String, int>>((ref) => ref.watch(chatRepositoryProvider).unreadByRequest());
