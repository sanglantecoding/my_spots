/// Espèces de champignons supportées par le système de prévision.
enum MushroomSpecies {
  /// Cèpe de Bordeaux (Boletus edulis)
  boletusEdulis,

  /// Girolle / Chanterelle (Cantharellus cibarius)
  chanterelle,

  /// Trompette de la mort (Craterellus cornucopioides)
  blackTrumpet,

  /// Autre espèce (pour extensibilité future)
  other,
}

extension MushroomSpeciesExtension on MushroomSpecies {
  /// Code court pour sérialisation/stockage
  String get code {
    switch (this) {
      case MushroomSpecies.boletusEdulis:
        return 'boletus_edulis';
      case MushroomSpecies.chanterelle:
        return 'chanterelle';
      case MushroomSpecies.blackTrumpet:
        return 'black_trumpet';
      case MushroomSpecies.other:
        return 'other';
    }
  }
}

/// Convertit un code en espèce de champignon.
MushroomSpecies mushroomSpeciesFromCode(String code) {
  return MushroomSpecies.values.firstWhere(
    (s) => s.code == code,
    orElse: () => MushroomSpecies.other,
  );
}
