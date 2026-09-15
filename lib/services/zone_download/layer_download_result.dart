/// Résultat de l'évaluation d'un téléchargement de couche.
///
/// Contient les compteurs de tuiles téléchargées, négatives et en échec,
/// ainsi qu'un flag [successful] indiquant si le téléchargement est considéré
/// comme réussi (basé sur le ratio d'échecs réseau).
class LayerDownloadResult {
  const LayerDownloadResult({
    required this.downloadedTileCount,
    required this.estimatedTileCount,
    required this.successful,
    this.negativeTileCount = 0,
    this.failedTileCount = 0,
  });

  /// Nombre de tuiles téléchargées avec succès (HTTP 200 + contenu valide).
  final int downloadedTileCount;

  /// Nombre total de tuiles estimées pour cette couche.
  final int estimatedTileCount;

  /// `true` si le téléchargement est considéré comme réussi
  /// (ratio d'échecs réseau ≤ 15 %).
  final bool successful;

  /// Nombre de tuiles "négatives" (réponses HTTP 404 / contenu invalide).
  /// Ces tuiles ne comptent pas comme des échecs réseau.
  final int negativeTileCount;

  /// Nombre de tuiles en échec réseau (timeout, 5xx, etc.).
  final int failedTileCount;
}
