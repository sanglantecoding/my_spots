import 'package:my_spots/models/fishing_port.dart';

/// Service singleton pour la gestion des ports de pêche et météo marine
class PortService {
  PortService._();

  static final PortService instance = PortService._();

  /// Liste maîtresse des ports français côtiers/pêche avec leurs URLs Météo-France
  static const List<FishingPort> _frenchPorts = [
    FishingPort(
      key: 'aber_benoit',
      name: 'Aber Benoit',
      weatherUrl: 'https://meteofrance.com/meteo-marine/aber-benoit/570442',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'ajaccio',
      name: 'Ajaccio',
      weatherUrl: 'https://meteofrance.com/meteo-marine/ajaccio/570232',
      latitude: 41.9192,
      longitude: 8.7386,
    ),

    FishingPort(
      key: 'anse_de_primel',
      name: 'Anse De Primel',
      weatherUrl: 'https://meteofrance.com/meteo-marine/anse-de-primel/570457',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'antibes',
      name: 'Antibes',
      weatherUrl: 'https://meteofrance.com/meteo-marine/antibes/570250',
      latitude: 43.5808,
      longitude: 7.1239,
    ),

    FishingPort(
      key: 'arcachon_eyrac',
      name: 'Arcachon Eyrac',
      weatherUrl: 'https://meteofrance.com/meteo-marine/arcachon-eyrac/570253',
      latitude: 44.6626,
      longitude: -1.1708,
    ),

    FishingPort(
      key: 'arradon',
      name: 'Arradon',
      weatherUrl: 'https://meteofrance.com/meteo-marine/arradon/570367',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'arromanches_les_bains',
      name: 'Arromanches Les Bains',
      weatherUrl:
          'https://meteofrance.com/meteo-marine/arromanches-les-bains/570505',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'audierne',
      name: 'Audierne',
      weatherUrl: 'https://meteofrance.com/meteo-marine/audierne/570412',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'auray',
      name: 'Auray',
      weatherUrl: 'https://meteofrance.com/meteo-marine/auray/570394',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'barfleur',
      name: 'Barfleur',
      weatherUrl: 'https://meteofrance.com/meteo-marine/barfleur/570535',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'bastia',
      name: 'Bastia',
      weatherUrl: 'https://meteofrance.com/meteo-marine/bastia/570205',
      latitude: 42.6973,
      longitude: 9.4509,
    ),

    FishingPort(
      key: 'binic',
      name: 'Binic',
      weatherUrl: 'https://meteofrance.com/meteo-marine/binic/570418',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'biscarrosse',
      name: 'Biscarrosse',
      weatherUrl: 'https://meteofrance.com/meteo-marine/biscarrosse/570262',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'bonifacio',
      name: 'Bonifacio',
      weatherUrl: 'https://meteofrance.com/meteo-marine/bonifacio/570193',
      latitude: 41.3879,
      longitude: 9.1598,
    ),

    FishingPort(
      key: 'bordeaux',
      name: 'Bordeaux',
      weatherUrl: 'https://meteofrance.com/meteo-marine/bordeaux/570292',
      latitude: 44.8378,
      longitude: -0.5792,
    ),

    FishingPort(
      key: 'boucau_bayonne',
      name: 'Boucau Bayonne',
      weatherUrl: 'https://meteofrance.com/meteo-marine/boucau-bayonne/570286',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'boulogne_sur_mer',
      name: 'Boulogne Sur Mer',
      weatherUrl:
          'https://meteofrance.com/meteo-marine/boulogne-sur-mer/570586',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'brest',
      name: 'Brest',
      weatherUrl: 'https://meteofrance.com/meteo-marine/brest/570424',
      latitude: 48.3904,
      longitude: -4.4861,
    ),

    FishingPort(
      key: 'brignogan_plage',
      name: 'Brignogan Plage',
      weatherUrl: 'https://meteofrance.com/meteo-marine/brignogan-plage/570493',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'calais',
      name: 'Calais',
      weatherUrl: 'https://meteofrance.com/meteo-marine/calais/570580',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'calvi_et_ile_rousse',
      name: 'Calvi Et Ile Rousse',
      weatherUrl:
          'https://meteofrance.com/meteo-marine/calvi-et-ile-rousse/570214',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'camaret_sur_mer',
      name: 'Camaret Sur Mer',
      weatherUrl: 'https://meteofrance.com/meteo-marine/camaret-sur-mer/570439',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'cancale',
      name: 'Cancale',
      weatherUrl: 'https://meteofrance.com/meteo-marine/cancale/570475',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'cannes',
      name: 'Cannes',
      weatherUrl: 'https://meteofrance.com/meteo-marine/cannes/570259',
      latitude: 43.55,
      longitude: 7.0128,
    ),

    FishingPort(
      key: 'cap_d_agde',
      name: 'Cap D Agde',
      weatherUrl: 'https://meteofrance.com/meteo-marine/cap-d-agde/570229',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'cap_ferret',
      name: 'Cap Ferret',
      weatherUrl: 'https://meteofrance.com/meteo-marine/cap-ferret/570244',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'carteret',
      name: 'Carteret',
      weatherUrl: 'https://meteofrance.com/meteo-marine/carteret/570532',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'cayeux_sur_mer',
      name: 'Cayeux Sur Mer',
      weatherUrl: 'https://meteofrance.com/meteo-marine/cayeux-sur-mer/570571',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'chateau_du_taureau',
      name: 'Chateau Du Taureau',
      weatherUrl:
          'https://meteofrance.com/meteo-marine/chateau-du-taureau/570484',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'cherbourg',
      name: 'Cherbourg',
      weatherUrl: 'https://meteofrance.com/meteo-marine/cherbourg/570544',
      latitude: 49.6337,
      longitude: -1.6221,
    ),

    FishingPort(
      key: 'concarneau',
      name: 'Concarneau',
      weatherUrl: 'https://meteofrance.com/meteo-marine/concarneau/570421',
      latitude: 47.875,
      longitude: -3.9183,
    ),

    FishingPort(
      key: 'cordouan',
      name: 'Cordouan',
      weatherUrl: 'https://meteofrance.com/meteo-marine/cordouan/570265',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'courseulles_sur_mer',
      name: 'Courseulles Sur Mer',
      weatherUrl:
          'https://meteofrance.com/meteo-marine/courseulles-sur-mer/570520',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'dahouet',
      name: 'Dahouet',
      weatherUrl: 'https://meteofrance.com/meteo-marine/dahouet/570436',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'deauville',
      name: 'Deauville',
      weatherUrl: 'https://meteofrance.com/meteo-marine/deauville/570541',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'dielette',
      name: 'Dielette',
      weatherUrl: 'https://meteofrance.com/meteo-marine/dielette/570508',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'dieppe',
      name: 'Dieppe',
      weatherUrl: 'https://meteofrance.com/meteo-marine/dieppe/570583',
      latitude: 49.922,
      longitude: 1.077,
    ),

    FishingPort(
      key: 'dives_sur_mer',
      name: 'Dives Sur Mer',
      weatherUrl: 'https://meteofrance.com/meteo-marine/dives-sur-mer/570529',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'douarnenez',
      name: 'Douarnenez',
      weatherUrl: 'https://meteofrance.com/meteo-marine/douarnenez/570403',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'dunkerque',
      name: 'Dunkerque',
      weatherUrl: 'https://meteofrance.com/meteo-marine/dunkerque/570568',
      latitude: 51.0344,
      longitude: 2.377,
    ),

    FishingPort(
      key: 'entree_baie_de_somme',
      name: 'Entree Baie De Somme',
      weatherUrl:
          'https://meteofrance.com/meteo-marine/entree-baie-de-somme/570565',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'erquy',
      name: 'Erquy',
      weatherUrl: 'https://meteofrance.com/meteo-marine/erquy/570400',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'etel',
      name: 'Etel',
      weatherUrl: 'https://meteofrance.com/meteo-marine/etel/570349',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'etretat',
      name: 'Etretat',
      weatherUrl: 'https://meteofrance.com/meteo-marine/etretat/570562',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'fecamp',
      name: 'Fecamp',
      weatherUrl: 'https://meteofrance.com/meteo-marine/fecamp/570556',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'fort_mahon_berck_plage',
      name: 'Fort Mahon Berck Plage',
      weatherUrl:
          'https://meteofrance.com/meteo-marine/fort-mahon-berck-plage/570559',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'fos_sur_mer',
      name: 'Fos Sur Mer',
      weatherUrl: 'https://meteofrance.com/meteo-marine/fos-sur-mer/570295',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'fromentine_embarcadere',
      name: 'Fromentine Embarcadere',
      weatherUrl:
          'https://meteofrance.com/meteo-marine/fromentine-embarcadere/570337',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'grandcamp',
      name: 'Grandcamp',
      weatherUrl: 'https://meteofrance.com/meteo-marine/grandcamp/570523',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'granville',
      name: 'Granville',
      weatherUrl: 'https://meteofrance.com/meteo-marine/granville/570490',
      latitude: 48.837,
      longitude: -1.597,
    ),

    FishingPort(
      key: 'gravelines',
      name: 'Gravelines',
      weatherUrl: 'https://meteofrance.com/meteo-marine/gravelines/570574',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'gruissan',
      name: 'Gruissan',
      weatherUrl: 'https://meteofrance.com/meteo-marine/gruissan/570187',
      latitude: 43.1056,
      longitude: 3.1025,
    ),

    FishingPort(
      key: 'hennebont',
      name: 'Hennebont',
      weatherUrl: 'https://meteofrance.com/meteo-marine/hennebont/570397',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'hyeres',
      name: 'Hyeres',
      weatherUrl: 'https://meteofrance.com/meteo-marine/hyeres/570226',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'ile_d_aix',
      name: 'Ile D Aix',
      weatherUrl: 'https://meteofrance.com/meteo-marine/ile-d-aix/570343',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'ile_de_brehat',
      name: 'Ile De Brehat',
      weatherUrl: 'https://meteofrance.com/meteo-marine/ile-de-brehat/570463',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'ile_de_hoedic',
      name: 'Ile De Hoedic',
      weatherUrl: 'https://meteofrance.com/meteo-marine/ile-de-hoedic/570331',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'iles_des_ebihens',
      name: 'Iles Des Ebihens',
      weatherUrl:
          'https://meteofrance.com/meteo-marine/iles-des-ebihens/570427',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'iles_levant',
      name: 'Iles Levant',
      weatherUrl: 'https://meteofrance.com/meteo-marine/iles-levant/570208',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'iles_porquerolles',
      name: 'Iles Porquerolles',
      weatherUrl:
          'https://meteofrance.com/meteo-marine/iles-porquerolles/570235',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'l_herbaudiere',
      name: 'L Herbaudiere',
      weatherUrl: 'https://meteofrance.com/meteo-marine/l-herbaudiere/570328',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'la_ciotat',
      name: 'La Ciotat',
      weatherUrl: 'https://meteofrance.com/meteo-marine/la-ciotat/570199',
      latitude: 43.1742,
      longitude: 5.6075,
    ),

    FishingPort(
      key: 'la_cotiniere',
      name: 'La Cotiniere',
      weatherUrl: 'https://meteofrance.com/meteo-marine/la-cotiniere/570298',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'la_rochelle_pallice',
      name: 'La Rochelle Pallice',
      weatherUrl:
          'https://meteofrance.com/meteo-marine/la-rochelle-pallice/570325',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'la_trinite_sur_mer',
      name: 'La Trinite Sur Mer',
      weatherUrl:
          'https://meteofrance.com/meteo-marine/la-trinite-sur-mer/570376',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'lacanau',
      name: 'Lacanau',
      weatherUrl: 'https://meteofrance.com/meteo-marine/lacanau/570283',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'le_conquet',
      name: 'Le Conquet',
      weatherUrl: 'https://meteofrance.com/meteo-marine/le-conquet/570433',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'le_croisic',
      name: 'Le Croisic',
      weatherUrl: 'https://meteofrance.com/meteo-marine/le-croisic/570340',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'le_grau_du_roi',
      name: 'Le Grau Du Roi',
      weatherUrl: 'https://meteofrance.com/meteo-marine/le-grau-du-roi/570268',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'le_guilvinec',
      name: 'Le Guilvinec',
      weatherUrl: 'https://meteofrance.com/meteo-marine/le-guilvinec/570361',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'le_havre',
      name: 'Le Havre',
      weatherUrl: 'https://meteofrance.com/meteo-marine/le-havre/570514',
      latitude: 49.4944,
      longitude: 0.1079,
    ),

    FishingPort(
      key: 'le_legue',
      name: 'Le Legue',
      weatherUrl: 'https://meteofrance.com/meteo-marine/le-legue/570406',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'le_legue_port',
      name: 'Le Legue Port',
      weatherUrl: 'https://meteofrance.com/meteo-marine/le-legue-port/570415',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'le_palais',
      name: 'Le Palais',
      weatherUrl: 'https://meteofrance.com/meteo-marine/le-palais/570322',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'le_pouldu',
      name: 'Le Pouldu',
      weatherUrl: 'https://meteofrance.com/meteo-marine/le-pouldu/570352',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'le_pouliguen',
      name: 'Le Pouliguen',
      weatherUrl: 'https://meteofrance.com/meteo-marine/le-pouliguen/570304',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'le_senequet',
      name: 'Le Senequet',
      weatherUrl: 'https://meteofrance.com/meteo-marine/le-senequet/570502',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'le_touquet',
      name: 'Le Touquet',
      weatherUrl: 'https://meteofrance.com/meteo-marine/le-touquet/570553',
      latitude: 50.5219,
      longitude: 1.5889,
    ),

    FishingPort(
      key: 'le_treport',
      name: 'Le Treport',
      weatherUrl: 'https://meteofrance.com/meteo-marine/le-treport/570577',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'les_heaux_de_brehat',
      name: 'Les Heaux De Brehat',
      weatherUrl:
          'https://meteofrance.com/meteo-marine/les-heaux-de-brehat/570472',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'les_sables_d_olonne',
      name: 'Les Sables D Olonne',
      weatherUrl:
          'https://meteofrance.com/meteo-marine/les-sables-d-olonne/570310',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'lesconil',
      name: 'Lesconil',
      weatherUrl: 'https://meteofrance.com/meteo-marine/lesconil/570379',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'lezardrieux',
      name: 'Lezardrieux',
      weatherUrl: 'https://meteofrance.com/meteo-marine/lezardrieux/570460',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'locmariaquer',
      name: 'Locmariaquer',
      weatherUrl: 'https://meteofrance.com/meteo-marine/locmariaquer/570382',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'locquirec',
      name: 'Locquirec',
      weatherUrl: 'https://meteofrance.com/meteo-marine/locquirec/570466',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'loctudy',
      name: 'Loctudy',
      weatherUrl: 'https://meteofrance.com/meteo-marine/loctudy/570430',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'lorient',
      name: 'Lorient',
      weatherUrl: 'https://meteofrance.com/meteo-marine/lorient/570370',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'marseille_vieux_port',
      name: 'Marseille Vieux Port',
      weatherUrl:
          'https://meteofrance.com/meteo-marine/marseille-vieux-port/570184',
      latitude: 43.2951,
      longitude: 5.3748,
    ),

    FishingPort(
      key: 'menton',
      name: 'Menton',
      weatherUrl: 'https://meteofrance.com/meteo-marine/menton/570289',
      latitude: 43.7747,
      longitude: 7.4975,
    ),

    FishingPort(
      key: 'mimizan',
      name: 'Mimizan',
      weatherUrl: 'https://meteofrance.com/meteo-marine/mimizan/570271',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'morgat',
      name: 'Morgat',
      weatherUrl: 'https://meteofrance.com/meteo-marine/morgat/570448',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'nice',
      name: 'Nice',
      weatherUrl: 'https://meteofrance.com/meteo-marine/nice/570241',
      latitude: 43.6959,
      longitude: 7.2861,
    ),

    FishingPort(
      key: 'omonville_la_rogue',
      name: 'Omonville La Rogue',
      weatherUrl:
          'https://meteofrance.com/meteo-marine/omonville-la-rogue/570517',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'ouistreham',
      name: 'Ouistreham',
      weatherUrl: 'https://meteofrance.com/meteo-marine/ouistreham/570538',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'paimpol',
      name: 'Paimpol',
      weatherUrl: 'https://meteofrance.com/meteo-marine/paimpol/570478',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'palavas_les_flots',
      name: 'Palavas Les Flots',
      weatherUrl:
          'https://meteofrance.com/meteo-marine/palavas-les-flots/570277',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'penerf',
      name: 'Penerf',
      weatherUrl: 'https://meteofrance.com/meteo-marine/penerf/570346',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'pointe_d_agon',
      name: 'Pointe D Agon',
      weatherUrl: 'https://meteofrance.com/meteo-marine/pointe-d-agon/570454',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'pointe_de_gatseau',
      name: 'Pointe De Gatseau',
      weatherUrl:
          'https://meteofrance.com/meteo-marine/pointe-de-gatseau/570307',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'pointe_de_grave',
      name: 'Pointe De Grave',
      weatherUrl: 'https://meteofrance.com/meteo-marine/pointe-de-grave/570274',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'pornic',
      name: 'Pornic',
      weatherUrl: 'https://meteofrance.com/meteo-marine/pornic/570319',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'pornichet',
      name: 'Pornichet',
      weatherUrl: 'https://meteofrance.com/meteo-marine/pornichet/570313',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'port_beni',
      name: 'Port Beni',
      weatherUrl: 'https://meteofrance.com/meteo-marine/port-beni/570481',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'port_de_bouc',
      name: 'Port De Bouc',
      weatherUrl: 'https://meteofrance.com/meteo-marine/port-de-bouc/570247',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'port_en_bessin',
      name: 'Port En Bessin',
      weatherUrl: 'https://meteofrance.com/meteo-marine/port-en-bessin/570496',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'port_haliguen',
      name: 'Port Haliguen',
      weatherUrl: 'https://meteofrance.com/meteo-marine/port-haliguen/570364',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'port_la_nouvelle',
      name: 'Port La Nouvelle',
      weatherUrl:
          'https://meteofrance.com/meteo-marine/port-la-nouvelle/570196',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'port_manec_h',
      name: 'Port Manec H',
      weatherUrl: 'https://meteofrance.com/meteo-marine/port-manec-h/570388',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'port_maria',
      name: 'Port Maria',
      weatherUrl: 'https://meteofrance.com/meteo-marine/port-maria/570385',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'port_navalo',
      name: 'Port Navalo',
      weatherUrl: 'https://meteofrance.com/meteo-marine/port-navalo/570391',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'port_saint_louis_du_rhone',
      name: 'Port Saint Louis Du Rhone',
      weatherUrl:
          'https://meteofrance.com/meteo-marine/port-saint-louis-du-rhone/570220',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'port_vendres',
      name: 'Port Vendres',
      weatherUrl: 'https://meteofrance.com/meteo-marine/port-vendres/570223',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'portbail',
      name: 'Portbail',
      weatherUrl: 'https://meteofrance.com/meteo-marine/portbail/570511',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'porto_vecchio',
      name: 'Porto Vecchio',
      weatherUrl: 'https://meteofrance.com/meteo-marine/porto-vecchio/570238',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'portsall',
      name: 'Portsall',
      weatherUrl: 'https://meteofrance.com/meteo-marine/portsall/570451',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'royan',
      name: 'Royan',
      weatherUrl: 'https://meteofrance.com/meteo-marine/royan/570256',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'saint_cast',
      name: 'Saint Cast',
      weatherUrl: 'https://meteofrance.com/meteo-marine/saint-cast/570409',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'saint_denis_d_oleron',
      name: 'Saint Denis D Oleron',
      weatherUrl:
          'https://meteofrance.com/meteo-marine/saint-denis-d-oleron/570334',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'saint_germain_sur_ay',
      name: 'Saint Germain Sur Ay',
      weatherUrl:
          'https://meteofrance.com/meteo-marine/saint-germain-sur-ay/570547',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'saint_gildas',
      name: 'Saint Gildas',
      weatherUrl: 'https://meteofrance.com/meteo-marine/saint-gildas/570355',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'saint_gilles_croix_de_vie',
      name: 'Saint Gilles Croix De Vie',
      weatherUrl:
          'https://meteofrance.com/meteo-marine/saint-gilles-croix-de-vie/570301',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'saint_jean_de_luz',
      name: 'Saint Jean De Luz',
      weatherUrl:
          'https://meteofrance.com/meteo-marine/saint-jean-de-luz/570211',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'saint_martin_de_re',
      name: 'Saint Martin De Re',
      weatherUrl:
          'https://meteofrance.com/meteo-marine/saint-martin-de-re/570316',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'saint_quay_portrieux',
      name: 'Saint Quay Portrieux',
      weatherUrl:
          'https://meteofrance.com/meteo-marine/saint-quay-portrieux/570445',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'saint_tropez',
      name: 'Saint Tropez',
      weatherUrl: 'https://meteofrance.com/meteo-marine/saint-tropez/570190',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'saint_vaast_la_hougue',
      name: 'Saint Vaast La Hougue',
      weatherUrl:
          'https://meteofrance.com/meteo-marine/saint-vaast-la-hougue/570499',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'saint_valery_en_caux',
      name: 'Saint Valery En Caux',
      weatherUrl:
          'https://meteofrance.com/meteo-marine/saint-valery-en-caux/570550',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'sete',
      name: 'Sete',
      weatherUrl: 'https://meteofrance.com/meteo-marine/sete/570202',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'toulon',
      name: 'Toulon',
      weatherUrl: 'https://meteofrance.com/meteo-marine/toulon/570217',
      latitude: 43.1242,
      longitude: 5.928,
    ),

    FishingPort(
      key: 'trebeurden',
      name: 'Trebeurden',
      weatherUrl: 'https://meteofrance.com/meteo-marine/trebeurden/570487',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'treguier',
      name: 'Treguier',
      weatherUrl: 'https://meteofrance.com/meteo-marine/treguier/570469',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'trehiguier',
      name: 'Trehiguier',
      weatherUrl: 'https://meteofrance.com/meteo-marine/trehiguier/570373',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'vannes',
      name: 'Vannes',
      weatherUrl: 'https://meteofrance.com/meteo-marine/vannes/570358',
      latitude: 0.0,
      longitude: 0.0,
    ),

    FishingPort(
      key: 'vieux_boucau',
      name: 'Vieux Boucau',
      weatherUrl: 'https://meteofrance.com/meteo-marine/vieux-boucau/570280',
      latitude: 0.0,
      longitude: 0.0,
    ),
  ];

