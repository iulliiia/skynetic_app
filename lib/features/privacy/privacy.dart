import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:skynetic_app/core/api/api_client.dart';
import 'package:skynetic_app/core/api/api_error.dart';
import 'package:skynetic_app/core/auth/auth_controller.dart';
import 'package:skynetic_app/core/providers.dart';
import 'package:skynetic_app/models/saved_scans.dart';
import 'package:skynetic_app/theme/app_theme.dart';
import 'package:skynetic_app/widgets/responsive_center.dart';

/// Current notice of a purpose.
class ConsentNotice {
  final String purpose;
  final String version;
  final String titleRo;
  final String bodyRo;
  final bool isMandatory;
  const ConsentNotice({required this.purpose, required this.version, required this.titleRo, required this.bodyRo, required this.isMandatory});

  factory ConsentNotice.fromJson(Map<String, dynamic> j) => ConsentNotice(
        purpose: j['purpose'] as String,
        version: j['version'] as String,
        titleRo: j['title_ro'] as String,
        bodyRo: j['body_ro'] as String,
        isMandatory: j['is_mandatory'] as bool? ?? false,
      );
}

/// The user's decision for one purpose.
class ConsentState {
  final String purpose;
  final String status; // granted | withdrawn | undecided
  final String? noticeVersion;
  final ConsentNotice notice;
  final bool outdated;

  const ConsentState({required this.purpose, required this.status, this.noticeVersion, required this.notice, required this.outdated});

  bool get granted => status == 'granted';
  bool get undecided => status == 'undecided';

  factory ConsentState.fromJson(Map<String, dynamic> j) => ConsentState(
        purpose: j['purpose'] as String,
        status: j['status'] as String,
        noticeVersion: j['notice_version'] as String?,
        notice: ConsentNotice.fromJson(j['current_notice'] as Map<String, dynamic>),
        outdated: j['outdated'] as bool? ?? false,
      );
}

class DataRequest {
  final String id;
  final String type;
  final String status;
  final DateTime requestedAt;
  const DataRequest({required this.id, required this.type, required this.status, required this.requestedAt});

