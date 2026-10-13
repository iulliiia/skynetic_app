import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skynetic_app/features/review/review_providers.dart';
import 'package:skynetic_app/features/review/review_widgets.dart';
import 'package:skynetic_app/theme/app_theme.dart';
import 'package:skynetic_app/widgets/responsive_center.dart';

/// Patient: list of their medical review requests.
class MyRequestsScreen extends ConsumerWidget {
  const MyRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(myRequestsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Evaluările mele')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myRequestsProvider);
          await ref.read(myRequestsProvider.future);
        },
        child: requests.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(padding: const EdgeInsets.all(24), children: [
            Text(e.toString(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
            TextButton(onPressed: () => ref.invalidate(myRequestsProvider), child: const Text('Reîncearcă')),
          ]),
          data: (items) => items.isEmpty
              ? ListView(padding: const EdgeInsets.all(32), children: [
                  const SizedBox(height: 48),
                  Icon(Icons.medical_services_outlined, size: 56, color: AppColors.accent1.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  const Text(
                    'Nu ai cerut încă nicio evaluare.\nDeschide o scanare din leziunile tale și apasă „Solicită evaluare medicală”.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, height: 1.4),
                  ),
                ])
              : ResponsiveCenter(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => RequestCard(
                      request: items[i],
                      onTap: () async {
                        await context.push('/review-requests/${items[i].id}');
                        if (context.mounted) invalidateReviewData(ref);
                      },
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
