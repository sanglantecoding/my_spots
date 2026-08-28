# 📋 CHANGELOG - My Spots

Toutes les modifications notables de ce projet seront documentées dans ce fichier.

---

## 🆕 [v1.0.1+2] - 24 Août 2026

### ✨ Refactoring architectural majeur

#### 🧭 **Architecture GPS unifiée**
- **GpsController comme unique source** : Suppression de l'architecture dual tracking (GpsService + GpsController)
- **MapScreen refactorisé** : Suppression des appels à `GpsService.startAdaptiveGpsTracking()` et `stopAdaptiveGpsTracking()`
- **Subscription directe** : MapScreen s'abonne à `GpsController.instance.positionStream` et `stateStream`
- **GpsService nettoyé** : Ne contient plus que des fonctions pures (calculs de distance, formatage, statut GPS)
- **Suppression tracking** : Retrait de toute logique de streaming GPS de GpsService
- **Vérification** : `Geolocator.getPositionStream()` appelé uniquement dans GpsController

#### 🏗️ **Initialisation centralisée**
- **AppBootstrap créé** : Classe d'initialisation centralisée dans `lib/core/app_bootstrap.dart`
- **main() simplifié** : Appel unique à `AppBootstrap.initialize()` avant `runApp()`
- **Services initialisés** : AppSettings, WaypointStore, MapTileCacheService, SatelliteService
- **Code propre** : main.dart réduit à l'essentiel

#### 📦 **Repository pattern pour FMTC**
- **TileCacheRepository créé** : Interface abstraite dans `lib/repositories/tile_cache_repository.dart`
- **FmtcTileCacheRepository** : Implémentation encapsulant les dépendances FMTC internes
- **Isolation des imports** : `export_internal.dart` confiné au repository
- **MapTileCacheService refactorisé** : Délègue au repository au lieu d'appeler FMTC directement
- **API propre** : Méthodes publiques `purgeTilesInBounds()` et `clearLayerCache()`

#### 🧩 **Extraction de widgets MapScreen**
- **GpsMarkerWidget** : Widget indépendant écoutant GpsController pour éviter les rebuilds du parent
- **SelectedWaypointPanel** : Panneau de détails du waypoint sélectionné extrait
- **MapControlsWidget** : Boutons de contrôle de carte (recenter, toggle waypoints, add waypoint)
- **Réduction MapScreen** : De ~1066 à ~876 lignes (-190 lignes)
- **Meilleure maintenabilité** : Chaque widget testable et modifiable indépendamment

#### 📄 **Extraction de ManagePortsScreen**
- **ManagePortsScreen séparé** : Déplacé de settings_page.dart vers `lib/views/settings/manage_ports_screen.dart`
- **Réduction SettingsScreen** : De ~1678 à ~1420 lignes (-258 lignes)
- **Navigation préservée** : MaterialPageRoute continue de fonctionner

#### 🔒 **Sécurité AlarmService**
- **Protection contre conditions de course** : Flag `_isProcessingAlarm` déjà en place
- **Verrou audio** : Flag `_isPlayingAudio` pour éviter le chevauchement audio
- **Null check ajouté** : Vérification de `_proximityPlayer` avant opérations audio
- **Calculs synchrones** : Distance calculée de manière synchrone

### 🔧 Améliorations techniques

#### 📊 **Statistiques de la version**
- **~450 lignes** supprimées des fichiers principaux
- **3 nouveaux widgets** extraits (GpsMarkerWidget, SelectedWaypointPanel, MapControlsWidget)
- **1 nouveau repository** (TileCacheRepository)
- **1 nouveau service d'initialisation** (AppBootstrap)
- **1 nouvel écran** (ManagePortsScreen)
- **Architecture améliorée** : Séparation des responsabilités, dépendances isolées
- **flutter analyze** : 17 issues pré-existantes (deprecated_member_use, implementation_imports)

---

## 🆕 [v1.01] - 20 Juin 2026

### ✨ Nouvelles fonctionnalités

#### 🧭 **Système de navigation active**
- **Bandeau de navigation** avec informations en temps réel
- **Affichage de la distance** vers le waypoint cible (m/nm/km selon préférences)
- **Cap compas** normalisé (0-360°) pour suivre la direction
- **Vitesse actuelle** en temps réel (nœuds pour pêche, km/h pour terrestre)
- **ETA (Estimated Time of Arrival)** calculé dynamiquement
- **Bouton "Y aller"** dans le panneau d'information du waypoint
- **Bouton d'arrêt** (croix rouge) intégré dans le bandeau
- **Positionnement optimal** : Bandeau en haut de l'écran pour ne pas gêner la vue carte
- **Design moderne** : Style inspiré des GPS marins Garmin avec fond semi-transparent

