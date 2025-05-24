import 'dart:io';

import 'package:flutter/material.dart';
import 'package:skynetic_app/models/saved_scans.dart';
import 'package:skynetic_app/screens/learn_screen.dart';
import 'package:skynetic_app/screens/photo_detail_screen.dart';
import 'package:skynetic_app/screens/profile_screen.dart';
import 'package:skynetic_app/screens/scan_screen.dart';
import 'package:skynetic_app/theme/app_theme.dart';
import 'package:skynetic_app/widgets/action_card.dart';
import 'package:skynetic_app/widgets/bottom_nav_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeContent(),
    const ScanScreen(),
    const ProfileScreen(),
    const LearnScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

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
    setState(() {
      recentScans = List.from(SavedScans.list.reversed.take(5));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bine ai venit!',
                textAlign: TextAlign.center,
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
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ScanScreen()),
                  );
                },
              ),
              const SizedBox(height: 8),
              ActionCard(
                title: 'Urmărește evoluția',
                subtitle:
                    'Consultă rezultatele anterioare ale scanărilor tale.',
                icon: Icons.history,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  );
                },
              ),
              const SizedBox(height: 8),
              ActionCard(
                title: 'Ai grija de pielea ta',
                subtitle:
                    'Care sunt tipurile de cancer de piele. Simptome și prevenție.',
                icon: Icons.book_outlined,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LearnScreen()),
                  );
                },
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
                Column(
                  children: [
                    Icon(
                      Icons.history,
                      size: 48,
                      color: AppColors.accent1.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Nicio scanare recentă',
                      style: TextStyle(
                        color: AppColors.textSecondary.withOpacity(0.7),
                      ),
                    ),
                  ],
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
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PhotoDetailScreen(
                                imagePath: scan.imagePath,
                                classId: scan.classId,
                              ),
                            ),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(scan.imagePath),
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    } else {
                      return GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const ProfileScreen()),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: AppColors.accent1.withOpacity(0.1),
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
    );
  }
}
