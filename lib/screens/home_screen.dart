import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skynetic_app/core/auth/auth_controller.dart';
import 'package:skynetic_app/features/lesions/lesion_providers.dart';
import 'package:skynetic_app/features/lesions/lesions_screen.dart';
import 'package:skynetic_app/features/notifications/notifications.dart';
import 'package:skynetic_app/features/privacy/privacy.dart';
import 'package:skynetic_app/models/saved_scans.dart';
import 'package:skynetic_app/screens/learn_screen.dart';
import 'package:skynetic_app/screens/photo_detail_screen.dart';
import 'package:skynetic_app/screens/profile_screen.dart';
import 'package:skynetic_app/screens/scan_screen.dart';
import 'package:skynetic_app/theme/app_theme.dart';
import 'package:skynetic_app/widgets/action_card.dart';
import 'package:skynetic_app/widgets/bottom_nav_bar.dart';
import 'package:skynetic_app/widgets/responsive_center.dart';
import 'package:skynetic_app/widgets/scan_image.dart';

/// Tab shell. The archive tab shows API-backed lesions for signed-in
/// patients and the local archive for guests.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  void _selectTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  Widget _buildScreen(bool isPatient) {
    switch (_currentIndex) {
      case 1:
        return const ScanScreen();
      case 2:
        return isPatient ? const LesionsScreen() : const ProfileScreen();
      case 3:
        return const LearnScreen();
      default:
        return HomeContent(onSelectTab: _selectTab);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPatient = ref.watch(authControllerProvider).isPatient;
    return Scaffold(
      body: _buildScreen(isPatient),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _selectTab,
      ),
    );
  }
}

class HomeContent extends ConsumerStatefulWidget {
  /// Switches the bottom navigation tab (1 = scan, 2 = archive, 3 = learn).
  final ValueChanged<int>? onSelectTab;

  const HomeContent({super.key, this.onSelectTab});

  @override
  ConsumerState<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends ConsumerState<HomeContent> {
  List<SavedScan> recentScans = [];
  int claimable = 0;

  @override
  void initState() {
    super.initState();
    _loadLocalScans();
  }

  Future<void> _loadLocalScans() async {
    await SavedScans.load();
    if (!mounted) return;
    setState(() {
      recentScans = List.from(SavedScans.list.reversed.take(5));
      claimable = SavedScans.claimable.length;
    });
  }

  Future<void> _open(int tab, Widget screen) async {
    if (widget.onSelectTab != null) {
      widget.onSelectTab!(tab);
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    _loadLocalScans();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ResponsiveCenter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        auth.isAuthenticated && user != null && user.firstName != null
                            ? 'Bine ai venit, ${user.firstName}!'
                            : 'Bine ai venit!',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (auth.isAuthenticated) const NotificationBell(),
                    _AccountButton(auth: auth),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Gata să ai grijă de pielea ta? Alege ce facem azi.',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 10),
                if (auth.isPatient) const ResearchConsentBanner(),
                if (auth.isPatient && claimable > 0) ...[
                  _ClaimBanner(
                    count: claimable,
                    onTap: () async {
                      await context.push('/claim');
                      _loadLocalScans();
                    },
                  ),
                  const SizedBox(height: 8),
                ],
                ActionCard(
                  title: 'Fă/încarcă o fotografie',
                  subtitle:
                      'Trimite o imagine cu pielea ta pentru a o analiza automat.',
                  icon: Icons.camera_alt_outlined,
                  onTap: () => _open(1, const ScanScreen()),
                ),
                const SizedBox(height: 8),
                ActionCard(
                  title: 'Urmărește evoluția',
                  subtitle: auth.isPatient
                      ? 'Leziunile tale și istoricul scanărilor.'
                      : 'Consultă rezultatele anterioare ale scanărilor tale.',
                  icon: Icons.history,
                  onTap: () => _open(2, auth.isPatient ? const LesionsScreen() : const ProfileScreen()),
                ),
                const SizedBox(height: 8),
                if (auth.isPatient) ...[
                  ActionCard(
                    title: 'Evaluările mele',
                    subtitle: 'Cererile trimise medicului dermatolog și răspunsurile primite.',
                    icon: Icons.medical_services_outlined,
                    onTap: () => context.push('/review-requests'),
                  ),
                  const SizedBox(height: 8),
                ],
                ActionCard(
                  title: 'Ai grija de pielea ta',
                  subtitle:
                      'Care sunt tipurile de cancer de piele. Simptome și prevenție.',
                  icon: Icons.book_outlined,
                  onTap: () => _open(3, const LearnScreen()),
                ),
                const SizedBox(height: 24),
                if (auth.isPatient) _PatientLesionsSection(onSeeAll: () => _open(2, const LesionsScreen()))
                else _GuestRecentScans(recentScans: recentScans, onChanged: _loadLocalScans, onArchive: () => _open(2, const ProfileScreen())),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountButton extends ConsumerWidget {
  final AuthState auth;
  const _AccountButton({required this.auth});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (auth.isLoading) return const SizedBox(width: 40, height: 40);
    if (!auth.isAuthenticated) {
      return OutlinedButton.icon(
        onPressed: () => context.push('/login'),
        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
        icon: const Icon(Icons.person_outline, size: 18),
        label: const Text('Cont'),
      );
    }
    return PopupMenuButton<String>(
      tooltip: auth.user?.email,
      icon: CircleAvatar(
        backgroundColor: AppColors.accent2,
        child: Text(
          (auth.user?.displayName ?? '?').substring(0, 1).toUpperCase(),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      onSelected: (v) {
        if (v == 'logout') ref.read(authControllerProvider.notifier).logout();
        if (v == 'privacy') context.push('/privacy');
      },
      itemBuilder: (_) => [
        PopupMenuItem(enabled: false, child: Text(auth.user?.email ?? '', style: const TextStyle(fontSize: 12))),
        const PopupMenuItem(value: 'privacy', child: Text('Confidențialitate și date')),
        const PopupMenuItem(value: 'logout', child: Text('Deconectare')),
      ],
    );
  }
}

class _ClaimBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _ClaimBanner({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.accent2.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.link, color: AppColors.accent3),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  count == 1
                      ? 'Ai o scanare făcută fără cont. Adaugă-o la o leziune.'
                      : 'Ai $count scanări făcute fără cont. Adaugă-le la leziunile tale.',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.accent3),
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.accent3),
            ],
          ),
        ),
      ),
    );
  }
}

