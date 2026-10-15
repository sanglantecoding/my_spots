Corrections module champignons (15/10/26) :

PARTIE A - Nettoyage et refactoring :
1. Helper _paletteChip unifié pour boutons palette dans mushroom_controls_widget.dart.
2. mushroom_waypoint_panel.dart : _mushroomWaypoints getter déjà présent, countWithoutData déjà en cache.
3. WeatherDay.cumulativePrecipitation/meanTemperature absents du code, non supprimés.
4. ForestData.treeDensity/canopyCover non utilisés (vérifié par grep), non supprimés.

PARTIE B - Corrections d'incohérences :
5. flutter_map 8.2.2 (>= 7) : contours pointillés (StrokePattern.dotted()) pour cases exclues et données manquantes.
6. Grille ancrée : floor(bound/pas)*pas avec cos(latitude arrondie à 0.1°), ligne/colonne de bord incluses dans le compte.
7. meshElevation depuis Open-Meteo, correction température par (meshElevation - altitudeCase) * 0.0065 °C/m (gradient standard).

PARTIE C - Points mineurs :
8. failedCellCount utilise !terrainKnown au lieu de elevation == null.
9. calculateForPoints : météo seulement pour points non exclus, onStage réel avant forêt, today normalisé, distinction TimeoutException/erreur, dataSources renseignés.
10. MushroomWaypointForecastService.countWithoutData vérifie dataSources['terrain']/['weather'], second appelant reçoit callbacks.
11. MushroomForecastService : météo et forêt en parallèle via Future.wait, forecastBoletusRange async.
12. map_screen.dart : _mushroomStartDate rafraîchi au changement de jour, polygones mémoïsés par (cellules, jour, opacité, palette).
13. map_view.dart : mushroomPolygons.length retiré de _criticalParamsChanged.

Test results (flutter test) :
00:14 +605 ~6: All other tests passed!
dart format : 167 fichiers (0 changed). flutter analyze : 0 issue.

