import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skynetic_app/features/lesions/lesion_models.dart';
import 'package:skynetic_app/features/lesions/lesion_providers.dart';
import 'package:skynetic_app/theme/app_theme.dart';

/// Asks the patient which lesion a photo belongs to. Returns null when
/// dismissed. "Leziune nouă" opens the form and returns the created lesion.
Future<Lesion?> showLesionPicker(BuildContext context) {
  return showModalBottomSheet<Lesion>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => const _LesionPickerSheet(),
  );
}

class _LesionPickerSheet extends ConsumerWidget {
  const _LesionPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lesions = ref.watch(lesionsProvider);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                'Cărei leziuni îi aparține fotografia?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.accent2,
                child: Icon(Icons.add, color: Colors.white),
              ),
              title: const Text('Leziune nouă', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Prima fotografie a unei leziuni noi'),
              onTap: () async {
                final created = await context.push<Lesion>('/lesions/new');
                if (created != null && context.mounted) Navigator.of(context).pop(created);
              },
            ),
            const Divider(height: 1),
            Flexible(
              child: lesions.when(
                loading: () => const Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(e.toString(), style: const TextStyle(color: Colors.red)),
                ),
                data: (items) => items.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Nu ai leziuni salvate încă.', style: TextStyle(color: AppColors.textSecondary)),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: items.length,
                        itemBuilder: (_, i) => ListTile(
                          leading: const Icon(Icons.radio_button_checked, color: AppColors.primary),
                          title: Text(items[i].label),
                          subtitle: Text(items[i].locationLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: Text('${items[i].scanCount}', style: const TextStyle(color: Colors.grey)),
                          onTap: () => Navigator.of(context).pop(items[i]),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
