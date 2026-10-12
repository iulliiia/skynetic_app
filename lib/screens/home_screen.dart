import 'package:flutter/material.dart';
import 'package:skynetic_app/widgets/responsive_center.dart';
import 'package:skynetic_app/models/saved_scans.dart';
import 'package:skynetic_app/screens/learn_screen.dart';
import 'package:skynetic_app/screens/photo_detail_screen.dart';
import 'package:skynetic_app/screens/profile_screen.dart';
import 'package:skynetic_app/screens/scan_screen.dart';
import 'package:skynetic_app/theme/app_theme.dart';
import 'package:skynetic_app/widgets/action_card.dart';
import 'package:skynetic_app/widgets/bottom_nav_bar.dart';
import 'package:skynetic_app/widgets/scan_image.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  void _selectTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  Widget _buildScreen() {
    switch (_currentIndex) {
      case 1:
        return const ScanScreen();
      case 2:
        return const ProfileScreen();
      case 3:
        return const LearnScreen();
      default:
        return HomeContent(onSelectTab: _selectTab);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildScreen(),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _selectTab,
      ),
    );
  }
}

class HomeContent extends StatefulWidget {
  /// Switches the bottom navigation tab (1 = scan, 2 = archive, 3 = learn).
  final ValueChanged<int>? onSelectTab;

  const HomeContent({super.key, this.onSelectTab});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  List<SavedScan> recentScans = [];

  @override
  void initState() {
    super.initState();
    _loadRecentScans();
  }

  Future<void> _loadRecentScans() async {
    await SavedScans.load();
    if (!mounted) return;
    setState(() {
      recentScans = List.from(SavedScans.list.reversed.take(5));
    });
  }

  Future<void> _open(int tab, Widget screen) async {
    if (widget.onSelectTab != null) {
      widget.onSelectTab!(tab);
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    _loadRecentScans();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ResponsiveCenter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bine ai venit!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
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
                  subtitle:
                      'Consultă rezultatele anterioare ale scanărilor tale.',
                  icon: Icons.history,
                  onTap: () => _open(2, const ProfileScreen()),
                ),
                const SizedBox(height: 8),
                ActionCard(
                  title: 'Ai grija de pielea ta',
                  subtitle:
                      'Care sunt tipurile de cancer de piele. Simptome și prevenție.',
                  icon: Icons.book_outlined,
                  onTap: () => _open(3, const LearnScreen()),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Scanări recente',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),
                if (recentScans.isEmpty)
                  Center(
                    child: Column(
                    children: [
                      Icon(
                        Icons.history,
                        size: 48,
                        color: AppColors.accent1.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Nicio scanare recentă',
                        style: TextStyle(
                          color: AppColors.textSecondary.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: recentScans.length + 1,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
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
                              MaterialPageRoute(
                                builder: (_) => PhotoDetailScreen(
                                  scan: scan,
                                ),
                              ),
                            );
                            _loadRecentScans();
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: ScanImage(path: scan.imagePath),
                          ),
                        );
                      } else {
                        return GestureDetector(
                          onTap: () => _open(2, const ProfileScreen()),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: AppColors.accent1.withValues(alpha: 0.1),
                              border: Border.all(color: AppColors.accent1),
                            ),
                            child: const Center(
                              child: Text(
                                'Vezi arhiva',
                                style: TextStyle(
                                  color: AppColors.accent1,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
