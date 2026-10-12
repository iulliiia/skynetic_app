import 'package:flutter/material.dart';
import 'package:skynetic_app/widgets/responsive_center.dart';
import 'package:skynetic_app/screens/learn/abcde_screen.dart';
import 'package:skynetic_app/screens/learn/prevention_screen.dart';
import 'package:skynetic_app/screens/learn/skin_care_screen.dart';
import 'package:skynetic_app/screens/learn/when_to_see_doctor_screen.dart';
import 'package:skynetic_app/theme/app_theme.dart';
import 'package:skynetic_app/widgets/learn_card.dart';

class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cunoaște-ți pielea'),
      ),
      body: ResponsiveCenter(
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            const Text(
              'Învață. Aplică. Trăiește sănătos.',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Învață despre prevenția și depistarea cancerului de piele',
              style: TextStyle(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            LearnCard(
              title: 'Criteriile ABCDE',
              description: 'Află cum să recunoști alunițele suspecte',
              icon: Icons.list_alt,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ABCDEScreen()),
                );
              },
            ),
            const SizedBox(height: 10),
            LearnCard(
              title: 'Sfaturi de prevenție',
              description: 'Cum să-ți protejezi pielea de soare',
              icon: Icons.wb_sunny,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PreventionScreen()),
                );
              },
            ),
            const SizedBox(height: 10),
            LearnCard(
              title: 'Îngrijirea pielii',
              description: 'Recomandări pentru o piele sănătoasă',
              icon: Icons.healing,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SkinCareScreen()),
                );
              },
            ),
            const SizedBox(height: 10),
            LearnCard(
              title: 'Când să mergi la medic',
              description: 'Semnale de alarmă care necesită consult medical',
              icon: Icons.medical_services,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const WhenToSeeDoctorScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
