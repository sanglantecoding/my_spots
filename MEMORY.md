# MEMORY.md — Projet My Spots

## Vue d'ensemble

**My Spots** est une application Flutter de cartographie et de gestion de waypoints (spots de pêche, champignons, etc.) avec navigation GPS en temps réel, alarmes de proximité, affichage de cartes marines SHOM / LiDAR, et téléchargement de zones hors-ligne.

---

## Structure du projet (`lib/`)

```
lib/
├── main.dart                          # Point d'entrée (~400 lignes) — AppBootstrap, initialisation
├── app_settings.dart                  # Configuration globale (SharedPreferences) — 333 lignes
├── settings_page.dart                 # Écran de paramètres (~1420 lignes) — Ports, unités, alarmes, sauvegarde
├── help_page.dart                     # Page d'aide (affiche CHANGELOG.md) — 200 lignes
├── waypoint_export_screen.dart        # Export/Import GPX — 522 lignes
├── controllers/
│   └── gps_controller.dart            # Contrôleur GPS unifié (tracking, streaming) — ~200 lignes
├── core/
│   ├── app_bootstrap.dart             # Initialisation de l'application — ~100 lignes
│   └── app_initialization_status.dart # Statut d'initialisation — ~50 lignes
├── models/
│   ├── waypoint.dart                  # Modèle Waypoint + WaypointStore (SharedPreferences) — 97 lignes
│   ├── offline_map.dart              # Modèle OfflineMap (ObjectBox) — ~100 lignes
│   ├── offline_map_layer.dart        # Modèle OfflineMapLayer (ObjectBox) — ~80 lignes
│   ├── fishing_port.dart              # Modèle FishingPort (ports météo) — ~60 lignes
│   ├── litto3d_layer.dart             # Modèle Litto3DLayer (catalogue LiDAR) — ~70 lignes
│   └── lidar_region_bounds.dart      # Modèle LidarRegionBounds (limites régionales) — ~50 lignes
├── repositories/
│   ├── offline_map_repository.dart    # Repository OfflineMap (ObjectBox) — ~150 lignes
│   ├── tile_cache_repository.dart     # Interface repository cache tuiles — ~50 lignes
│   └── fmtc_tile_cache_repository.dart # Repository FMTC (implémentation) — ~200 lignes
├── services/
│   ├── gps_service.dart               # Service GPS utilitaire (Haversine, statuts, formatage) — 297 lignes
│   ├── alarm_service.dart             # Alarmes de proximité (zones X/Y/Z, bips audio) — 224 lignes
│   ├── satellite_service.dart         # Simulation de données satellites — 199 lignes
│   ├── waypoint_sort_service.dart     # Tri des waypoints par distance — 139 lignes
│   ├── port_service.dart              # Service ports météo — ~100 lignes
│   ├── marine_map_service.dart        # Cartes marines RasterMarine SHOM (clevisu WMTS) — ~350 lignes
│   ├── map_tile_cache_service.dart    # Cache de tuiles FMTC (hors-ligne) — ~200 lignes
│   ├── negative_tile_filter.dart      # Filtre de tuiles négatives — ~200 lignes
│   ├── zone_layer_config.dart        # Configuration des couches par zone — ~100 lignes
│   ├── layer_download_assessor.dart  # Évaluation des téléchargements — ~150 lignes
│   ├── tile_cache/
│   │   ├── blank_gray_filter.dart    # Filtre pixels blancs/gris — ~270 lignes
│   │   ├── cache_manager.dart        # Gestionnaire de cache — ~150 lignes
│   │   ├── message_tile_provider.dart # Provider tuiles message "Dézoomez" — ~100 lignes
│   │   └── tile_provider_factory.dart # Factory providers tuiles — ~80 lignes
│   └── zone_download/
│       ├── zone_download_service.dart # Service téléchargement zones — ~650 lignes
│       ├── fmtc_layer_downloader.dart # Downloader FMTC (pause/resume) — ~200 lignes
│       ├── shom_coverage_preflight.dart # Préflight SHOM — ~90 lignes
│       ├── layer_download_result.dart # Résultat téléchargement — ~50 lignes
│       ├── repository_interface.dart  # Interface repository zone download — ~30 lignes
│       └── zone_download.dart         # Types et enums zone download — ~50 lignes
├── utils/
│   ├── date_utils.dart                # Formatage de dates — 52 lignes
│   └── gps_status_utils.dart          # Utilitaires statut GPS (couleurs, icônes, labels) — 70 lignes
├── views/
│   ├── home_page.dart                 # Écran d'accueil — ~300 lignes
│   ├── map_screen.dart                # Écran carte — ~900 lignes
│   ├── waypoints_screen.dart          # Écran waypoints — ~400 lignes
│   ├── offline_maps_screen.dart       # Écran cartes hors-ligne — ~500 lignes
│   ├── dialogs/
│   │   └── waypoint_editor_sheet.dart # Éditeur waypoint (bottom sheet) — ~300 lignes
│   ├── settings/
│   │   └── widgets/
│   │       └── meteo_port_setting.dart # Widget paramètre port météo — ~100 lignes
│   └── widgets/
│       └── map/
│           ├── map_view.dart          # Vue carte principale — ~400 lignes
│           ├── gps_marker_widget.dart # Widget marqueur GPS — ~150 lignes
│           ├── selected_waypoint_panel.dart # Panneau waypoint sélectionné — ~200 lignes
│           ├── map_controls_widget.dart # Contrôles carte — ~150 lignes
│           └── distance_measurement_overlay.dart # Overlay mesure distance — ~100 lignes
└── widgets/
    ├── gps_status_indicator.dart      # Indicateur GPS compact — 90 lignes
    ├── navigation_overlay.dart        # Bandeau de navigation active (cap, distance, ETA) — 300 lignes
    ├── satellite_bottom_sheet.dart    # Bottom sheet détails satellites — 460 lignes
    ├── satellite_status_dialog.dart   # Dialog état GPS/satellites — 373 lignes
    └── waypoint_accuracy_indicator.dart # Indicateur précision waypoint — 37 lignes
```

