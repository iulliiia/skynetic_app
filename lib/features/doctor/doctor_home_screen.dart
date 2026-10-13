import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skynetic_app/core/auth/auth_controller.dart';
import 'package:skynetic_app/core/auth/auth_models.dart';
import 'package:skynetic_app/features/notifications/notifications.dart';
import 'package:skynetic_app/features/review/review_models.dart';
import 'package:skynetic_app/features/review/review_providers.dart';
import 'package:skynetic_app/features/review/review_widgets.dart';
import 'package:skynetic_app/theme/app_theme.dart';
import 'package:skynetic_app/widgets/responsive_center.dart';

/// Landing screen for doctor (and admin) accounts: the review dashboard for
/// approved doctors, otherwise the verification status.
class DoctorHomeScreen extends ConsumerStatefulWidget {
  const DoctorHomeScreen({super.key});

  @override
  ConsumerState<DoctorHomeScreen> createState() => _DoctorHomeScreenState();
}

class _DoctorHomeScreenState extends ConsumerState<DoctorHomeScreen> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    try {
      await ref.read(authControllerProvider.notifier).refreshUser();
      if (mounted) invalidateReviewData(ref);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;
    final approved = user?.isApprovedDoctor ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(approved ? 'Cazurile mele' : 'Contul meu'),
        actions: [
          if (approved) const NotificationBell(),
          IconButton(
            tooltip: 'Confidențialitate și date',
            icon: const Icon(Icons.privacy_tip_outlined),
            onPressed: () => context.push('/privacy'),
          ),
          IconButton(
            tooltip: 'Deconectare',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: SafeArea(
        child: approved
            ? _Dashboard(onRefresh: _refresh)
            : RefreshIndicator(
                onRefresh: _refresh,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  child: ResponsiveCenter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(user == null ? '' : 'Dr. ${user.displayName}',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        const SizedBox(height: 4),
                        Text(user?.email ?? '', style: const TextStyle(color: AppColors.textSecondary)),
                        const SizedBox(height: 24),
                        if (user?.role == UserRole.admin)
                          const _StatusCard(
                            icon: Icons.admin_panel_settings_outlined,
                            color: AppColors.primary,
                            title: 'Cont de administrator',
                            body: 'Administrarea conturilor de medic se face din interfața web (/admin), nu din aplicația mobilă.',
                          )
                        else
                          _StatusCard.forStatus(user?.doctorStatus ?? DoctorVerificationStatus.pending),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _refreshing ? null : _refresh,
                          icon: _refreshing
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.refresh),
                          label: const Text('Reîncarcă starea contului'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _Dashboard extends ConsumerStatefulWidget {
  final Future<void> Function() onRefresh;
  const _Dashboard({required this.onRefresh});

  @override
  ConsumerState<_Dashboard> createState() => _DashboardState();
}

class _DashboardState extends ConsumerState<_Dashboard> {
  String _group = 'open';

  @override
  Widget build(BuildContext context) {
    final dash = ref.watch(doctorDashboardProvider);
    final cases = ref.watch(doctorCasesProvider(_group));
    return RefreshIndicator(
      onRefresh: () async {
        invalidateReviewData(ref);
        await ref.read(doctorCasesProvider(_group).future);
      },
      child: ResponsiveCenter(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            dash.maybeWhen(
              data: (d) => Row(
                children: [
                  _Stat('În așteptare', d.pending, ReviewStatus.color(ReviewStatus.pending)),
                  const SizedBox(width: 8),
                  _Stat('În evaluare', d.accepted, ReviewStatus.color(ReviewStatus.accepted)),
                  const SizedBox(width: 8),
                  _Stat('Info', d.needsInfo, ReviewStatus.color(ReviewStatus.needsInfo)),
                  const SizedBox(width: 8),
                  _Stat('Finalizate', d.completed, ReviewStatus.color(ReviewStatus.completed)),
                ],
              ),
              orElse: () => const SizedBox(height: 72, child: Center(child: CircularProgressIndicator())),
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'open', label: Text('Deschise'), icon: Icon(Icons.inbox_outlined)),
                ButtonSegment(value: 'closed', label: Text('Închise'), icon: Icon(Icons.done_all)),
              ],
              selected: {_group},
              onSelectionChanged: (s) => setState(() => _group = s.first),
            ),
            const SizedBox(height: 12),
            cases.when(
              loading: () => const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Text(e.toString(), style: const TextStyle(color: Colors.red)),
              data: (items) => items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(children: [
                        Icon(Icons.inbox_outlined, size: 56, color: AppColors.accent1.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        Text(_group == 'open' ? 'Niciun caz deschis.' : 'Niciun caz închis.',
                            style: const TextStyle(color: AppColors.textSecondary)),
                      ]),
                    )
                  : Column(
                      children: [
                        for (final r in items)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: RequestCard(
                              request: r,
                              doctorView: true,
                              onTap: () async {
                                await context.push('/review-requests/${r.id}');
                                if (context.mounted) invalidateReviewData(ref);
                              },
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _Stat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Text('$value', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  const _StatusCard({required this.icon, required this.color, required this.title, required this.body});

  factory _StatusCard.forStatus(DoctorVerificationStatus status) {
    switch (status) {
      case DoctorVerificationStatus.approved:
        return const _StatusCard(
          icon: Icons.verified_outlined, color: Colors.green, title: 'Cont verificat',
          body: 'Datele profesionale au fost confirmate.',
        );
      case DoctorVerificationStatus.rejected:
        return const _StatusCard(
          icon: Icons.cancel_outlined, color: Colors.red, title: 'Verificare respinsă',
          body: 'Datele transmise nu au putut fi confirmate. Contactează administratorul pentru detalii și pentru a retrimite documentele.',
        );
      case DoctorVerificationStatus.suspended:
        return const _StatusCard(
          icon: Icons.pause_circle_outline, color: Colors.orange, title: 'Drepturi suspendate',
          body: 'Accesul la evaluarea cazurilor a fost suspendat de un administrator.',
        );
      case DoctorVerificationStatus.pending:
        return const _StatusCard(
          icon: Icons.hourglass_top, color: AppColors.accent3, title: 'În curs de verificare',
          body: 'Un administrator verifică datele profesionale transmise. Vei putea evalua cazuri după aprobare.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
                const SizedBox(height: 6),
                Text(body, style: const TextStyle(height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