#### 🔔 **Refactoring complet du service d'alarmes**
- **Service autonome AlarmService** : Extraction de toute la logique d'alarme de main.dart
- **Architecture améliorée** : Séparation claire des responsabilités
- **Flux GPS unifié** : Plus de conflit entre les streams GPS
- **Calculs centralisés** : Distance, cap, zones X/Y/Z gérés dans le service
- **API explicite** : Méthodes `startMonitoring()` et `stopMonitoring()`
- **Activation exclusive** : Alarmes déclenchées uniquement en mode navigation actif
- **Bug corrigé** : Plus de bip involontaire lors de la simple sélection d'un waypoint

#### 🔊 **Contrôle audio intégré**
- **Bouton Mute dans le bandeau** : Icône volume_up/volume_off
- **Contrôle instantané** : Coupe/réactive les bips pendant la navigation
- **État synchronisé** : Partagé entre le service et l'UI
- **Indicateur visuel** : Icône bleue (actif) ou grise (coupé)
- **Tooltip dynamique** : "Activer le son" / "Couper le son"

#### 🚫 **Suppression des vibrations**
- **Mode silencieux pur** : Plus aucune vibration en mode Mute
- **Son uniquement** : L'alarme ne produit que des bips sonores
- **Silence total** : Ni son, ni vibration quand l'alarme est coupée
- **Expérience utilisateur** : Plus discrète et respectueuse

### 🔧 Améliorations techniques

#### 🏗️ **Architecture**
- **Service AlarmService (~200 lignes)** : Logique d'alarme isolée et autonome
- **Widget NavigationOverlay (~270 lignes)** : Bandeau de navigation modulaire
- **Nettoyage main.dart** : Suppression de ~100 lignes de code d'alarme
- **Pas de logique lourde dans main.dart** : Respect strict de la séparation des responsabilités
- **Communication par callbacks** : Service notifie l'UI des changements d'état

#### 🎯 **Comportement corrigé**
- **Sélection de waypoint** : Aucun bip (simple affichage des détails)
- **Création de waypoint** : Aucun bip
- **Mode navigation actif** : Alarmes activées explicitement avec "Y aller"
- **Arrêt navigation** : Alarmes désactivées explicitement avec la croix rouge
- **Mode Mute** : Silence total (ni son, ni vibration)

### 📊 Statistiques de la version
- **+2 services** créés (AlarmService, NavigationOverlay widget)
- **~370 lignes** de code ajoutées
- **~100 lignes** supprimées de main.dart
- **Architecture améliorée** : Séparation des responsabilités
- **Bug corrigé** : Plus de bip involontaire à la sélection de waypoint

---

## 🆕 [v1.00] - 5 Mars 2026

### ✨ Fonctionnalités principales

#### 🗺️ **Navigation GPS en temps réel**
- **Suivi GPS continu** avec indicateur de précision coloré
- **4 niveaux de précision** : Excellent (<8m), Correct (8-15m), Moyen (15-30m), Faible (>30m)
- **Mode économie d'énergie** pour prolonger l'autonomie
- **Affichage de la vitesse** et du cap en temps réel
- **Vue détaillée des satellites** : nombre, type GNSS, signal, altitude

#### 📍 **Gestion multi-catégories de waypoints**
- **🎣 Pêche** : Points de pêche favoris avec icône Ancre
- **🍄 Champignons** : Zones de cueillette avec icône Forêt
- **🚗 Voiture/Autre** : Points de stationnement avec icône GPS standard
- **Personnalisation** : Couleurs et noms pour chaque waypoint
- **Précision historique** : Chaque waypoint enregistre la précision GPS lors de sa création

#### 📊 **Import/Export GPX complet**
- **Exportation GPX** standard pour compatibilité avec tous les GPS
- **Importation GPX** depuis fichiers externes
- **Sélection multiple** pour export ciblé
- **Métadonnées enrichies** : nom, position, couleur, catégorie, statut GPS
- **Historique de fiabilité** : Chaque waypoint conserve son statut de précision
- **Compatibilité descendante** : Points anciens affichés avec statut "Inconnu"

#### 💾 **Sauvegarde complète haute fidélité**
- **Export complet** : Waypoints + réglages + métadonnées de précision
- **Historique préservé** : Précision GPS et statut de chaque waypoint conservés
- **Import robuste** : Gestion gracieuse des données manquantes avec valeurs par défaut
- **Migration sans perte** : Transfert parfait entre appareils ou réinstallations
- **Fichier JSON structuré** : Format lisible et versionné pour compatibilité