---

## Dépendances clés (`pubspec.yaml`)

| Package | Usage |
|---|---|
| `flutter_map` ^8.2.2 | Affichage de la carte (tuiles OSM, SHOM, etc.) |
| `latlong2` ^0.9.1 | Types LatLng pour les coordonnées |
| `geolocator` ^14.0.2 | Position GPS, streaming, calculs de distance/cap |
| `permission_handler` ^12.0.1 | Permissions de localisation |
| `shared_preferences` ^2.3.3 | Persistance des waypoints et réglages |
| `audioplayers` ^6.1.0 | Sons d'alarme de proximité |
| `flutter_map_tile_caching` ^10.1.1 | Cache de tuiles hors-ligne (FMTC) |
| `url_launcher` ^6.3.0 | Ouverture météo marine dans le navigateur |
| `xml` ^6.5.0 | Parsing/génération GPX |
| `share_plus` ^10.1.2 | Partage de fichiers GPX/sauvegarde |
| `file_picker` ^8.1.2 | Sélection de fichiers pour import |
| `intl` ^0.20.2 | Internationalisation (dates) |
| `path_provider` ^2.1.3 | Chemins de fichiers temporaires |
| `objectbox` ^4.0.0 | Base de données locale (OfflineMap, OfflineMapLayer) |
| `objectbox_flutter_libs` ^4.0.0 | Librairies natives ObjectBox pour Flutter |

---

## Modèles de données

### `Waypoint`
- **Stockage** : `SharedPreferences` via `WaypointStore` (JSON sérialisé)
- **Champs** : `name`, `latitude`, `longitude`, `createdAt`, `colorHex`, `category` (fishing/mushrooms/other), `creationAccuracy`, `gpsStatus`
- **Catégories** : `WaypointCategory.fishing`, `.mushrooms`, `.other`
- **Couleurs disponibles** : Jaune, Vert, Bleu, Orange, Rouge

