enum Suspect {
  colonelMustard('Alex Hunter'),
  professorPlum('Blake Rivers'),
  reverendGreen('Casey Knight'),
  mrsPeacock('Jordan Steele'),
  missScarlett('Riley Cross'),
  mrsWhite('Taylor Frost');

  final String name;
  const Suspect(this.name);

  String get assetPath => 'assets/person/$name.jpg';

  static Suspect? fromName(String value) {
    try {
      return Suspect.values.firstWhere((s) => s.name == value);
    } catch (_) {
      return null;
    }
  }
}