#### 🛰️ **Informations satellites avancées**
- **Accès direct** : Clic sur le signal GPS (accueil et carte)
- **Détails complets** : Satellites utilisés/visibles, type GNSS
- **Signal en temps réel** : Barre de progression et pourcentage
- **Altitude live** : Affichage et mise à jour automatique
- **Liste individuelle** : Chaque satellite avec force du signal

### ⚠️ **Système d'alarme de proximité**

#### 🎯 **3 zones d'alarme configurables**
- **Zone X** (100m par défaut) : Bip lent toutes les 4 secondes
- **Zone Y** (20m par défaut) : Bip-bip toutes les 2 secondes
- **Zone Z** (5m par défaut) : Bip continu toutes les 500ms

#### 🔊 **Caractéristiques avancées**
- **Audio uniquement** : Bips sonores sans retour tactile
- **Optimisation intelligente** : Timer recréé uniquement lors du changement de zone
- **Indicateur visuel** : Icône d'alarme affichée dans les zones actives
- **Arrêt automatique** : Désactivation hors de la zone X
- **Activation explicite** : Alarmes déclenchées uniquement en mode navigation actif
- **Contrôle Mute** : Bouton intégré dans le bandeau de navigation

#### ⚙️ **Personnalisation**
- Distances ajustables (X: 10-1000m, Y: 5-500m, Z: 1-100m)
- Activation/désactivation de l'alarme
- Contrôle du son (Mute/Unmute) pendant la navigation
- Gestion silencieuse des erreurs audio
- **Contraintes X > Y > Z** : Validation automatique des configurations

### 🎯 **Gestion des waypoints**

#### 📝 **Création et édition**
- **Interface glissante** pour création rapide
- **Vérification de précision GPS** avant enregistrement
- **Alerte de sécurité** si précision > seuil configuré
- **Édition** : nom, catégorie, couleur, position
- **Métadonnées précision** : Enregistrement automatique de la précision GPS

#### 🎨 **Personnalisation**
- **8 couleurs prédéfinies** pour identification visuelle
- **3 catégories** avec icônes distinctes
- **Affichage optionnel** : noms, dates sur la carte
- **Taille de police** ajustable (10-20pt)
- **Indicateurs de précision** : Icônes colorées dans la liste
- **Historique visuel** : Points anciens avec icône grise claire ("Inconnu")

#### 🔍 **Filtrage et affichage**
- **Filtres par catégorie** : Pêche, Champignons, Autre
- **Visibilité contrôlée** de chaque type de waypoint
- **Affichage sélectif** des noms et dates
- **Recherche rapide** par nom
- **Tri intelligent** : Par distance depuis position actuelle
- **Affichage distances** : "à 450 m" ou "à 1.2 km"

### 🎨 **Interface utilisateur**

#### 📱 **Design moderne et intuitif**
- **Interface sombre** : Optimisée pour usage extérieur
- **Navigation fluide** : Transitions et animations naturelles
- **Icônes thématiques** : Pêche (ancre), Champignons (forêt), Voiture (GPS)
- **Code couleur** : Vert (excellent), Jaune (correct), Orange (moyen), Rouge (faible)

#### 🗺️ **Cartographie interactive**
- **4 types de fonds** : Standard (OpenStreetMap), Relief (OpenTopoMap), Randonnée (Thunderforest), Marine (SHOM)
- **Carte marine SHOM** : Service WMTS clevisu avec empilement multi-échelles (1:50k, 1:25k, 1:10k)
- **Superposition Lidar** : Données bathymétriques Litto3D du SHOM (flux WMTS INSPIRE)
- **3 couches temporelles Lidar** : 2009, 2011, 2014-2015 avec empilement chronologique
- **Contrôle d'opacité** : Slider ajustable (0-100%) pour la superposition bathymétrique
- **Zoom fluide** : Du niveau local au niveau régional
- **Marqueurs dynamiques** : Adaptation selon le niveau de zoom
- **Mode plein écran** : Navigation sans distraction

### ⚡ **Performance et optimisation**

#### 🔋 **Économie d'énergie**
- **Mode éco** : Réduction de la fréquence GPS
- **Gestion intelligente** : Arrêt automatique en arrière-plan
- **Optimisation mémoire** : Nettoyage automatique des ressources
- **Batterie prolongée** : Jusqu'à 12h d'utilisation continue

