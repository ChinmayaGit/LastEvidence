enum Weapon {
  dagger('Dagger'),
  candlestick('Candlestick'),
  revolver('Revolver'),
  rope('Rope'),
  leadPiping('Lead Piping'),
  spanner('Spanner');

  final String name;
  const Weapon(this.name);

  String get assetPath => 'assets/weapon/$name.png';

  static Weapon? fromName(String value) {
    try {
      return Weapon.values.firstWhere((w) => w.name == value);
    } catch (_) {
      return null;
    }
  }
}



