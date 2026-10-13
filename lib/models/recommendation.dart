class Recommendations {
  Recommendations._internal() {
    recommendations = <int, String>{
      0: 'Leziunea are grad de risc scăzut, dar este important să fii atent la orice schimbare. Monitorizează lunar zona afectată și programează un consult dermatologic dacă observi modificări de formă, culoare, dimensiune sau textură.',
      1: 'Nu te panica! Aplicația oferă doar o evaluare orientativă, nu un diagnostic validat clinic. Îți recomandăm să consulți un medic dermatolog cât mai curând posibil pentru o examinare completă și un diagnostic concret.',
      2: 'Pielea ta arată bine, nu s-au identificat leziuni. Pentru a menține sănătatea pielii, îți recomandăm să vizitezi secțiunea noastră de prevenție și îngrijire, unde vei găsi sfaturi utile pentru protecție și auto-monitorizare.',
      3: 'Modelul nu a putut distinge clar între categorii pentru această fotografie. Încearcă o poză mai clară, la lumină naturală, cu leziunea centrată. Dacă ai orice îngrijorare, consultă un medic dermatolog indiferent de rezultatul aplicației.',
    };
  }

  static final Recommendations _instance = Recommendations._internal();

  factory Recommendations() => _instance;

  late final Map<int, String> recommendations;

  String? get(int id) => recommendations[id];
}
