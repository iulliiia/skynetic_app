import 'package:flutter/material.dart';
import 'package:skynetic_app/theme/app_theme.dart';

class ABCDEScreen extends StatelessWidget {
  const ABCDEScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Criteriile ABCDE'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Regula ABCDE a cancerului de piele',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Regula ABCDE este un mod simplu de a reține semnele de avertizare ale melanomului. Folosește acest ghid când examinezi alunițele sau alte pete de pe piele.',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              _buildCriteriaCard(
                'A - Asimetrie',
                'O jumătate a aluniței nu este identică cu cealaltă jumătate.',
                'Alunițele normale sunt simetrice. Dacă trasezi o linie prin mijloc, cele două părți ar trebui să fie identice.',
                Icons.compare,
              ),
              _buildCriteriaCard(
                'B - Margini (Borders)',
                'Marginile sunt neregulate, zimțate, neuniforme sau estompate.',
                'Alunițele normale au margini netede și regulate. Melanoamele au adesea margini inegale.',
                Icons.crop_free,
              ),
              _buildCriteriaCard(
                'C - Culoare',
                'Culoarea nu este uniformă și poate include diferite nuanțe de maro, negru sau cafeniu.',
                'Alunițele normale au de obicei o singură nuanță de maro. Melanoamele pot avea nuanțe variate de maro, cafeniu sau negru.',
                Icons.palette,
              ),
              _buildCriteriaCard(
                'D - Diametru',
                'Diametrul este mai mare de 6 mm (aproximativ dimensiunea unei gume de creion).',
                'Alunițele normale sunt de obicei mai mici de 6 mm. Melanoamele sunt adesea mai mari.',
                Icons.straighten,
              ),
              _buildCriteriaCard(
                'E - Evoluție',
                'Alunița se schimbă în dimensiune, formă, culoare sau înălțime.',
                'Alunițele normale rămân neschimbate în timp. Melanoamele se modifică frecvent în dimensiune, formă sau culoare.',
                Icons.update,
              ),
              const SizedBox(height: 24),
              const Text(
                'Când să mergi la doctor',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Dacă observi oricare dintre aceste semne de avertizare sau ai o aluniță care se modifică, provoacă mâncărimi sau sângerează, mergi la un medic dermatolog cât mai curând posibil.',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.accent2.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accent2),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.accent3),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Ține minte: Detectarea timpurie este cheia pentru tratamentul eficient al cancerului de piele.',
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

  Widget _buildCriteriaCard(
    String title,
    String description,
    String explanation,
    IconData icon,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              description,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              explanation,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
