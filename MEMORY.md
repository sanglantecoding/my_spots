Corrections module champignons (13/10/26) :

PARTIE A - Diagnostic (tests manuels annulés, analyse code) :
1. getTerrainBatch retourne Map vide par défaut dans TerrainService - pas d'implémentation batch IGN.
2. La cause réelle des "cellules sans données" : absence de données terrain/météo/forêt (dataSources null).
3. Aucun test live effectué : l'interface batch n'est pas implémentée dans IgnOpenElevationTerrainService.
4. Le service utilise getTerrainData (point unique) avec patch 3x3 pour chaque centre individuellement.
5. Forest batch via CompositeForestService mais sans diagnostic live sur les tuiles et distances.

PARTIE B - Corrections appliquées :
1. UI : contrôle (top:10), légende (top:60), bannière (top:110) empilés à gauche, bannière affiche le nombre.
2. Cellules sans données : fond gris alpha 0.4, bordure grise alpha 1.0, jamais colorées par l'indice.
3. "Meilleur jour" : compte uniquement les cellules avec terrain (dataSources['terrain'] != null).
4. Panneau "Où aller ?" : timeout 60s avec message "Délai dépassé", bouton Réessayer, étape affichée, GPS séparé avec timeout 8s.
5. Tri : par indice du jour sélectionné décroissant (meilleur au pire), affiche "J+X (meilleur) · J+Y: indice".

PARTIE C - Corrections clés et timeouts (13/10/26 suite) :
1. Clé unifiée : point_key.dart avec mushroomViewportPointKey (lat,lng 6 décimales, virgule).
2. getTerrainBatch retourne Map indexée par mushroomViewportPointKey, cache interne inchangé.
3. Callbacks onStage(String) dans calculateForPoints/ForWaypoints pour afficher étapes réelles.
4. Timeouts par étape : altitude 20s, météo 20s, forêt 30s - continue avec inconnu + avertissement.
5. Forêt optimisée : tuiles contenant des centres uniquement, 2 en parallèle, 12s par tuile, échec non mis en cache.

Test results (flutter test) :
00:18 +603 ~6: All other tests passed!
dart format : 160 fichiers (0 changed). flutter analyze : 0 issue.
