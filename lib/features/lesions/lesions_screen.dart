import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:skynetic_app/features/lesions/lesion_models.dart';
import 'package:skynetic_app/features/lesions/lesion_providers.dart';
import 'package:skynetic_app/theme/app_theme.dart';
import 'package:skynetic_app/widgets/responsive_center.dart';

/// "Arhiva" tab for signed-in patients: lesions backed by the API.
class LesionsScreen extends ConsumerStatefulWidget {
  const LesionsScreen({super.key});

  @override
  ConsumerState<LesionsScreen> createState() => _LesionsScreenState();
}

class _LesionsScreenState extends ConsumerState<LesionsScreen> {
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final lesions = ref.watch(_showArchived ? archivedLesionsProvider : lesionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_showArchived ? 'Leziuni arhivate' : 'Leziunile mele'),
        actions: [
          IconButton(
            tooltip: _showArchived ? 'Leziuni active' : 'Leziuni arhivate',
            icon: Icon(_showArchived ? Icons.inventory_2 : Icons.inventory_2_outlined),
            onPressed: () => setState(() => _showArchived = !_showArchived),
          ),
        ],
      ),
      floatingActionButton: _showArchived
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                await context.push('/lesions/new');
                if (mounted) invalidateLesionData(ref);
              },
              backgroundColor: AppColors.accent2,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Leziune nouă'),
            ),
      body: RefreshIndicator(
        onRefresh: () async {
          invalidateLesionData(ref);
          await ref.read(_showArchived ? archivedLesionsProvider.future : lesionsProvider.future);
        },
        child: lesions.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _Message(
            icon: Icons.cloud_off,
            text: e.toString(),
            action: TextButton(onPressed: () => invalidateLesionData(ref), child: const Text('Reîncearcă')),
          ),
          data: (items) => items.isEmpty
              ? _Message(
                  icon: _showArchived ? Icons.inventory_2_outlined : Icons.add_a_photo_outlined,
                  text: _showArchived
                      ? 'Nu ai leziuni arhivate.'
                      : 'Nu ai adăugat încă nicio leziune.\nCreează una și fotografiază-o periodic pentru a urmări evoluția.',
                )
              : ResponsiveCenter(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => LesionCard(
                      lesion: items[i],
                      onTap: () async {
                        await context.push('/lesions/${items[i].id}');
                        if (mounted) invalidateLesionData(ref);
                      },
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

/// Summary row used in the lesions list and on the home screen.
class LesionCard extends StatelessWidget {
  final Lesion lesion;
  final VoidCallback onTap;
  const LesionCard({super.key, required this.lesion, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final latest = lesion.latestScanAt;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.radio_button_checked, color: AppColors.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lesion.label,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.primary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(lesion.locationLabel,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Text(
                      lesion.scanCount == 0
                          ? 'Nicio scanare încă'
                          : '${lesion.scanCount} ${lesion.scanCount == 1 ? 'scanare' : 'scanări'}'
                              '${latest != null ? ' · ultima ${DateFormat('d MMM yyyy', 'ro_RO').format(latest)}' : ''}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.accent1),
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? action;
  const _Message({required this.icon, required this.text, this.action});

  @override
  Widget build(BuildContext context) {
    // Inside a RefreshIndicator the content must be scrollable.
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 48),
        Icon(icon, size: 56, color: AppColors.accent1.withValues(alpha: 0.5)),
        const SizedBox(height: 16),
        Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, height: 1.4)),
        if (action != null) Center(child: action),
      ],
    );
  }
}
