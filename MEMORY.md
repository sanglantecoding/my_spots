Corrections module champignons (12/10/26) :

1. Accents corrigés dans ign_bd_foret_forest_service.dart : 'forêt fermée/ouverte', 'conifère', 'fermée/ouverte', 'formation herbacée'.
2. MushroomWaypointForecastService renvoie Map<String, List<MushroomForecast>> au lieu de List<List>, clé = 'lat,lng'.
3. Cache indépendant de l'ordre : clé générée à partir des clés de waypoints triées, pas de l'ordre d'entrée.
4. map_view.dart utilise lookup par clé '${lat},${lng}' au lieu de indexOf pour les pastilles champignons.
5. Tests ajoutés : pastille correcte avec waypoints non-champignons avant/après, cache invariant par ordre, fiche Pluie 26 j/Gel récent/Hors saison, snapshot backward compatibility, lac OSM conservé même avec forêt BD Forêt.

Test results (flutter test) :
00:18 +584 ~6: All other tests passed!
dart format : 157 fichiers (0 changed). flutter analyze : 0 issue.
