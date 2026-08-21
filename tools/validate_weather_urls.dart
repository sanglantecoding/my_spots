import 'dart:io';

/// Script de validation des URLs Météo-France
/// Ce script vérifie chaque URL de port et identifie celles qui retournent 404
void main() async {
  print('=== Validation des URLs Météo-France ===\n');

  // Liste des ports avec leurs URLs (copiée depuis PortService)
  final ports = [
    // Méditerranée - Ports locaux
    {
      'key': 'palavas_les_flots',
      'name': 'Palavas-les-Flots',
      'url': 'https://meteofrance.com/meteo-marine/palavas-les-flots/570277',
    },
    {
      'key': 'carnon',
      'name': 'Carnon (Mauguio)',
      'url': 'https://meteofrance.com/meteo-marine/mauguio/34154',
    },
    {
      'key': 'la_grande_motte',
      'name': 'La Grande-Motte',
      'url': 'https://meteofrance.com/meteo-marine/la-grande-motte/34154',
    },
    {
      'key': 'le_grau_du_roi',
      'name': 'Le Grau-du-Roi',
      'url': 'https://meteofrance.com/meteo-marine/le-grau-du-roi/30133',
    },
    {
      'key': 'port_camargue',
      'name': 'Port-Camargue',
      'url': 'https://meteofrance.com/meteo-marine/port-camargue/30133',
    },
    {
      'key': 'sete',
      'name': 'Sète',
      'url': 'https://meteofrance.com/meteo-marine/sete/34301',
    },
    {
      'key': 'frontignan',
      'name': 'Frontignan',
      'url': 'https://meteofrance.com/meteo-marine/frontignan/34160',
    },
    {
      'key': 'meze',
      'name': 'Mèze',
      'url': 'https://meteofrance.com/meteo-marine/meze/34170',
    },
    {
      'key': 'bouzigues',
      'name': 'Bouzigues',
      'url': 'https://meteofrance.com/meteo-marine/bouzigues/34170',
    },
    {
      'key': 'marseillan',
      'name': 'Marseillan',
      'url': 'https://meteofrance.com/meteo-marine/marseillan/34300',
    },
    {
      'key': 'cap_agde',
      'name': 'Cap d\'Agde',
      'url': 'https://meteofrance.com/meteo-marine/agde/34003',
    },
    {
      'key': 'agde',
      'name': 'Agde',
      'url': 'https://meteofrance.com/meteo-marine/agde/34003',
    },
    {
      'key': 'valras_plage',
      'name': 'Valras-Plage',
      'url': 'https://meteofrance.com/meteo-marine/valras-plage/11395',
    },
    {
      'key': 'port_la_nouvelle',
      'name': 'Port-la-Nouvelle',
      'url': 'https://meteofrance.com/meteo-marine/port-la-nouvelle/11290',
    },
    {
      'key': 'gruissan',
      'name': 'Gruissan',
      'url': 'https://meteofrance.com/meteo-marine/gruissan/11179',
    },
    {
      'key': 'vendres_plage',
      'name': 'Vendres-Plage',
      'url': 'https://meteofrance.com/meteo-marine/vendres/11179',
    },
    {
      'key': 'collioure',
      'name': 'Collioure',
      'url': 'https://meteofrance.com/meteo-marine/collioure/66023',
    },
    {
      'key': 'port_vendres',
      'name': 'Port-Vendres',
      'url': 'https://meteofrance.com/meteo-marine/port-vendres/66023',
    },
    {
      'key': 'banyuls_sur_mer',
      'name': 'Banyuls-sur-Mer',
      'url': 'https://meteofrance.com/meteo-marine/banyuls-sur-mer/66019',
    },
    // Méditerranée - Autres ports
    {
      'key': 'perpignan',
      'name': 'Perpignan',
      'url': 'https://meteofrance.com/meteo-marine/perpignan/66136',
    },
    {
      'key': 'montpellier',
      'name': 'Montpellier',
      'url': 'https://meteofrance.com/meteo-marine/montpellier/34172',
    },
    {
      'key': 'aigues_mortes',
      'name': 'Aigues-Mortes',
      'url': 'https://meteofrance.com/meteo-marine/aigues-mortes/30003',
    },
    {
      'key': 'marseille',
      'name': 'Marseille',
      'url': 'https://meteofrance.com/meteo-marine/marseille/13055',
    },
    {
      'key': 'toulon',
      'name': 'Toulon',
      'url': 'https://meteofrance.com/meteo-marine/toulon/83137',
    },
    {
      'key': 'nice',
      'name': 'Nice',
      'url': 'https://meteofrance.com/meteo-marine/nice/06088',
    },
    {
      'key': 'cannes',
      'name': 'Cannes',
      'url': 'https://meteofrance.com/meteo-marine/cannes/06029',
    },
    {
      'key': 'antibes',
      'name': 'Antibes',
      'url': 'https://meteofrance.com/meteo-marine/antibes/06004',
    },
    {
      'key': 'saint_tropez',
      'name': 'Saint-Tropez',
      'url': 'https://meteofrance.com/meteo-marine/saint-tropez/83120',
    },
    // Corse
    {
      'key': 'ajaccio',
      'name': 'Ajaccio',
      'url': 'https://meteofrance.com/meteo-marine/ajaccio/2A004',
    },
    {
      'key': 'bastia',
      'name': 'Bastia',
      'url': 'https://meteofrance.com/meteo-marine/bastia/2B033',
    },
    {
      'key': 'calvi',
      'name': 'Calvi',
      'url': 'https://meteofrance.com/meteo-marine/calvi/2B060',
    },
    {
      'key': 'bonifacio',
      'name': 'Bonifacio',
      'url': 'https://meteofrance.com/meteo-marine/bonifacio/2A041',
    },
    {
      'key': 'porto_vecchio',
      'name': 'Porto-Vecchio',
      'url': 'https://meteofrance.com/meteo-marine/porto-vecchio/2A224',
    },
    {
      'key': 'ile_rousse',
      'name': 'Ile-Rousse',
      'url': 'https://meteofrance.com/meteo-marine/ile-rousse/2B133',
    },
    {
      'key': 'propriano',
      'name': 'Propriano',
      'url': 'https://meteofrance.com/meteo-marine/propriano/2A212',
    },
    // Manche / Mer du Nord
    {
      'key': 'dunkerque',
      'name': 'Dunkerque',
      'url': 'https://meteofrance.com/meteo-marine/dunkerque/59183',
    },
    {
      'key': 'boulogne_sur_mer',
      'name': 'Boulogne-sur-Mer',
      'url': 'https://meteofrance.com/meteo-marine/boulogne-sur-mer/62122',
    },
    {
      'key': 'dieppe',
      'name': 'Dieppe',
      'url': 'https://meteofrance.com/meteo-marine/dieppe/76217',
    },
    {
      'key': 'le_havre',
      'name': 'Le Havre',
      'url': 'https://meteofrance.com/meteo-marine/le-havre/76351',
    },
    {
      'key': 'rouen',
      'name': 'Rouen',
      'url': 'https://meteofrance.com/meteo-marine/rouen/76540',
    },
    {
      'key': 'caen',
      'name': 'Caen',
      'url': 'https://meteofrance.com/meteo-marine/caen/14158',
    },
    {
      'key': 'cherbourg',
      'name': 'Cherbourg',
      'url': 'https://meteofrance.com/meteo-marine/cherbourg/50129',
    },
    {
      'key': 'saint_malo',
      'name': 'Saint-Malo',
      'url': 'https://meteofrance.com/meteo-marine/saint-malo/35288',
    },
    {
      'key': 'dinard',
      'name': 'Dinard',
      'url': 'https://meteofrance.com/meteo-marine/dinard/35087',
    },
    {
      'key': 'granville',
      'name': 'Granville',
      'url': 'https://meteofrance.com/meteo-marine/granville/50217',
    },
    {
      'key': 'saint_brieuc',
      'name': 'Saint-Brieuc',
      'url': 'https://meteofrance.com/meteo-marine/saint-brieuc/22278',
    },
    // Bretagne
    {
      'key': 'brest',
      'name': 'Brest',
      'url': 'https://meteofrance.com/meteo-marine/brest/29019',
    },
    {
      'key': 'lorient',
      'name': 'Lorient',
      'url': 'https://meteofrance.com/meteo-marine/lorient/56126',
    },
    {
      'key': 'concarneau',
      'name': 'Concarneau',
      'url': 'https://meteofrance.com/meteo-marine/concarneau/29039',
    },
    {
      'key': 'quimper',
      'name': 'Quimper',
      'url': 'https://meteofrance.com/meteo-marine/quimper/29232',
    },
    {
      'key': 'douarnenez',
      'name': 'Douarnenez',
      'url': 'https://meteofrance.com/meteo-marine/douarnenez/29045',
    },
    {
      'key': 'roscoff',
      'name': 'Roscoff',
      'url': 'https://meteofrance.com/meteo-marine/roscoff/29260',
    },
    {
      'key': 'morlaix',
      'name': 'Morlaix',
      'url': 'https://meteofrance.com/meteo-marine/morlaix/29151',
    },
    // Atlantique
    {
      'key': 'saint_nazaire',
      'name': 'Saint-Nazaire',
      'url': 'https://meteofrance.com/meteo-marine/saint-nazaire/44109',
    },
    {
      'key': 'nantes',
      'name': 'Nantes',
      'url': 'https://meteofrance.com/meteo-marine/nantes/44109',
    },
    {
      'key': 'la_rochelle',
      'name': 'La Rochelle',
      'url': 'https://meteofrance.com/meteo-marine/la-rochelle/17300',
    },
    {
      'key': 'rochefort',
      'name': 'Rochefort',
      'url': 'https://meteofrance.com/meteo-marine/rochefort/17300',
    },
    {
      'key': 'royan',
      'name': 'Royan',
      'url': 'https://meteofrance.com/meteo-marine/royan/17303',
    },
    {
      'key': 'bordeaux',
      'name': 'Bordeaux',
      'url': 'https://meteofrance.com/meteo-marine/bordeaux/33063',
    },
    {
      'key': 'arcachon',
      'name': 'Arcachon',
      'url': 'https://meteofrance.com/meteo-marine/arcachon/33009',
    },
    {
      'key': 'bayonne',
      'name': 'Bayonne',
      'url': 'https://meteofrance.com/meteo-marine/bayonne/64144',
    },
    {
      'key': 'biarritz',
      'name': 'Biarritz',
      'url': 'https://meteofrance.com/meteo-marine/biarritz/64122',
    },
    {
      'key': 'saint_jean_de_luz',
      'name': 'Saint-Jean-de-Luz',
      'url': 'https://meteofrance.com/meteo-marine/saint-jean-de-luz/64485',
    },
    {
      'key': 'hendaye',
      'name': 'Hendaye',
      'url': 'https://meteofrance.com/meteo-marine/hendaye/64240',
    },
    // Ports de pêche majeurs
    {
      'key': 'boulogne_sur_mer_peche',
      'name': 'Boulogne-sur-Mer (Pêche)',
      'url': 'https://meteofrance.com/meteo-marine/boulogne-sur-mer/62122',
    },
    {
      'key': 'lorient_peche',
      'name': 'Lorient (Pêche)',
      'url': 'https://meteofrance.com/meteo-marine/lorient/56126',
    },
    {
      'key': 'concarneau_peche',
      'name': 'Concarneau (Pêche)',
      'url': 'https://meteofrance.com/meteo-marine/concarneau/29039',
    },
    {
      'key': 'saint_malo_peche',
      'name': 'Saint-Malo (Pêche)',
      'url': 'https://meteofrance.com/meteo-marine/saint-malo/35288',
    },
    {
      'key': 'dieppe_peche',
      'name': 'Dieppe (Pêche)',
      'url': 'https://meteofrance.com/meteo-marine/dieppe/76217',
    },
    {
      'key': 'granville_peche',
      'name': 'Granville (Pêche)',
      'url': 'https://meteofrance.com/meteo-marine/granville/50217',
    },
    {
      'key': 'le_guilvinec',
      'name': 'Le Guilvinec',
      'url': 'https://meteofrance.com/meteo-marine/le-guilvinec/29072',
    },
    {
      'key': 'douarnenez_peche',
      'name': 'Douarnenez (Pêche)',
      'url': 'https://meteofrance.com/meteo-marine/douarnenez/29045',
    },
    {
      'key': 'saint_guenole',
      'name': 'Saint-Guénolé',
      'url': 'https://meteofrance.com/meteo-marine/saint-guenole/29072',
    },
    {
      'key': 'lesconil',
      'name': 'Lesconil',
      'url': 'https://meteofrance.com/meteo-marine/lesconil/29072',
    },
    {
      'key': 'loctudy',
      'name': 'Loctudy',
      'url': 'https://meteofrance.com/meteo-marine/loctudy/29127',
    },
  ];

  final validPorts = <Map<String, String>>[];
  final invalidPorts = <Map<String, String>>[];
  final networkErrors = <Map<String, String>>[];

  print('Vérification de ${ports.length} ports...\n');

  for (final port in ports) {
    final url = port['url'] as String;
    final name = port['name'] as String;
    final key = port['key'] as String;

    try {
      final result = await checkUrl(url);

      if (result['valid'] == true) {
        validPorts.add(port);
        print('✓ ${name.padRight(25)} - ${result['statusCode']}');
      } else {
        invalidPorts.add(port);
        print('✗ ${name.padRight(25)} - ${result['statusCode']} (INVALID)');
      }
    } catch (e) {
      networkErrors.add(port);
      print('⚠ ${name.padRight(25)} - ERREUR RÉSEAU: $e');
    }

    // Délai pour éviter d'être bloqué par Météo-France
    await Future.delayed(const Duration(milliseconds: 500));
  }

  print('\n=== RÉSUMÉ ===');
  print('Ports valides: ${validPorts.length}');
  print('Ports invalides (404/autre): ${invalidPorts.length}');
  print('Erreurs réseau: ${networkErrors.length}');

  if (invalidPorts.isNotEmpty) {
    print('\n=== PORTS INVALIDES (à supprimer) ===');
    for (final port in invalidPorts) {
      print('${port['key']}: ${port['name']} - ${port['url']}');
    }
  }

  if (networkErrors.isNotEmpty) {
    print('\n=== ERREURS RÉSEAU (à vérifier manuellement) ===');
    for (final port in networkErrors) {
      print('${port['key']}: ${port['name']} - ${port['url']}');
    }
  }

  print('\n=== LISTE DES PORTS VALIDES (pour PortService) ===');
  for (final port in validPorts) {
    print('FishingPort(');
    print('  key: \'${port['key']}\',');
    print('  name: \'${port['name']}\',');
    print('  weatherUrl: \'${port['url']}\',');
    print('  latitude: ${port['latitude'] ?? '43.0000'},');
    print('  longitude: ${port['longitude'] ?? '3.0000'},');
    print('),');
  }
}

Future<Map<String, dynamic>> checkUrl(String url) async {
  final uri = Uri.parse(url);
  final client = HttpClient();

  try {
    final request = await client.getUrl(uri);
    final response = await request.close();

    final statusCode = response.statusCode;
    final isValid = statusCode == 200 || statusCode == 301 || statusCode == 302;

    return {'valid': isValid, 'statusCode': statusCode};
  } catch (e) {
    rethrow;
  } finally {
    client.close();
  }
}
