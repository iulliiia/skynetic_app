import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:skynetic_app/core/auth/auth_controller.dart';
import 'package:skynetic_app/features/chat/chat_controller.dart';
import 'package:skynetic_app/features/chat/chat_models.dart';
import 'package:skynetic_app/features/review/review_models.dart';
import 'package:skynetic_app/features/review/review_providers.dart';
import 'package:skynetic_app/theme/app_theme.dart';
import 'package:skynetic_app/widgets/responsive_center.dart';

/// Case conversation between the patient and the assigned doctor.
class ChatScreen extends ConsumerStatefulWidget {
  final String requestId;
  const ChatScreen({super.key, required this.requestId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    ref.read(chatControllerProvider(widget.requestId).notifier).send(text);
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatControllerProvider(widget.requestId));
    final request = ref.watch(requestProvider(widget.requestId)).value;
    final auth = ref.watch(authControllerProvider);
    final me = auth.user?.id;

    ref.listen(chatControllerProvider(widget.requestId), (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.error!)));
        ref.read(chatControllerProvider(widget.requestId).notifier).clearError();
      }
      if (next.messages.length != (prev?.messages.length ?? 0)) _scrollToEnd();
    });

    final counterpart = request == null
        ? ''
        : auth.isDoctor
            ? (request.patient?.displayName ?? 'Pacient')
            : (request.doctor?.displayName ?? 'Medic');
    final canWrite = request == null ||
        ReviewStatus.open.contains(request.status) && request.status != ReviewStatus.pending ||
        request.status == ReviewStatus.completed;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(counterpart, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17)),
            if (request != null)
              Text(request.lesion.label,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Tooltip(
              message: chat.connected ? 'Conectat' : 'Reconectare...',
              child: Icon(chat.connected ? Icons.wifi : Icons.wifi_off,
                  size: 18, color: chat.connected ? Colors.green : Colors.orange),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          final inputBar = _buildInput(canWrite);
          // With the keyboard open on a landscape phone only a few dozen
          // pixels remain: show just the (scrollable) input bar.
          if (constraints.maxHeight < 160) {
            return SingleChildScrollView(child: inputBar);
          }
          return Column(
            children: [
              if (!chat.connected && !chat.loading)
                Container(
                  width: double.infinity,
                  color: Colors.orange.shade50,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: const Text(
                      'Conexiune în timp real întreruptă — mesajele se trimit în continuare și se reîncarcă la reconectare.',
                      style: TextStyle(fontSize: 12, color: Colors.orange)),
                ),
              Expanded(
                child: chat.loading
                    ? const Center(child: CircularProgressIndicator())
                    : chat.messages.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Text(
                                'Niciun mesaj încă. Scrie primul mesaj — conversația este vizibilă doar ție și ${auth.isDoctor ? 'pacientului' : 'medicului'}.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
                              ),
                            ),
                          )
                        : ResponsiveCenter(
                            child: ListView.builder(
                              controller: _scroll,
                              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                              itemCount: chat.messages.length,
                              itemBuilder: (_, i) {
                                final m = chat.messages[i];
                                final showDay = i == 0 || !_sameDay(chat.messages[i - 1].createdAt, m.createdAt);
                                return Column(
                                  children: [
                                    if (showDay) _DayLabel(m.createdAt),
                                    _Bubble(
                                      message: m,
                                      mine: m.senderUserId == me,
                                      onRetry: m.failed
                                          ? () => ref.read(chatControllerProvider(widget.requestId).notifier).retry(m)
                                          : null,
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
              ),
              const Divider(height: 1),
              inputBar,
            ],
          );
        }),
      ),
    );
  }

  Widget _buildInput(bool canWrite) {
    if (!canWrite) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Conversația nu este deschisă pentru această cerere.', style: TextStyle(color: Colors.grey)),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              minLines: 1,
              maxLines: 4,
              maxLength: 4000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Scrie un mesaj…', counterText: ''),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 4),
          IconButton.filled(
            onPressed: _send,
            icon: const Icon(Icons.send),
            style: IconButton.styleFrom(backgroundColor: AppColors.accent2),
            tooltip: 'Trimite',
          ),
        ],
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayLabel extends StatelessWidget {
  final DateTime day;
  const _DayLabel(this.day);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(999)),
          child: Text(DateFormat('d MMMM yyyy', 'ro_RO').format(day),
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final bool mine;
  final VoidCallback? onRetry;
  const _Bubble({required this.message, required this.mine, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final m = message;
    final bg = mine ? AppColors.primary : Colors.white;
    final fg = mine ? Colors.white : AppColors.textPrimary;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          decoration: BoxDecoration(
            color: m.failed ? Colors.red.shade50 : bg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(mine ? 14 : 4),
              bottomRight: Radius.circular(mine ? 4 : 14),
            ),
            boxShadow: mine
                ? null
                : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(m.body, style: TextStyle(color: m.failed ? Colors.red.shade900 : fg, height: 1.35)),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(DateFormat('HH:mm').format(m.createdAt),
                      style: TextStyle(fontSize: 10, color: mine ? Colors.white70 : Colors.grey)),
                  if (mine) ...[
                    const SizedBox(width: 4),
                    if (m.failed)
                      InkWell(onTap: onRetry, child: const Icon(Icons.refresh, size: 14, color: Colors.red))
                    else if (m.pending)
                      const Icon(Icons.schedule, size: 12, color: Colors.white70)
                    else
                      Icon(m.readAt != null ? Icons.done_all : Icons.done,
                          size: 14, color: m.readAt != null ? Colors.lightBlueAccent : Colors.white70),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
