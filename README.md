# My Spots 🎣

Application mobile de navigation et repérage côtier pour pêcheurs, plaisanciers et randonneurs. Permet de marquer des spots, télécharger des cartes marines hors-ligne, naviguer vers vos waypoints favoris, et consulter la météo marine.

## ✨ Fonctionnalités

### 🗺️ Cartes multiples

**Cartes marines SHOM** (officielles françaises)
- Raster marine du SHOM avec 6 échelles : 1M, 350K, 100K, 50K, 25K, 10K
- Empilement intelligent selon le zoom : plus on zoome, plus la carte devient détaillée
- Couverture de toutes les côtes françaises (métropole + outre-mer)

**Cartes terrestres**
- **Standard** : OpenStreetMap classique
- **Relief** : OpenTopoMap avec courbes de niveau
- **Randonnée** : Thunderforest Outdoors (sentiers, chemins)

### 📥 Cartes hors-ligne

- Téléchargement de zones personnalisées (rectangle ou tracé main levée)
- Pré-analyse automatique de couverture SHOM avant téléchargement
- Gestion des téléchargements : pause, reprise, annulation
- Affichage de la progression et taille de chaque zone
- Mode 100% hors-ligne une fois les zones téléchargées

### 🌊 Bathymétrie LiDAR

- Overlay des campagnes Litto3D (bathymétrie haute résolution)
- 20+ campagnes couvrant les côtes françaises
- Opacité réglable de 0 à 100%
- Affichage conditionnel selon la zone visible

### 📍 Waypoints

- **3 catégories** : Pêche 🎣, Champignons 🍄, Autre 📌
- Couleur personnalisable par waypoint
- Enregistrement automatique de la précision GPS au moment du marquage
- Statut GPS persistant (Excellent/Bon/Moyen/Faible/Inconnu)
- Visibilité configurable par catégorie sur la carte
- Affichage des noms sur la carte (activable/désactivable)

### 🧭 Navigation

- Navigation active vers un waypoint sélectionné
- Bandeau en temps réel : distance, cap, vitesse, ETA
- Recentrage automatique sur position utilisateur
- Calcul de distance entre 2 points (mesure manuelle)

### 🔔 Alarmes de proximité

3 zones concentriques paramétrables :
- **Zone X** (loin) : première alerte
- **Zone Y** (intermédiaire) : alerte rapprochée
- **Zone Z** (proche) : alerte critique
- Alertes sonores avec haut-parleur activable/désactivable
- Surveillance automatique pendant la navigation

### 🌤️ Météo marine

- Catalogue de 180+ ports de pêche français
- URL météo personnalisable par port
- Ports favoris pour accès rapide
- Recherche par nom de port
- Ouverture directe dans le navigateur

### 🛰️ GPS

- Suivi continu avec indicateur de précision coloré
- 4 niveaux : Excellent (<8m), Bon (8-15m), Moyen (15-30m), Faible (>30m)
- Affichage vitesse (km/h ou nœuds) et cap
- Altitude et nombre de satellites
- Mode économie d'énergie (réduit la fréquence des mises à jour)

### 💾 Sauvegarde et export

**Export GPX**
- Export standard compatible tous GPS (Garmin, TomTom, Wahoo)
- Sélection multiple de waypoints
- Métadonnées enrichies : nom, catégorie, couleur, statut GPS

**Import GPX**
- Import depuis fichiers externes
- Choix : fusion (ajoute aux existants) ou remplacement complet
- Détection automatique des doublons

**Sauvegarde complète JSON**
- Export de tous les waypoints + réglages + préférences
- Restauration sur un autre appareil
- Partage via email, cloud, Bluetooth

### ⚙️ Personnalisation

- Unités de distance : mètres ou milles nautiques
- Unités de vitesse : km/h ou nœuds
- Type de carte par défaut
- Visibilité des waypoints par catégorie
- Opacité de la bathymétrie
- Mode hors-ligne forcé (bloque les requêtes réseau)

## 🚀 Installation

### Prérequis
- Flutter 3.16+
- Android Studio ou Xcode

### Étapes

```bash
git clone <repository-url>
cd my_spots
flutter pub get
dart run build_runner build
flutter run

```

### Permissions
- Android :
  - Localisation précise
  - Internet (pour cartes en ligne)
  - Stockage (pour cache hors-ligne)
- iOS :
  - Localisation quand l'app est active

### 📱 Utilisation
- Créer un waypoint
    - Maintenir appuyé sur la carte
    - Sélectionner "Ajouter un waypoint ici"
    - Choisir nom, catégorie, couleur
    - Valider
- Télécharger une zone hors-ligne
    - Maintenir appuyé sur la carte
    - Sélectionner "Tracer une zone hors-ligne"
    - Choisir rectangle ou main levée
    - Ajuster les bounds
    - Valider le téléchargement
- Naviguer vers un waypoint
    - Appuyer sur un waypoint sur la carte
    - Appuyer sur l'icône navigation 🧭
    - Le bandeau de navigation apparaît
    - Suivre le cap indiqué
- Mesurer une distance
    - Maintenir appuyé sur la carte
    - Sélectionner "Mesurer une distance"
    - Placer le premier point
    - Placer le second point
    - La distance s'affiche (mètres + milles nautiques)

### 📦 Dépendances principales
- flutter_map : rendu cartographique
- flutter_map_tile_caching : cache et téléchargement de tuiles
- geolocator : accès GPS
- objectbox : base de données locale
- audioplayers : alarmes sonores
- latlong2 : calculs géographiques
- url_launcher : ouverture météo dans navigateur

### 📄 Licence
- Projet privé - Tous droits réservés

**Développé avec ❤️ en Flutter et vibe coding pour les amateurs de plein air**
