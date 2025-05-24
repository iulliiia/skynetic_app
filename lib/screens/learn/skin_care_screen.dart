import 'package:flutter/material.dart';
import 'package:skynetic_app/theme/app_theme.dart';

class SkinCareScreen extends StatelessWidget {
  const SkinCareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sfaturi pentru îngrijirea pielii'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cum să îți îngrijești pielea',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Îngrijirea pielii este esențială pentru sănătatea generală și poate contribui la prevenirea cancerului de piele. Iată câteva recomandări pentru a menține o piele sănătoasă.',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              _buildSkinCareCard(
                'Curățare zilnică a tenului',
                'Spală-ți fața de două ori pe zi cu un produs de curățare delicat pentru a elimina murdăria, sebumul și poluanții care pot afecta pielea.',
                Icons.clean_hands,
              ),
              _buildSkinCareCard(
                'Hidratarea pielii',
                'Folosește o cremă hidratantă potrivită tipului tău de piele pentru a o menține catifelată și protejată.',
                Icons.opacity,
              ),
              _buildSkinCareCard(
                'Aplicarea protecției solare',
                'Aplică zilnic cremă de protecție solară, chiar și în zilele înnorate. Alege un produs cu SPF cât mai mare',
                Icons.wb_sunny,
              ),
              _buildSkinCareCard(
                'Alimentație sănătoasă',
                'Consumă o dietă echilibrată, bogată în antioxidanți, vitamine și minerale care susțin sănătatea pielii din interior.',
                Icons.restaurant,
              ),
              _buildSkinCareCard(
                'Hidratare corespunzătoare',
                'Bea suficientă apă pentru a-ți menține pielea hidratată și pentru a ajuta la eliminarea toxinelor din organism.',
                Icons.water_drop,
              ),
              _buildSkinCareCard(
                'Evitarea fumatului',
                'Fumatul afectează colagenul și elastina, ceea ce duce la îmbătrânirea prematură și crește riscul de cancer de piele.',
                Icons.smoke_free,
              ),
              _buildSkinCareCard(
                'Limitarea consumului de alcool',
                'Consumul excesiv de alcool poate deshidrata pielea și poate provoca inflamații, făcând-o mai vulnerabilă la deteriorare.',
                Icons.no_drinks,
              ),
              _buildSkinCareCard(
                'Odihnă corespunzătoare',
                'În timpul somnului, pielea ta se regenerează. Încearcă să dormi între 7 și 9 ore de calitate în fiecare noapte.',
                Icons.nightlight,
              ),
              const SizedBox(height: 24),
              const Text(
                'Când să mergi la dermatolog',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Ia în considerare un consult dermatologic dacă ai probleme persistente cu pielea, observi schimbări neobișnuite sau ai antecedente familiale de cancer de piele.',
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

  Widget _buildSkinCareCard(
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
