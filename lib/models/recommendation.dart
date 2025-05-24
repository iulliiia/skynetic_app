class Recommendations {
  Recommendations._internal() {
    recommendations = <int, String>{
      0: 'Monitorizează lunar și consultă un dermatolog dacă apar modificări.',
      1: 'Este recomandat sa consulti un doctor cat mai rapid.',
      2: 'Pielea ta este normala, nu ai de ce sa iti faci griji.'
    };
  }

  static final Recommendations _instance = Recommendations._internal();

  factory Recommendations() => _instance;

  late final Map<int, String> recommendations;

  String? get(int id) => recommendations[id];
}
