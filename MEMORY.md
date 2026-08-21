# MEMORY.md — Projet My Spots

## Vue d'ensemble

**My Spots** est une application Flutter de cartographie et de gestion de waypoints (spots de pêche, champignons, etc.) avec navigation GPS en temps réel, alarmes de proximité, et affichage de cartes marines SHOM / LiDAR.

---

## Structure du projet (`lib/`)

```
lib/
├── main.dart                          # Point d'entrée (~2768 lignes) — Écrans Home, Map, Waypoints, éditeur
├── app_settings.dart                  # Configuration globale (SharedPreferences) — 333 lignes
├── settings_page.dart                 # Écran de paramètres (~1674 lignes) — Ports, unités, alarmes, sauvegarde
├── help_page.dart                     # Page d'aide (affiche CHANGELOG.md) — 200 lignes
├── waypoint_export_screen.dart        # Export/Import GPX — 522 lignes
├── models/
│   └── waypoint.dart                  # Modèle Waypoint + WaypointStore (SharedPreferences) — 97 lignes
├── services/
│   ├── gps_service.dart               # Service GPS centralisé (Haversine, statuts, tracking adaptatif) — 297 lignes
│   ├── alarm_service.dart             # Alarmes de proximité (zones X/Y/Z, bips audio) — 224 lignes
│   ├── satellite_service.dart         # Simulation de données satellites — 199 lignes
│   ├── audio_service.dart             # Service audio (redondant avec alarm_service) — 85 lignes
│   ├── location_permission_service.dart # Gestion des permissions GPS — 79 lignes
│   ├── waypoint_sort_service.dart     # Tri des waypoints par distance — 139 lignes
│   ├── bathymetry_overlay_service.dart # Overlay LiDAR/Bathymétrie SHOM (WMTS) — 52 lignes
│   ├── marine_map_service.dart        # Cartes marines RasterMarine SHOM (clevisu WMTS) — 45 lignes
│   ├── map_tile_cache_service.dart    # Cache de tuiles FMTC (hors-ligne) — 99 lignes
│   └── resource_manager.dart          # Gestionnaire de ressources (timers, streams, audio) — 96 lignes
├── utils/
│   ├── date_utils.dart                # Formatage de dates — 52 lignes
│   └── gps_status_utils.dart          # Utilitaires statut GPS (couleurs, icônes, labels) — 70 lignes
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

---

## Modèles de données

### `Waypoint`
- **Stockage** : `SharedPreferences` via `WaypointStore` (JSON sérialisé)
- **Champs** : `name`, `latitude`, `longitude`, `createdAt`, `colorHex`, `category` (fishing/mushrooms/other), `creationAccuracy`, `gpsStatus`
- **Catégories** : `WaypointCategory.fishing`, `.mushrooms`, `.other`
- **Couleurs disponibles** : Jaune, Vert, Bleu, Orange, Rouge

### `AppSettings`
- **Stockage** : `SharedPreferences` (clés individuelles)
- **Paramètres** : unité de vitesse (kmh/knots), unité de distance (metric/nautical), type de carte (standard/relief/hiking/marine), visibilité waypoints, alarmes de proximité (zones X/Y/Z), overlay bathymétrie, ports favoris météo marine, mode économie d'énergie

---

## Architecture et flux de données

### State Management
- **Aucun state management externe** (ni Provider, ni Riverpod, ni Bloc)
- Utilisation de `setState()` dans les `StatefulWidget`
- Services statiques (singletons) avec variables statiques mutables
- `AppSettings` : classe statique avec champs statiques modifiés directement

### Persistance
- `WaypointStore` : charge/sauvegarde la liste complète des waypoints en JSON via `SharedPreferences`
- `AppSettings` : chaque paramètre a sa propre clé `SharedPreferences`
- `MapTileCacheService` : cache de tuiles FMTC (ObjectBox) pour usage hors-ligne

### Géolocalisation
- `GpsService` : service centralisé avec tracking adaptatif (stationnaire vs mobile)
- Seuils de précision GPS unifiés : 0-8m (Vert/Excellent), 8-15m (Ambre/OK), 15-30m (Orange/Moyen), >30m (Rouge/Faible)
- Streaming GPS avec adaptation de la fréquence selon la vitesse
- `SatelliteService` : simulation de données satellites (pas d'API réelle)

### Cartes
- **4 types de cartes** : Standard (OSM), Relief (OpenTopoMap), Randonnée (Thunderforest), Marine (SHOM)
- **Carte marine** : empilement WMTS SHOM clevisu (3 échelles : 1:50k, 1:25k, 1:10k)
- **Overlay bathymétrie** : empilement WMTS SHOM INSPIRE Litto3D (3 millésimes : 2009, 2011, 2014-2015)
- Cache FMTC dédié par couche pour éviter les collisions de cache

### Navigation et alarmes
- `NavigationOverlay` : bandeau affichant distance, cap, vitesse, ETA vers un waypoint cible
- `AlarmService` : 3 zones de proximité (X=100m bip lent, Y=20m bip-bip, Z=5m bip continu)
- Son : `assets/sounds/beep.mp3`

---

## Écrans principaux

1. **HomePage** (`main.dart`) : Menu principal avec boutons CARTE et WAYPOINTS, statut GPS, météo marine
2. **MapScreen** (`main.dart`) : Carte interactive avec waypoints, navigation, overlay bathymétrie, ajout/édition de waypoints
3. **WaypointsScreen** (`main.dart`) : Liste des waypoints triés par distance, édition, suppression
4. **SettingsScreen** (`settings_page.dart`) : Paramètres complets (port, unités, carte, alarmes, sauvegarde/restauration)
5. **WaypointExportScreen** (`waypoint_export_screen.dart`) : Export/Import GPX avec sélection multiple
6. **HelpPage** (`help_page.dart`) : Aide affichant le CHANGELOG.md

---

## Points d'attention / Refactoring potentiel

### Fichiers volumineux
- **`main.dart`** : **~2768 lignes** — contient 3 écrans majeurs (HomePage, MapScreen, WaypointsScreen) + l'éditeur de waypoints. **Priorité de refactoring** : extraire MapScreen, WaypointsScreen et _WaypointEditorSheet dans des fichiers séparés.
- **`settings_page.dart`** : **~1674 lignes** — très long, pourrait être découpé en sous-widgets ou sections.

### Redondances
- **`audio_service.dart`** vs **`alarm_service.dart`** : `AudioService` semble être une version antérieure du système audio, partiellement redondant avec `AlarmService`. Vérifier si encore utilisé.
- **Calculs de distance Haversine** : dupliqués dans `GpsService`, `AlarmService`, `WaypointSortService`, `NavigationOverlay`. `GpsService.calculateDistance()` est la version centralisée, mais les autres services ont leur propre implémentation.
- **`GpsStatusUtils`** vs **`GpsService`** : logique de statut GPS dupliquée entre les deux.

### Problèmes potentiels
- **Services statiques** : utilisation intensive de variables statiques mutables — pas idéal pour les tests et le cycle de vie.
- **`SatelliteService`** : données satellites **simulées** (pas de vraie API Android GNSS). Les utilisateurs pourraient être induits en erreur.
- **Permissions** : la logique de permission est dupliquée dans `main.dart` (HomePage), `GpsService`, et `LocationPermissionService`.
- **`NavigationOverlay`** : crée son propre stream GPS (`Geolocator.getPositionStream`) en parallèle de celui de `GpsService` — double consommation de batterie.
- **`AlarmService`** : utilise `_distanceInMeters()` avec Haversine manuelle au lieu de `GpsService.calculateDistance()`.

### Tests
- Un seul fichier de test : `test/gps_service_test.dart` (98 lignes) — couvre les seuils de précision GPS.
- Pas de tests pour les autres services, modèles, ou widgets.

---

## Versions et environnement

- **Flutter SDK** : ^3.10.7
- **Version app** : 1.0.0+1
- **Package name** : `com.svc.my_spots`
- **Localisation** : Français uniquement (`fr_FR`)
- **Thème** : Dark mode (couleur de fond `#0A1929`)