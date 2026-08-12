# 🎣 My Spots

*Application mobile de navigation et gestion de waypoints pour la pêche, la chasse aux champignons et autres activités de plein air.*

---

## 🌟 Fonctionnalités principales

### 🧭 Navigation active
- **Bandeau de navigation** avec informations en temps réel
- **Distance vers le waypoint** (m/nm/km selon préférences)
- **Cap compas** normalisé (0-360°) pour suivre la direction
- **Vitesse actuelle** en temps réel (nœuds pour pêche, km/h pour terrestre)
- **ETA (Estimated Time of Arrival)** calculé dynamiquement
- **Bouton "Y aller"** pour activer la navigation vers un waypoint
- **Bouton d'arrêt** intégré dans le bandeau
- **Contrôle audio** : Bouton Mute pour couper/réactiver les bips

### 🗺️ Navigation GPS en temps réel
- **Suivi GPS continu** avec indicateur de précision coloré
- **4 niveaux de précision** : Excellent (<8m), Correct (8-15m), Moyen (15-30m), Faible (>30m)
- **Mode économie d'énergie** pour prolonger l'autonomie
- **Affichage de la vitesse** et du cap en temps réel
- **Vue détaillée des satellites** : nombre, type GNSS, signal, altitude

### 📍 Gestion multi-catégories de waypoints
- **🎣 Pêche** : Points de pêche favoris avec marées et météo
- **🍄 Champignons** : Zones de cueillette avec distances en km/mètres
- **🚗 Voiture/Autre** : Points de stationnement et repères divers
- **Personnalisation** : Couleurs et noms pour chaque waypoint
- **Précision historique** : Chaque waypoint enregistre la précision GPS lors de sa création

### 📊 Import/Export GPX complet
- **Exportation GPX** standard pour compatibilité avec tous les GPS
- **Importation GPX** depuis fichiers externes
- **Sélection multiple** pour export ciblé
- **Métadonnées enrichies** : nom, position, couleur, catégorie, statut GPS
- **Historique de fiabilité** : Chaque waypoint conserve son statut de précision
- **Compatibilité descendante** : Points anciens affichés avec statut "Inconnu"

### 💾 Sauvegarde complète haute fidélité
- **Export complet** : Waypoints + réglages + métadonnées de précision
- **Historique préservé** : Précision GPS et statut de chaque waypoint conservés
- **Import robuste** : Gestion gracieuse des données manquantes avec valeurs par défaut
- **Migration sans perte** : Transfert parfait entre appareils ou réinstallations
- **Fichier JSON structuré** : Format lisible et versionné pour compatibilité

### 🛰️ Informations satellites avancées
- **Accès direct** : Clic sur le signal GPS (accueil et carte)
- **Détails complets** : Satellites utilisés/visibles, type GNSS
- **Signal en temps réel** : Barre de progression et pourcentage
- **Altitude live** : Affichage et mise à jour automatique
- **Liste individuelle** : Chaque satellite avec force du signal

---

## ⚠️ Système d'alarme de proximité

### 🎯 3 zones d'alarme configurables
- **Zone X** (100m par défaut) : Bip lent toutes les 4 secondes
- **Zone Y** (20m par défaut) : Bip-bip toutes les 2 secondes  
- **Zone Z** (5m par défaut) : Bip continu toutes les 500ms

### 🔊 Caractéristiques avancées
- **Audio uniquement** : Bips sonores sans retour tactile
- **Activation explicite** : Alarmes déclenchées uniquement en mode navigation actif
- **Indicateur visuel** : Icône d'alarme affichée dans les zones actives
- **Arrêt automatique** : Désactivation hors de la zone X
- **Contrôle Mute** : Bouton intégré dans le bandeau de navigation

### ⚙️ Personnalisation
- Distances ajustables (X: 10-1000m, Y: 5-500m, Z: 1-100m)
- Activation/désactivation de l'alarme
- Contrôle du son (Mute/Unmute) pendant la navigation

---

## 🎯 Gestion des waypoints

### 📝 Création et édition
- **Interface glissante** pour création rapide
- **Vérification de précision GPS** avant enregistrement
- **Alerte de sécurité** si précision > seuil configuré
- **Édition** : nom, catégorie, couleur, position
- **Métadonnées précision** : Enregistrement automatique de la précision GPS

