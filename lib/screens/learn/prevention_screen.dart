import 'package:flutter/material.dart';
import 'package:skynetic_app/theme/app_theme.dart';

class PreventionScreen extends StatelessWidget {
  const PreventionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sfaturi de prevenție'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cum să previi cancerul de piele',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Protejarea pielii împotriva soarelui este cea mai importantă metodă de prevenire a cancerului de piele. Iată câteva sfaturi care te pot ajuta să rămâi în siguranță.',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              _buildPreventionCard(
                'Folosește cremă de protecție solară',
                'Aplică zilnic o cremă cu spectru larg și SPF de cel puțin 30, chiar și în zilele înnorate. Reaplică la fiecare două ore sau mai des dacă înoți sau transpiri.',
                Icons.wb_sunny,
              ),
              _buildPreventionCard(
                'Stai la umbră',
                'Evită expunerea directă la soare în orele de vârf, în general între 10:00 și 16:00, când radiațiile UV sunt cele mai puternice.',
                Icons.beach_access,
              ),
              _buildPreventionCard(
                'Poartă haine care te apără de soare',
                'Acoperă-ți pielea cu bluze cu mânecă lungă, pantaloni lungi și o pălărie cu boruri largi. Optează pentru haine cu protecție UV încorporată, dacă este posibil.',
                Icons.accessibility_new,
              ),
              _buildPreventionCard(
                'Poartă ochelari de soare',
                'Protejează-ți ochii și pielea din jurul lor cu ochelari care blochează razele UVA și UVB.',
                Icons.remove_red_eye,
              ),
              _buildPreventionCard(
                'Evită expunerea artificială',
                'Solarul emite radiații UV nocive care cresc riscul de cancer de piele. Nu există un bronz „sigur”.',
                Icons.do_not_disturb,
              ),
              _buildPreventionCard(
                'Mergi la controale regulate',
                'Examinează-ți pielea frecvent pentru modificări ale alunițelor existente sau apariția unora noi. Programează anual un control dermatologic profesional.',
                Icons.search,
              ),
              const SizedBox(height: 24),
              const Text(
                'Ține minte',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Oricine poate dezvolta cancer de piele, indiferent de culoarea pielii sau cât de ușor te bronzezi. Adoptând aceste măsuri de prevenție, îți poți reduce considerabil riscul.',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreventionCard(
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
            Icon(icon, color: AppColors.primary, size: 32),
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
