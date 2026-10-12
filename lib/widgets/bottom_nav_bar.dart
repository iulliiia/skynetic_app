import 'package:flutter/material.dart';
import 'package:skynetic_app/theme/app_theme.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color:
                const Color.fromARGB(255, 68, 68, 68).withValues(alpha: 0.15),
            blurRadius: 15,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.accent2,
        unselectedItemColor: AppColors.accent1,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Acasa',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt),
            label: 'Scaneaza',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Arhiva',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.book),
            label: 'Curiozitati',
          ),
        ],
      ),
    );
  }
}