### 🎨 Personnalisation
- **8 couleurs prédéfinies** pour identification visuelle
- **3 catégories** avec icônes distinctes
- **Affichage optionnel** : noms, dates sur la carte
- **Taille de police** ajustable (10-20pt)
- **Indicateurs de précision** : Icônes colorées dans la liste
- **Historique visuel** : Points anciens avec icône grise claire ("Inconnu")
- **Signal inconnu** : Gestion dédiée pour les imports sans métadonnées

### 🔍 Filtrage et affichage
- **Filtres par catégorie** : Pêche, Champignons, Autre
- **Visibilité contrôlée** de chaque type de waypoint
- **Affichage sélectif** des noms et dates
- **Recherche rapide** par nom
- **Tri intelligent** : Par distance depuis position actuelle
- **Affichage distances** : "à 450 m" ou "à 1.2 km"

---

## 🎨 Interface utilisateur

### 📱 Design moderne et intuitif
- **Interface sombre** : Optimisée pour usage extérieur
- **Navigation fluide** : Transitions et animations naturelles
- **Icônes thématiques** : Pêche (ancre), Champignons (forêt), Voiture (GPS)
- **Code couleur** : Vert (excellent), Jaune (correct), Orange (moyen), Rouge (faible)

### 🗺️ Cartographie interactive
- **3 types de fonds** : Standard, Relief, Randonnée
- **Zoom fluide** : Du niveau local au niveau régional
- **Marqueurs dynamiques** : Adaptation selon le niveau de zoom
- **Mode plein écran** : Navigation sans distraction

---

## ⚡ Performance et optimisation

### 🔋 Économie d'énergie
- **Mode éco** : Réduction de la fréquence GPS
- **Gestion intelligente** : Arrêt automatique en arrière-plan
- **Optimisation mémoire** : Nettoyage automatique des ressources
- **Batterie prolongée** : Jusqu'à 12h d'utilisation continue

### 📊 Métriques de performance
- **Démarrage** : <2 secondes
- **Consommation batterie** : Optimisée avec mode éco
- **Mémoire** : Gestion centralisée des ressources
- **Précision GPS** : Jusqu'à 5 mètres en conditions idéales

---

## 📖 Guide d'utilisation

### 🎨 Interpréter les couleurs du signal GPS

#### 🟢 **Vert - Signal Excellent (< 8m)**
- **Précision optimale** pour navigation précise
- **Idéal pour** : marquage de points exacts, navigation fine
- **Confiance** : Très élevée

#### 🟡 **Jaune - Signal Correct (8-15m)**
- **Précision bonne** pour usage général
- **Idéal pour** : repérage de zones, navigation approximative
- **Confiance** : Élevée

#### 🟠 **Orange - Signal Moyen (15-30m)**
- **Précision acceptable** avec marge d'erreur
- **Idéal pour** : repérage grossier, zones larges
- **Confiance** : Modérée

#### 🔴 **Rouge - Signal Faible (> 30m)**
- **Précision limitée** pour informations générales
- **Idéal pour** : localisation approximative seulement
- **Confiance** : Faible

### 📤 Exporter ses données

#### **Export GPX (Standard)**
1. **Accéder** à l'écran des waypoints
2. **Appuyer** sur le bouton 📤 en haut à droite
3. **Sélectionner** les waypoints à exporter (cases à cocher)
4. **Choisir** "EXPORTER (X)" pour le fichier GPX
5. **Partager** : Email, Cloud, Bluetooth, etc.

#### **Sauvegarde complète (JSON)**
1. **Aller** dans les paramètres
2. **Appuyer** sur "Exporter tout"
3. **Partager** le fichier de sauvegarde
4. **Contient** : Waypoints + réglages + métadonnées

#### **Compatibilité**
- **Garmin**, **TomTom**, **Wahoo**, et tous les GPS compatibles GPX
- **Logiciels** : Google Earth, QGIS, OziExplorer
- **Applications** : OsmAnd, Gaia GPS, AllTrails

### 🛰️ Accéder aux détails satellites