class _PatientLesionsSection extends ConsumerWidget {
  final VoidCallback onSeeAll;
  const _PatientLesionsSection({required this.onSeeAll});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lesions = ref.watch(lesionsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Leziunile mele',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ),
            TextButton(onPressed: onSeeAll, child: const Text('Vezi toate')),
          ],
        ),
        const SizedBox(height: 8),
        lesions.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
          error: (e, _) => Text(e.toString(), style: const TextStyle(color: Colors.red)),
          data: (items) => items.isEmpty
              ? Column(
                  children: [
                    Icon(Icons.add_a_photo_outlined, size: 48, color: AppColors.accent1.withValues(alpha: 0.5)),
                    const SizedBox(height: 12),
                    const Text('Nu ai adăugat încă nicio leziune.',
                        style: TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await context.push('/lesions/new');
                        if (context.mounted) invalidateLesionData(ref);
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Adaugă prima leziune'),
                    ),
                  ],
                )
              : Column(
                  children: [
                    for (final l in items.take(3))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: LesionCard(
                          lesion: l,
                          onTap: () async {
                            await context.push('/lesions/${l.id}');
                            if (context.mounted) invalidateLesionData(ref);
                          },
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _GuestRecentScans extends StatelessWidget {
  final List<SavedScan> recentScans;
  final VoidCallback onChanged;
  final VoidCallback onArchive;
  const _GuestRecentScans({required this.recentScans, required this.onChanged, required this.onArchive});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Scanări recente',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
        ),
        const SizedBox(height: 16),
        if (recentScans.isEmpty)
          Center(
            child: Column(
              children: [
                Icon(Icons.history, size: 48, color: AppColors.accent1.withValues(alpha: 0.5)),
                const SizedBox(height: 16),
                Text('Nicio scanare recentă',
                    style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.7))),
              ],
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recentScans.length + 1,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemBuilder: (context, index) {
              if (index < recentScans.length) {
                final scan = recentScans[index];
                return GestureDetector(
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => PhotoDetailScreen(scan: scan)),
                    );
                    onChanged();
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ScanImage(path: scan.imagePath),
                  ),
                );
              }
              return GestureDetector(
                onTap: onArchive,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: AppColors.accent1.withValues(alpha: 0.1),
                    border: Border.all(color: AppColors.accent1),
                  ),
                  child: const Center(
                    child: Text(
                      'Vezi arhiva',
                      style: TextStyle(color: AppColors.accent1, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
