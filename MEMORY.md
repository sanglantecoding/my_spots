Features waypoints champignons (11/10/26) :

1. MushroomWaypointForecastService : calcul groupé via calculateForPoints, cache 3h, max 50 waypoints, messages hors-ligne.
2. MushroomWaypointPanel : sélecteur J+0..J+7, liste triée par indice/distance GPS, tap centre, long press ouvre fiche.
3. Pastilles sur carte non-marine : rond coloré avec indice du jour (gradient), gris si habitat exclu ou données absentes.
4. Intégration dans MushroomControlsWidget avec callbacks onCenterOnWaypoint, onOpenSheet, onDayChanged, onForecastsLoaded.
5. Tests widget : panel rend sans erreur, sélecteur J+0..J+7, mock avec excluded flag. Cache invalidé quand waypoints changent.

Test results (flutter test) :
00:03 +3: MushroomWaypointPanel panel builds without error
00:03 +3: MushroomWaypointPanel day selector renders J+0 to J+7
00:03 +3: MushroomWaypointPanel excluded waypoint shows gray color in mock
dart format : 157 fichiers (0 changed). flutter analyze : 0 issue.
