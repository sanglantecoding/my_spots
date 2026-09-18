/// Raison pour laquelle le downloader a interrompu un téléchargement.
///
/// Distincte de [DownloadCancelReason] (qui vit dans le service) pour
/// éviter une dépendance circulaire. Le service traduit l'une en l'autre.
enum DownloadInterruptReason {
  /// Pas d'interruption : le téléchargement est allé jusqu'au bout.
  none,

  /// Interrompu par le watchdog (flux gelé > 15 min sans progrès).
  watchdog,

  /// Interrompu car le nombre de tuiles dépasse le plafond (12 000).
  tileCeiling,
}

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
    this.interruptReason = DownloadInterruptReason.none,
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

  /// Raison de l'interruption du téléchargement (si applicable).
  ///
  /// - [DownloadInterruptReason.none] : téléchargement allé jusqu'au bout.
  /// - [DownloadInterruptReason.watchdog] : interrompu par flux gelé.
  /// - [DownloadInterruptReason.tileCeiling] : interrompu par plafond de tuiles.
  final DownloadInterruptReason interruptReason;
}