#### **Depuis l'écran d'accueil**
- **Cliquer** sur le statut GPS coloré (ex: "GPS OK")
- **Informations** : Satellites, type GNSS, signal, altitude

#### **Depuis la vue carte**
- **Cliquer** sur l'icône GPS dans la barre d'outils
- **Mêmes informations** que depuis l'accueil

### 🧭 Utiliser la navigation active

#### **Activer la navigation**
1. **Sélectionner** un waypoint sur la carte (tap sur le marqueur)
2. **Cliquer** sur le bouton "Y aller" (icône navigation bleue) dans le panneau d'information
3. **Le bandeau de navigation** apparaît en haut de l'écran avec :
   - Distance vers le waypoint
   - Cap à suivre
   - Vitesse actuelle
   - ETA (temps d'arrivée estimé)
4. **Les alarmes de proximité** s'activent automatiquement

#### **Contrôler le son**
- **Cliquer** sur l'icône volume_up (bleue) pour couper le son
- **Cliquer** sur l'icône volume_off (grise) pour réactiver le son
- **Le mode Mute** désactive uniquement les bips, pas la navigation

#### **Arrêter la navigation**
- **Cliquer** sur la croix rouge** dans le bandeau de navigation
- **Le bandeau disparaît** et les alarmes s'arrêtent

### 📊 Paramètres conservés

#### **Configuration sauvegardée**
- **Unités** : Métrique (km/h) ou Nautique (nœuds)
- **Police** : Taille des textes (10-20pt)
- **Carte** : Type de fond préféré
- **Alarmes** : Distances des 3 zones
- **Affichage** : Visibilité des catégories

#### **Exportation des préférences**
- **Toutes les configurations** sont automatiquement sauvegardées
- **Restauration** automatique au redémarrage
- **Compatibilité** multi-appareils via synchronisation

---

## 🏗️ Installation et utilisation

### 📋 Prérequis
- **Android** : 6.0+ (API 23+)
- **GPS** : Activé et autorisé
- **Espace de stockage** : ~50MB

### 🎯 Première utilisation
1. **Autoriser la localisation** au lancement
2. **Attendre le signal GPS** (indicateur vert)
3. **Créer votre premier waypoint** avec le bouton +
4. **Configurer les alarmes** si nécessaire
5. **Personnaliser l'affichage** dans les paramètres

---

## 📝 Notes de version

### 🆕 v1.01 - 20 Juin 2026
- **Navigation active** : Bandeau avec distance, cap, vitesse, ETA
- **Contrôle audio** : Bouton Mute intégré dans le bandeau
- **Refactoring alarmes** : Service autonome AlarmService
- **Activation explicite** : Alarmes uniquement en mode navigation
- **Suppression vibrations** : Son uniquement, plus de retour tactile
- **Bug corrigé** : Plus de bip involontaire à la sélection de waypoint

### 📝 Notes de version v1.00 - 5 Mars 2026

### ✨ Fonctionnalités principales
- **Navigation GPS** en temps réel avec précision colorée
- **Gestion waypoints** multi-catégories (Pêche/Champignons/Autre)
- **Carte interactive** avec 3 types de fonds
- **Alarme proximité** à 3 zones configurables
- **Interface glissante** pour création/édition
- **Paramètres complets** : unités, police, visibilité

### 🛰️ Fonctionnalités avancées
- **Vue détaillée des satellites** : nombre, type GNSS, signal, altitude
- **Import/Export GPX** : Standard avec métadonnées enrichies
- **Précision historique** : Chaque waypoint enregistre la précision GPS
- **Tri intelligent** : Waypoints automatiquement triés par distance
- **Sauvegarde complète** : Waypoints + réglages + métadonnées
- **Accès direct satellites** : Clic sur signal GPS

---

## 📱 Compatibilité

### Plateformes supportées
- **Android** : 6.0+ (API 23+)

### Formats supportés
- **GPX 1.1** : Import/Export standard
- **JSON** : Sauvegarde interne
- **OpenStreetMap** : Fonds de carte
- **TopoMap** : Cartes de relief

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

**Développé avec ❤️ en Flutter pour les amateurs de plein air**

*Version 1.01 - Navigation active et refactoring des alarmes*
