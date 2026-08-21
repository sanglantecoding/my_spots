/// Modèle de données pour un port de pêche/météo
class FishingPort {
  final String key;
  final String name;
  final String weatherUrl;
  final double? latitude;
  final double? longitude;

  const FishingPort({
    required this.key,
    required this.name,
    required this.weatherUrl,
    this.latitude,
    this.longitude,
  });

  /// Constructeur pour les ports personnalisés (sans clé prédéfinie)
  FishingPort.custom({
    required this.name,
    required this.weatherUrl,
    this.latitude,
    this.longitude,
  }) : key = name;

  /// Conversion en Map pour la sérialisation
  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'name': name,
      'weatherUrl': weatherUrl,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };
  }

  /// Création depuis un Map
  static FishingPort fromMap(Map<String, dynamic> map) {
    return FishingPort(
      key: map['key'] as String? ?? map['name'] as String,
      name: map['name'] as String,
      weatherUrl: map['weatherUrl'] as String? ?? map['url'] as String,
      latitude: map['latitude'] as double?,
      longitude: map['longitude'] as double?,
    );
  }

  /// Conversion en JSON
  Map<String, dynamic> toJson() => toMap();

  /// Création depuis JSON
  static FishingPort fromJson(Map<String, dynamic> json) => fromMap(json);

  /// Constructeur legacy pour compatibilité avec le code existant
  factory FishingPort.legacy({required String name, required String url}) {
    return FishingPort.custom(name: name, weatherUrl: url);
  }

  /// Getter pour compatibilité avec le code existant qui utilise 'url'
  String get url => weatherUrl;

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FishingPort && other.key == key;
  }

  @override
  int get hashCode => key.hashCode;
}
