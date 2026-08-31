/// Drapeau global d'état d'initialisation.
///
/// Permet à l'UI (notamment `HomePage`) de détecter qu'un service critique
/// a échoué pendant le bootstrap, afin d'afficher un mode dégradé
/// (banner d'avertissement, liste de waypoints vide, cache hors-ligne
/// désactivé, etc.) sans crash en cascade.
class AppInitializationStatus {
  AppInitializationStatus._();

  /// Vrai tant qu'aucun service critique n'a planté.
  static bool criticalServicesOk = true;

  /// Vrai si `WaypointStore.load()` a échoué (critique : liste vide).
  static bool waypointsLoaded = false;

  /// Vrai si `AppSettings.loadSettings()` a échoué (critique : config absente).
  static bool settingsLoaded = false;

  /// Vrai si `MapTileCacheService.initialise()` a échoué (non-bloquant).
  static bool mapTileCacheReady = false;

  /// Vrai si `SatelliteService.initialize()` a échoué (non-bloquant).
  static bool satelliteReady = false;

  /// Erreurs rencontrées (clé = nom du service, valeur = message).
  /// Permet à l'UI d'afficher un diagnostic pertinent.
  static final Map<String, Object> errors = <String, Object>{};

  /// Liste lisible des services en échec pour l'UI / logs.
  static List<String> get failedServices => errors.keys.toList(growable: false);

  /// Mode dégradé activé dès qu'un service critique a échoué.
  static bool get isDegraded => !criticalServicesOk;
}