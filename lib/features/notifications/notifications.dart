import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:skynetic_app/core/api/api_client.dart';
import 'package:skynetic_app/core/providers.dart';
import 'package:skynetic_app/theme/app_theme.dart';
import 'package:skynetic_app/widgets/responsive_center.dart';

/// One inbox entry.
class AppNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final String? resourceType;
  final String? resourceId;
  final DateTime? readAt;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.resourceType,
    this.resourceId,
    this.readAt,
    required this.createdAt,
  });

  bool get isUnread => readAt == null;

  /// Where tapping it should go.
  String? get route => resourceType == 'review_request' && resourceId != null ? '/review-requests/$resourceId' : null;

  IconData get icon {
    if (type.startsWith('message')) return Icons.chat_bubble_outline;
    if (type == 'review.completed') return Icons.assignment_turned_in_outlined;
    if (type == 'review.needs_info') return Icons.help_outline;
    if (type == 'review.rejected' || type == 'review.expired' || type == 'review.cancelled') return Icons.block;
    return Icons.medical_services_outlined;
  }

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as String,
        type: j['type'] as String,
        title: j['title'] as String,
        body: j['body'] as String,
        resourceType: j['resource_type'] as String?,
        resourceId: j['resource_id'] as String?,
        readAt: j['read_at'] is String ? DateTime.tryParse(j['read_at'] as String)?.toLocal() : null,
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      );
}

class Inbox {
  final List<AppNotification> items;
  final int unreadCount;
  const Inbox({required this.items, required this.unreadCount});
}

abstract class NotificationRepository {
  Future<Inbox> inbox();
  Future<void> markRead(String id);
  Future<void> markAllRead();
  Future<void> registerDevice(String platform, String token);
}

class ApiNotificationRepository implements NotificationRepository {
  final ApiClient _client;
  ApiNotificationRepository(this._client);

  @override
  Future<Inbox> inbox() async {
    final res = await _client.getJson('/notifications', query: {'limit': 100});
    return Inbox(
      items: (res['items'] as List? ?? const []).cast<Map<String, dynamic>>().map(AppNotification.fromJson).toList(),
      unreadCount: (res['unread_count'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<void> markRead(String id) => _client.patchJson('/notifications/$id/read');

  @override
  Future<void> markAllRead() => _client.postJson('/notifications/read-all');

  @override
  Future<void> registerDevice(String platform, String token) =>
      _client.postJson('/devices', body: {'platform': platform, 'token': token});
}

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => ApiNotificationRepository(ref.watch(apiClientProvider)),
);

final inboxProvider = FutureProvider<Inbox>((ref) => ref.watch(notificationRepositoryProvider).inbox());

/// Push registration seam. The default does nothing: delivering push
/// notifications needs a Firebase project (google-services.json /
/// GoogleService-Info.plist) and `firebase_messaging`; plug an implementation
/// here that obtains the FCM/APNs token and calls
/// `NotificationRepository.registerDevice`.
abstract class PushRegistrar {
  Future<void> registerIfAvailable(NotificationRepository repo);
}

class NoopPushRegistrar implements PushRegistrar {
  @override
  Future<void> registerIfAvailable(NotificationRepository repo) async {}
}

final pushRegistrarProvider = Provider<PushRegistrar>((ref) => NoopPushRegistrar());

/// Bell icon with an unread badge; opens the inbox.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(inboxProvider).value?.unreadCount ?? 0;
    return IconButton(
      tooltip: 'Notificări',
      onPressed: () async {
        await context.push('/notifications');
        ref.invalidate(inboxProvider);
      },
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text('$unread'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}

/// Inbox screen.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inbox = ref.watch(inboxProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificări'),
        actions: [
          if ((inbox.value?.unreadCount ?? 0) > 0)
            IconButton(
              tooltip: 'Marchează tot citit',
              icon: const Icon(Icons.done_all),
              onPressed: () async {
                await ref.read(notificationRepositoryProvider).markAllRead();
                ref.invalidate(inboxProvider);
              },
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(inboxProvider);
          await ref.read(inboxProvider.future);
        },
        child: inbox.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(padding: const EdgeInsets.all(24), children: [Text(e.toString(), textAlign: TextAlign.center)]),
          data: (data) => data.items.isEmpty
              ? ListView(padding: const EdgeInsets.all(32), children: [
                  const SizedBox(height: 48),
                  Icon(Icons.notifications_none, size: 56, color: AppColors.accent1.withValues(alpha: 0.5)),
                  const SizedBox(height: 12),
                  const Text('Nicio notificare.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
                ])
              : ResponsiveCenter(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: data.items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final n = data.items[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: n.isUnread ? AppColors.accent2 : Colors.grey.shade200,
                          child: Icon(n.icon, color: n.isUnread ? Colors.white : Colors.grey, size: 20),
                        ),
                        title: Text(n.title, style: TextStyle(fontWeight: n.isUnread ? FontWeight.bold : FontWeight.normal)),
                        subtitle: Text('${n.body}\n${DateFormat('d MMM yyyy, HH:mm', 'ro_RO').format(n.createdAt)}',
                            style: const TextStyle(fontSize: 12)),
                        isThreeLine: true,
                        onTap: () async {
                          if (n.isUnread) {
                            await ref.read(notificationRepositoryProvider).markRead(n.id);
                            ref.invalidate(inboxProvider);
                          }
                          if (n.route != null && context.mounted) context.push(n.route!);
                        },
                      );
                    },
                  ),
                ),
        ),
      ),
    );
  }
}