  factory DataRequest.fromJson(Map<String, dynamic> j) => DataRequest(
        id: j['id'] as String,
        type: j['type'] as String,
        status: j['status'] as String,
        requestedAt: DateTime.tryParse(j['requested_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      );
}

abstract class PrivacyRepository {
  Future<List<ConsentState>> states();
  Future<void> grant(String purpose, String noticeVersion);
  Future<void> withdraw(String purpose);
  Future<List<DataRequest>> myRequests();
  Future<DataRequest> openRequest(String type);
  Future<Map<String, dynamic>> export();
}

class ApiPrivacyRepository implements PrivacyRepository {
  final ApiClient _client;
  ApiPrivacyRepository(this._client);

  @override
  Future<List<ConsentState>> states() async =>
      ((await _client.getJson('/consents'))['items'] as List).cast<Map<String, dynamic>>().map(ConsentState.fromJson).toList();

  @override
  Future<void> grant(String purpose, String noticeVersion) =>
      _client.postJson('/consents', body: {'purpose': purpose, 'notice_version': noticeVersion});

  @override
  Future<void> withdraw(String purpose) => _client.postJson('/consents/$purpose/withdraw');

  @override
  Future<List<DataRequest>> myRequests() async =>
      ((await _client.getJson('/data-requests'))['items'] as List).cast<Map<String, dynamic>>().map(DataRequest.fromJson).toList();

  @override
  Future<DataRequest> openRequest(String type) async => DataRequest.fromJson(await _client.postJson('/data-requests', body: {'type': type}));

  @override
  Future<Map<String, dynamic>> export() => _client.getJson('/me/export');
}

final privacyRepositoryProvider = Provider<PrivacyRepository>((ref) => ApiPrivacyRepository(ref.watch(apiClientProvider)));
final consentStatesProvider = FutureProvider<List<ConsentState>>((ref) => ref.watch(privacyRepositoryProvider).states());
final dataRequestsProvider = FutureProvider<List<DataRequest>>((ref) => ref.watch(privacyRepositoryProvider).myRequests());

/// True when the signed-in patient has never decided about research use.
final researchUndecidedProvider = Provider<bool>((ref) {
  final states = ref.watch(consentStatesProvider).value;
  if (states == null) return false;
  final r = states.where((s) => s.purpose == 'research');
  return r.isNotEmpty && r.first.undecided;
});

const _purposeIcons = {
  'service': Icons.settings_suggest_outlined,
  'doctor_review': Icons.medical_services_outlined,
  'research': Icons.science_outlined,
  'communications': Icons.notifications_outlined,
};

/// Privacy & data screen: per-purpose consent, data export, deletion request.
class PrivacyScreen extends ConsumerStatefulWidget {
  const PrivacyScreen({super.key});

  @override
  ConsumerState<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends ConsumerState<PrivacyScreen> {
  String? _busyPurpose;
  bool _exporting = false;

  Future<void> _toggle(ConsentState s, bool on) async {
    if (on) {
      final ok = await showModalBottomSheet<bool>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (ctx) => _NoticeSheet(notice: s.notice),
      );
      if (ok != true || !mounted) return;
    } else {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Retragi acordul?'),
          content: Text(s.purpose == 'research'
              ? 'Datele tale nu vor mai fi incluse în niciun export viitor pentru cercetare. Exporturile deja realizate nu pot fi retrase.'
              : 'Poți reactiva oricând această opțiune.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Anulează')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Retrage')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() => _busyPurpose = s.purpose);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repo = ref.read(privacyRepositoryProvider);
      if (on) {
        await repo.grant(s.purpose, s.notice.version);
      } else {
        await repo.withdraw(s.purpose);
      }
      ref.invalidate(consentStatesProvider);
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busyPurpose = null);
    }
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final data = await ref.read(privacyRepositoryProvider).export();
      final json = const JsonEncoder.withIndent('  ').convert(data);
      String where = 'în memorie';
      try {
        // Same time-limited, test-safe directory lookup as the local scans.
        final dir = await SavedScans.directoryResolver();
        if (dir != null) {
          final file = File('${dir.path}/skynetic-export-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}.json');
          await file.writeAsString(json);
          where = file.path;
        }
      } catch (_) {}
      messenger.showSnackBar(SnackBar(content: Text('Export generat (${(json.length / 1024).toStringAsFixed(1)} KB): $where')));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _requestDeletion() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ștergerea contului'),
        content: const Text(
          'Cererea este verificată de un administrator. Datele de identificare, fotografiile neevaluate și notificările vor fi șterse. '
          'Fotografiile și evaluările care fac parte dintr-o consultație finalizată se păstrează în formă pseudonimizată, ca înregistrare medicală, pe durata prevăzută de lege.\n\n'
          'Contul devine inaccesibil imediat după trimiterea cererii.',
          style: TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Anulează')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Trimite cererea'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(privacyRepositoryProvider).openRequest('deletion');
      messenger.showSnackBar(const SnackBar(content: Text('Cererea de ștergere a fost înregistrată.')));
      await ref.read(authControllerProvider.notifier).logout();
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final states = ref.watch(consentStatesProvider);
    final requests = ref.watch(dataRequestsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Confidențialitate și date')),
      body: states.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(e.toString(), textAlign: TextAlign.center))),
        data: (items) => ResponsiveCenter(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Alegi separat pentru fiecare scop. Acordurile opționale pot fi retrase oricând; istoricul deciziilor tale este păstrat.',
                style: TextStyle(color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 12),
              for (final s in items) _ConsentTile(state: s, busy: _busyPurpose == s.purpose, onChanged: (v) => _toggle(s, v)),
              const SizedBox(height: 24),
              const Text('Datele tale', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
              const SizedBox(height: 8),
              Card(
                margin: EdgeInsets.zero,
                child: Column(children: [
                  ListTile(
                    leading: const Icon(Icons.download_outlined, color: AppColors.primary),
                    title: const Text('Descarcă o copie a datelor mele'),
                    subtitle: const Text('Cont, leziuni, scanări, evaluări, mesaje, acorduri (JSON).'),
                    trailing: _exporting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.chevron_right),
                    onTap: _exporting ? null : _export,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.delete_forever_outlined, color: Colors.red),
                    title: const Text('Solicită ștergerea contului'),
                    subtitle: const Text('Verificată de un administrator; contul devine inaccesibil imediat.'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _requestDeletion,
                  ),
                ]),
              ),
              requests.maybeWhen(
                data: (list) => list.isEmpty
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          for (final r in list)
                            Text('Cerere de ${r.type == 'deletion' ? 'ștergere' : 'acces'} · ${r.status} · ${DateFormat('d MMM yyyy', 'ro_RO').format(r.requestedAt)}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ]),
                      ),
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConsentTile extends StatelessWidget {
  final ConsentState state;
  final bool busy;
  final ValueChanged<bool> onChanged;
  const _ConsentTile({required this.state, required this.busy, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final s = state;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_purposeIcons[s.purpose] ?? Icons.policy_outlined, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.notice.titleRo, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(s.notice.bodyRo, style: const TextStyle(fontSize: 13, height: 1.35, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  Text(
                    s.notice.isMandatory
                        ? 'Necesar pentru funcționarea aplicației · versiunea ${s.notice.version}'
                        : s.undecided
                            ? 'Nu ai decis încă'
                            : '${s.granted ? 'Acord dat' : 'Acord retras'}${s.outdated ? ' · există o versiune nouă a notei' : ''} · versiunea ${s.noticeVersion ?? s.notice.version}',
                    style: TextStyle(fontSize: 11, color: s.outdated ? Colors.orange : Colors.grey),
                  ),
                ],
              ),
            ),
            if (s.notice.isMandatory)
              const Padding(padding: EdgeInsets.all(12), child: Icon(Icons.lock_outline, color: Colors.grey))
            else if (busy)
              const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
            else
              Switch(value: s.granted, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _NoticeSheet extends StatelessWidget {
  final ConsentNotice notice;
  const _NoticeSheet({required this.notice});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(notice.titleRo, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
            const SizedBox(height: 4),
            Text('Versiunea ${notice.version}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            Text(notice.bodyRo, style: const TextStyle(height: 1.5)),
            if (notice.purpose == 'research') ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.accent2.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: const Text(
                  'Ce se exportă: fotografii și date structurate (localizare, simptome, rezultatul analizei automate, evaluarea medicului), sub un pseudonim. '
                  'Ce NU se exportă: nume, email, note libere, mesaje, data exactă a nașterii (doar grupa de vârstă).',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sunt de acord')),
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Nu acum')),
          ],
        ),
      ),
    );
  }
}

/// Home banner for patients who have not decided about research use.
class ResearchConsentBanner extends ConsumerWidget {
  const ResearchConsentBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(researchUndecidedProvider)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.accent1.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            await context.push('/privacy');
            ref.invalidate(consentStatesProvider);
          },
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: Row(children: [
              Icon(Icons.science_outlined, color: AppColors.accent1),
              SizedBox(width: 12),
              Expanded(
                child: Text('Vrei să contribui la cercetare? Decide cum pot fi folosite datele tale.',
                    style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.accent1)),
              ),
              Icon(Icons.chevron_right, color: AppColors.accent1),
            ]),
          ),
        ),
      ),
    );
  }
}