#### 📊 **Métriques de performance**
- **Démarrage** : <2 secondes
- **Consommation batterie** : Optimisée avec mode éco
- **Mémoire** : Gestion centralisée des ressources
- **Précision GPS** : Jusqu'à 5 mètres en conditions idéales

### 🔧 **Architecture technique**

#### 🏗️ **Structure modulaire**
- **Services séparés** : GPS, Audio, Permissions, Resources
- **Centralisation GPS** : Logique unifiée pour tout l'app
- **Gestion mémoire** : ResourceManager optimisé
- **Code documenté** : Comments détaillés en français

#### ⚡ **Performance optimisée**
- **Streams/Timers** : Gestion correcte des ressources
- **Mode économie** : Réduction de la fréquence GPS
- **Interface responsive** : Adaptation à toutes tailles d'écran
- **Audio pré-chargé** : Optimisation des sons d'alarme

### 🛠️ **Technologies utilisées**

#### 📱 **Framework et plateformes**
- **Flutter 3.41.4** : Framework cross-platform
- **Geolocator** : Services de localisation
- **Flutter Map** : Cartographie interactive
- **AudioPlayers** : Gestion des sons
- **SharedPreferences** : Stockage local
- **OpenStreetMap** : Fonds de carte standard
- **OpenTopoMap** : Cartes de relief
- **Thunderforest** : Cartes de randonnée
- **SHOM WMTS clevisu** : Cartes marines officielles françaises (multi-échelles)
- **SHOM INSPIRE** : Données bathymétriques Litto3D (multi-temporelles)

#### 🎯 **Fonctionnalités avancées**
- **Vue détaillée des satellites** : Accès direct et informations complètes
- **Import/Export GPX** : Standard avec métadonnées préservées
- **Tri intelligent** : Automatique par distance avec code couleur
- **Précision historique** : Métadonnées GPS et indicateurs visuels

### 📊 **Statistiques de la version**
- **+1800 lignes** de code
- **6 widgets** spécialisés
- **1 modèle enrichi** (Waypoint avec creationAccuracy)
- **9 services** créés (GPS, Audio, Permissions, Resources, Satellite, WaypointSort, MarineMap, BathymetryOverlay, AlarmService)
- **2 types d'export** (GPX + JSON)
- **1 ModalBottomSheet** satellites
- **1 indicateur** de précision GPS
- **2 services cartographiques** SHOM (MarineMapService + BathymetryOverlayService)
- **1 widget de navigation** (NavigationOverlay)

---

## 📱 Compatibilité

### Plateformes supportées
- **Android** : 6.0+ (API 23+)
- **Flutter** : 3.41.4+
- **Dart** : 3.11.1+

### Formats supportés
- **GPX 1.1** : Import/Export standard
- **JSON** : Sauvegarde interne
- **OpenStreetMap** : Fonds de carte standard
- **OpenTopoMap** : Cartes de relief
- **Thunderforest** : Cartes de randonnée
- **SHOM WMTS clevisu** : Cartes marines (multi-échelles 1:50k, 1:25k, 1:10k)
- **SHOM INSPIRE** : Données bathymétriques Litto3D (multi-temporelles 2009, 2011, 2014-2015)

---

## 🚀 Roadmap prévisionnelle

### v1.02 (Planifié)
- **Mode hors-ligne** : Téléchargement des cartes
- **Partage en temps réel** : Position avec amis
- **Historique des trajets** : Enregistrement des parcours
- **Multi-langues** : Anglais, Espagnol, Allemand

### v1.03 (Étudié)
- **Mode avancé** : Calques personnalisés
- **Statistiques** : Distance parcourue, temps passé
- **Cloud sync** : Synchronisation automatique
- **Import KML** : Format Google Earth

---

## 🤝 Contribuer

### 🐛 Rapporter un bug
1. **Décrire** le problème avec précision
2. **Fournir** les étapes pour reproduire
3. **Inclure** les informations sur l'appareil et la version
4. **Ajouter** des captures d'écran si pertinent

### 💡 Suggérer une amélioration
1. **Décrire** la fonctionnalité souhaitée
2. **Expliquer** le cas d'usage
3. **Proposer** des solutions techniques si possible
4. **Discuter** de la priorité et de la complexité

---

## 📄 Licence

Ce projet est sous licence MIT - voir le fichier [LICENSE](LICENSE) pour plus de détails.

---

*Pour plus d'informations, consultez le [README.md](README.md)*

---

*Version 1.0.1+2 - Architecture unifiée et refactoring progressif*