### `AppSettings`
- **Stockage** : `SharedPreferences` (clés individuelles)
- **Paramètres** : unité de vitesse (kmh/knots), unité de distance (metric/nautical), type de carte (standard/relief/hiking/marine), visibilité waypoints, alarmes de proximité (zones X/Y/Z), overlay bathymétrie, ports favoris météo marine, mode économie d'énergie, opacité bathymétrie

### `OfflineMap`
- **Stockage** : ObjectBox via `OfflineMapRepository`
- **Champs** : `uuid`, `name`, `bounds` (LatLngBounds), `status` (notStarted/downloading/ready/partial/failed), `createdAt`, `downloadedBytes`, `totalBytes`, `layers` (relation 1-N avec OfflineMapLayer)
- **Statuts** : `OfflineMapStatus.notStarted`, `.downloading`, `.ready`, `.partial`, `.failed`

### `OfflineMapLayer`
- **Stockage** : ObjectBox (relation avec OfflineMap)
- **Champs** : `layerType` (marine50k/marine25k/marine10k/lidarLitto3d), `minZoom`, `maxZoom`, `downloaded`, `total`, `status`, `lidarLayerId` (optionnel pour LiDAR)
- **Types** : `LayerType.marine50k`, `.marine25k`, `.marine10k`, `.lidarLitto3d`

### `FishingPort`
- **Stockage** : Code statique (catalogue ports)
- **Champs** : `id`, `name`, `region`, `url` (météo marine)

### `Litto3DLayer`
- **Stockage** : Code statique (catalogue LiDAR)
- **Champs** : `id`, `name`, `region`, `wmtsLayerName`, `bounds`

---

## Architecture et flux de données

### State Management
- **Aucun state management externe** (ni Provider, ni Riverpod, ni Bloc)
- Utilisation de `setState()` dans les `StatefulWidget`
- Services statiques (singletons) avec variables statiques mutables
- `AppSettings` : classe statique avec champs statiques modifiés directement
- `GpsController` : contrôleur GPS unifié pour tracking et streaming

### Persistance
- `WaypointStore` : charge/sauvegarde la liste complète des waypoints en JSON via `SharedPreferences`
- `AppSettings` : chaque paramètre a sa propre clé `SharedPreferences`
- `OfflineMapRepository` : repository ObjectBox pour OfflineMap et OfflineMapLayer
- `MapTileCacheService` : cache de tuiles FMTC pour usage hors-ligne
- `FmtcTileCacheRepository` : repository FMTC isolant les dépendances internes

