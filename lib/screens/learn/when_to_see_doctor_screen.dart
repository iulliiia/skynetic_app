import 'package:flutter/material.dart';
import 'package:skynetic_app/theme/app_theme.dart';

class WhenToSeeDoctorScreen extends StatelessWidget {
  const WhenToSeeDoctorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Când să mergi la medic'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Când mergi la Doctor?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Deși majoritatea leziunilor cutanate sunt benigne, este important să știi când ar trebui să consulți un dermatolog sau un medic specialist.',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              _buildWarningSignCard(
                'Alunițe Noi Sau Care Se Modifică',
                'Orice aluniță nouă sau care își schimbă dimensiunea, forma sau culoarea ar trebui evaluată de un medic.',
                Icons.warning_amber,
              ),
              _buildWarningSignCard(
                'Semne De Avertizare ABCDE',
                'Dacă o aluniță prezintă oricare dintre semnele ABCDE (Asimetrie, Margini neregulate, Culoare variabilă, Diametru >6mm, Evoluție).',
                Icons.list_alt,
              ),
              _buildWarningSignCard(
                'Sângerare Sau Mâncărime',
                'Alunițele care sângerează, provoacă mâncărimi sau devin dureroase fără să fi fost rănite trebuie verificate imediat.',
                Icons.healing,
              ),
              _buildWarningSignCard(
                'Răni Care Nu Se Vindecă',
                'Orice rană care nu se vindecă în 3-4 săptămâni trebuie evaluată de un medic.',
                Icons.medical_services,
              ),
              _buildWarningSignCard(
                'Istoric Familial',
                'Dacă ai un istoric familial de cancer de piele, este recomandat să faci controale dermatologice regulate.',
                Icons.family_restroom,
              ),
              _buildWarningSignCard(
                'Cancer De Piele Anterior',
                'Dacă ai avut anterior cancer de piele, ești expus unui risc mai mare și ar trebui să faci controale regulate.',
                Icons.history,
              ),
              _buildWarningSignCard(
                'Expunere Excesivă La Soare',
                'Dacă ai avut expuneri intense la soare sau arsuri solare, în special în copilărie, este indicat să fii monitorizat regulat.',
                Icons.wb_sunny,
              ),
              const SizedBox(height: 24),
              const Text(
                'Cum găsești un Dermatolog',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Pentru a găsi un dermatolog, poți cere o recomandare de la medicul de familie, poți verifica cu furnizorul tău de asigurări pentru specialiști incluși în rețea sau poți căuta online dermatologi acreditați din zona ta.',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.accent2.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accent2),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.accent3),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Ține minte: Detectarea timpurie este cheia tratamentului eficient al cancerului de piele.',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.accent3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWarningSignCard(
    String title,
    String description,
    IconData icon,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.accent3, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textPrimary,
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