  /// Obtenir tous les ports français
  List<FishingPort> get allPorts => List.unmodifiable(_frenchPorts);

  /// Obtenir un port par sa clé
  FishingPort? getPortByKey(String key) {
    try {
      return _frenchPorts.firstWhere((port) => port.key == key);
    } catch (e) {
      return null;
    }
  }

  /// Obtenir un port par son nom
  FishingPort? getPortByName(String name) {
    try {
      return _frenchPorts.firstWhere((port) => port.name == name);
    } catch (e) {
      return null;
    }
  }

  /// Filtrer les ports selon une requête de recherche
  /// Les ports commençant par la requête sont affichés en premier
  List<FishingPort> searchPorts(String query) {
    if (query.isEmpty) return allPorts;

    final lowerQuery = query.toLowerCase();
    final startsWith = <FishingPort>[];
    final contains = <FishingPort>[];

    for (final port in _frenchPorts) {
      final lowerName = port.name.toLowerCase();
      if (lowerName.startsWith(lowerQuery)) {
        startsWith.add(port);
      } else if (lowerName.contains(lowerQuery)) {
        contains.add(port);
      }
    }

    return [...startsWith, ...contains];
  }

  /// Obtenir l'URL météo automatique pour un port donné
  String? getAutoWeatherUrl(String portName) {
    final port = getPortByName(portName);
    return port?.weatherUrl;
  }

  /// Obtenir l'URL météo automatique pour une clé de port
  String? getAutoWeatherUrlByKey(String portKey) {
    final port = getPortByKey(portKey);
    return port?.weatherUrl;
  }
}