### Géolocalisation
- `GpsController` : contrôleur unifié pour tracking GPS (remplace GpsService pour le tracking)
- `GpsService` : service utilitaire pour calculs Haversine, statuts, formatage
- Seuils de précision GPS unifiés : 0-8m (Vert/Excellent), 8-15m (Ambre/OK), 15-30m (Orange/Moyen), >30m (Rouge/Faible)
- Streaming GPS avec adaptation de la fréquence selon la vitesse
- `SatelliteService` : simulation de données satellites (pas d'API réelle)

### Cartes
- **4 types de cartes** : Standard (OSM), Relief (OpenTopoMap), Randonnée (Thunderforest), Marine (SHOM)
- **Carte marine** : empilement WMTS SHOM clevisu (3 échelles : 1:50k, 1:25k, 1:10k)
- **Overlay bathymétrie** : empilement WMTS SHOM INSPIRE Litto3D (campagnes régionales)
- **Cache FMTC** : téléchargement de zones hors-ligne avec gestion d'instances
- **Filtre de tuiles** : `BlankGrayFilteringTileProvider` rend les pixels blancs/gris transparents
- **Message "Dézoomez"** : affiché quand aucune tuile n'est disponible au zoom actuel
- **Empilement dynamique** : couches adaptées selon le niveau de zoom

### Téléchargement de zones
- `ZoneDownloadService` : orchestration du téléchargement de zones marines
- `FmtcLayerDownloader` : downloader FMTC avec pause/resume
- `ShomCoveragePreflight` : vérification de couverture SHOM avant téléchargement
- `LayerDownloadAssessor` : évaluation des résultats de téléchargement (seuil 15%)
- `cancelAndAwaitEnd` : synchronisation avant suppression de stores

### Navigation et alarmes
- `NavigationOverlay` : bandeau affichant distance, cap, vitesse, ETA vers un waypoint cible
- `AlarmService` : 3 zones de proximité (X=100m bip lent, Y=20m bip-bip, Z=5m bip continu)
- Son : `assets/sounds/beep.mp3`

---

## Écrans principaux

1. **HomePage** (`views/home_page.dart`) : Menu principal avec boutons CARTE et WAYPOINTS, statut GPS, météo marine
2. **MapScreen** (`views/map_screen.dart`) : Carte interactive avec waypoints, navigation, overlay bathymétrie, ajout/édition de waypoints
3. **WaypointsScreen** (`views/waypoints_screen.dart`) : Liste des waypoints triés par distance, édition, suppression
4. **OfflineMapsScreen** (`views/offline_maps_screen.dart`) : Gestion des cartes marines hors-ligne (téléchargement, pause/resume, suppression)
5. **SettingsScreen** (`settings_page.dart`) : Paramètres complets (port, unités, carte, alarmes, sauvegarde/restauration)
6. **WaypointExportScreen** (`waypoint_export_screen.dart`) : Export/Import GPX avec sélection multiple
7. **HelpPage** (`help_page.dart`) : Aide affichant le CHANGELOG.md

---

## Points d'attention / Refactoring potentiel

### Fichiers volumineux
- **`settings_page.dart`** : **~1420 lignes** — très long, pourrait être découpé en sous-widgets ou sections.
- **`zone_download_service.dart`** : **~650 lignes** — service complexe pour téléchargement de zones, pourrait être découpé en sous-services.

### Redondances
- **Calculs de distance Haversine** : dupliqués dans `GpsService`, `AlarmService`, `WaypointSortService`, `NavigationOverlay`. `GpsService.calculateDistance()` est la version centralisée, mais les autres services ont leur propre implémentation.
- **`GpsStatusUtils`** vs **`GpsService`** : logique de statut GPS dupliquée entre les deux.

### Problèmes potentiels
- **Services statiques** : utilisation intensive de variables statiques mutables — pas idéal pour les tests et le cycle de vie.
- **`SatelliteService`** : données satellites **simulées** (pas de vraie API Android GNSS). Les utilisateurs pourraient être induits en erreur.
- **Permissions** : la logique de permission est dupliquée dans plusieurs fichiers.
- **`NavigationOverlay`** : utilise `GpsController` pour le streaming GPS (meilleur qu'avant).
- **`AlarmService`** : utilise `_distanceInMeters()` avec Haversine manuelle au lieu de `GpsService.calculateDistance()`.

### Tests
- **Tests unitaires complets** pour le téléchargement de zones :
  - `test/views/zone_config_test.dart` : Tests du préflight SHOM
  - `test/services/zone_download/instance_id_test.dart` : Tests d'unicité des instanceId FMTC
  - `test/services/zone_download/precancel_test.dart` : Tests d'indépendance des clés preCancel
  - `test/services/zone_download/pause_resume_test.dart` : Tests pause/resume FmtcLayerDownloader
  - `test/services/zone_download/assess_result_test.dart` : Tests d'évaluation des téléchargements
  - `test/services/tile_cache/blank_gray_filter_test.dart` : Tests du filtre de tuiles
  - `test/services/marine_layer_stacking_test.dart` : Tests de l'empilement des couches marines
  - `test/services/zone_download_service_test.dart` : Tests du service ZoneDownloadService
- **Tests GPS** : `test/gps_service_test.dart` (98 lignes) — couvre les seuils de précision GPS
- **Couverture de tests** : Bonne couverture pour les fonctionnalités de téléchargement de zones, mais limitée pour les autres services et widgets.

---

## Versions et environnement

- **Flutter SDK** : ^3.10.7
- **Version app** : 1.1.0
- **Package name** : `com.svc.my_spots`
- **Localisation** : Français uniquement (`fr_FR`)
- **Thème** : Dark mode (couleur de fond `#0A1929`)