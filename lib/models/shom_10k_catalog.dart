import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Façade maritime pour filtrer le catalogue 1:10 000.
enum Shom10kFacade {
  mediterraneeCorse('Méditerranée & Corse'),
  atlantiqueSud('Atlantique Sud'),
  bretagneSudPonant('Bretagne Sud & Ponant'),
  bretagneNordManche('Bretagne Nord & Manche');

  const Shom10kFacade(this.label);

  final String label;
}

/// Zone téléchargeable de carte marine SHOM 1:10 000.
class Shom10kRegion {
  const Shom10kRegion({
    required this.id,
    required this.name,
    required this.facade,
    required this.bounds,
    this.shomGridId,
    this.searchTerms = const [],
  });

  final String id;
  final String name;
  final Shom10kFacade facade;
  final LatLngBounds bounds;
  final String? shomGridId;
  final List<String> searchTerms;

  LatLng get center => bounds.center;

  bool matchesQuery(String query) {
    if (query.trim().isEmpty) return true;
    final q = _normalize(query);
    if (_normalize(name).contains(q)) return true;
    if (shomGridId != null && _normalize(shomGridId!).contains(q)) return true;
    for (final term in searchTerms) {
      if (_normalize(term).contains(q)) return true;
    }
    return false;
  }

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('à', 'a')
      .replaceAll('â', 'a')
      .replaceAll('ù', 'u')
      .replaceAll('ô', 'o')
      .replaceAll('î', 'i')
      .replaceAll('ï', 'i')
      .replaceAll('ç', 'c')
      .replaceAll('-', ' ')
      .replaceAll('\'', ' ');
}

/// Catalogue statique des ports et zones côtières françaises (1:10 000).
class Shom10kCatalog {
  Shom10kCatalog._();

  static const List<Shom10kFacade> facades = Shom10kFacade.values;

  static List<Shom10kRegion> get allRegions => _regions;

  static List<Shom10kRegion> regionsForFacade(Shom10kFacade? facade) {
    if (facade == null) return allRegions;
    return allRegions.where((r) => r.facade == facade).toList();
  }

  static Shom10kRegion? byId(String id) {
    for (final region in _regions) {
      if (region.id == id) return region;
    }
    return null;
  }

  static Shom10kRegion _box({
    required String id,
    required String name,
    required Shom10kFacade facade,
    required double lat,
    required double lng,
    double latSpan = 0.10,
    double lngSpan = 0.14,
    List<String> searchTerms = const [],
  }) {
    return Shom10kRegion(
      id: id,
      name: name,
      facade: facade,
      bounds: LatLngBounds(
        LatLng(lat - latSpan / 2, lng - lngSpan / 2),
        LatLng(lat + latSpan / 2, lng + lngSpan / 2),
      ),
      searchTerms: searchTerms,
    );
  }

  static final List<Shom10kRegion> _regions = [
    // ── Méditerranée & Corse ──
    _Shom10kData.sete,
    _Shom10kData.etangDeThau,
    _Shom10kData.frontignan,
    _Shom10kData.capAgde,
    _Shom10kData.grauDuRoi,
    _Shom10kData.portCamargue,
    _Shom10kData.portLaNouvelle,
    _Shom10kData.portVendres,
    _Shom10kData.marseille,
    _Shom10kData.laCiotat,
    _Shom10kData.toulon,
    _Shom10kData.hyeres,
    _Shom10kData.saintTropez,
    _Shom10kData.cannes,
    _Shom10kData.nice,
    _Shom10kData.antibes,
    _Shom10kData.ajaccio,
    _Shom10kData.bastia,
    _Shom10kData.bonifacio,
    _Shom10kData.portoVecchio,
    _Shom10kData.propriano,
    _Shom10kData.calvi,
    _Shom10kData.ileRousse,
    _Shom10kData.saintFlorent,

    // ── Atlantique Sud / Arcachon / Charente ──
    _Shom10kData.baieDeChingoudy,
    _Shom10kData.capbreton,
    _Shom10kData.hossegor,
    _Shom10kData.bassinArcachon,
    _Shom10kData.estuaireGironde,
    _Shom10kData.leVerdon,
    _Shom10kData.laRochelle,
    _Shom10kData.ileDeRe,
    _Shom10kData.ileDOleron,
    _Shom10kData.royan,
    _Shom10kData.bayonne,
    _Shom10kData.saintJeanDeLuz,

    // ── Bretagne Sud & Ponant ──
    _Shom10kData.golfeDuMorbihan,
    _Shom10kData.lorient,
    _Shom10kData.archipelGlenan,
    _Shom10kData.concarneau,
    _Shom10kData.quiberon,
    _Shom10kData.belleIle,
    _Shom10kData.radeDeBrest,
    _Shom10kData.camaret,
    _Shom10kData.audierne,
    _Shom10kData.douarnenez,

    // ── Bretagne Nord & Manche ──
    _Shom10kData.roscoff,
    _Shom10kData.saintMalo,
    _Shom10kData.baieDuMontSaintMichel,
    _Shom10kData.granville,
    _Shom10kData.cherbourg,
    _Shom10kData.leHavre,
    _Shom10kData.honfleur,
    _Shom10kData.dieppe,
    _Shom10kData.boulogneSurMer,
    _Shom10kData.calais,
    _Shom10kData.dunkerque,
    _Shom10kData.paimpol,
    _Shom10kData.saintBrieuc,
    _Shom10kData.carteret,
  ];
}

/// Déclarations des emprises — regroupées pour lisibilité.
abstract final class _Shom10kData {
  static final sete = Shom10kCatalog._box(
    id: 'med_sete',
    name: 'Sète',
    facade: Shom10kFacade.mediterraneeCorse,
    lat: 43.40,
    lng: 3.70,
  );
  static final etangDeThau = Shom10kCatalog._box(
    id: 'med_etang_thau',
    name: 'Étang de Thau',
    facade: Shom10kFacade.mediterraneeCorse,
    lat: 43.42,
    lng: 3.65,
    latSpan: 0.14,
    lngSpan: 0.18,
    searchTerms: ['Thau', 'Bouzigues', 'Mèze'],
  );
  static final frontignan = Shom10kCatalog._box(
    id: 'med_frontignan',
    name: 'Frontignan',
    facade: Shom10kFacade.mediterraneeCorse,
    lat: 43.45,
    lng: 3.75,
  );
  static final capAgde = Shom10kCatalog._box(
    id: 'med_cap_agde',
    name: "Cap d'Agde",
    facade: Shom10kFacade.mediterraneeCorse,
    lat: 43.28,
    lng: 3.52,
  );
  static final grauDuRoi = Shom10kCatalog._box(
    id: 'med_grau_du_roi',
    name: 'Grau-du-Roi',
    facade: Shom10kFacade.mediterraneeCorse,
    lat: 43.54,
    lng: 4.14,
  );
  static final portCamargue = Shom10kCatalog._box(
    id: 'med_port_camargue',
    name: 'Port-Camargue',
    facade: Shom10kFacade.mediterraneeCorse,
    lat: 43.53,
    lng: 4.08,
  );
  static final portLaNouvelle = Shom10kCatalog._box(
    id: 'med_port_la_nouvelle',
    name: 'Port-la-Nouvelle',
    facade: Shom10kFacade.mediterraneeCorse,
    lat: 43.01,
    lng: 3.04,
  );
  static final portVendres = Shom10kCatalog._box(
    id: 'med_port_vendres',
    name: 'Port-Vendres',
    facade: Shom10kFacade.mediterraneeCorse,
    lat: 42.52,
    lng: 3.11,
  );
  static final marseille = Shom10kCatalog._box(
    id: 'med_marseille',
    name: 'Marseille',
    facade: Shom10kFacade.mediterraneeCorse,
    lat: 43.30,
    lng: 5.37,
    latSpan: 0.16,
    lngSpan: 0.22,
  );
  static final laCiotat = Shom10kCatalog._box(
    id: 'med_la_ciotat',
    name: 'La Ciotat',
    facade: Shom10kFacade.mediterraneeCorse,
    lat: 43.17,
    lng: 5.61,
  );
  static final toulon = Shom10kCatalog._box(
    id: 'med_toulon',
    name: 'Toulon',
    facade: Shom10kFacade.mediterraneeCorse,
    lat: 43.12,
    lng: 5.93,
    latSpan: 0.14,
    lngSpan: 0.18,
  );
  static final hyeres = Shom10kCatalog._box(
    id: 'med_hyeres',
    name: 'Hyères',
    facade: Shom10kFacade.mediterraneeCorse,
    lat: 43.08,
    lng: 6.16,
  );
  static final saintTropez = Shom10kCatalog._box(
    id: 'med_saint_tropez',
    name: 'Saint-Tropez',
    facade: Shom10kFacade.mediterraneeCorse,
    lat: 43.27,
    lng: 6.64,
  );
  static final cannes = Shom10kCatalog._box(
    id: 'med_cannes',
    name: 'Cannes',
    facade: Shom10kFacade.mediterraneeCorse,
    lat: 43.55,
    lng: 7.02,
  );
  static final nice = Shom10kCatalog._box(
    id: 'med_nice',
    name: 'Nice',
    facade: Shom10kFacade.mediterraneeCorse,
    lat: 43.70,
    lng: 7.27,
    latSpan: 0.12,
    lngSpan: 0.16,
  );
  static final antibes = Shom10kCatalog._box(
    id: 'med_antibes',
    name: 'Antibes',
    facade: Shom10kFacade.mediterraneeCorse,
    lat: 43.58,
    lng: 7.12,
  );
  static final ajaccio = Shom10kCatalog._box(
    id: 'med_ajaccio',
    name: 'Ajaccio',
    facade: Shom10kFacade.mediterraneeCorse,
    lat: 41.93,
    lng: 8.74,
    latSpan: 0.12,
    lngSpan: 0.16,
  );
  static final bastia = Shom10kCatalog._box(
    id: 'med_bastia',
    name: 'Bastia',
    facade: Shom10kFacade.mediterraneeCorse,
    lat: 42.70,
    lng: 9.45,
  );
  static final bonifacio = Shom10kCatalog._box(
    id: 'med_bonifacio',
    name: 'Bonifacio',
    facade: Shom10kFacade.mediterraneeCorse,
    lat: 41.39,
    lng: 9.16,
    latSpan: 0.12,
    lngSpan: 0.14,
  );
  static final portoVecchio = Shom10kCatalog._box(
    id: 'med_porto_vecchio',
    name: 'Porto-Vecchio',
    facade: Shom10kFacade.mediterraneeCorse,
    lat: 41.59,
    lng: 9.28,
  );
  static final propriano = Shom10kCatalog._box(
    id: 'med_propriano',
    name: 'Propriano',
    facade: Shom10kFacade.mediterraneeCorse,
    lat: 41.68,
    lng: 8.90,
  );
  static final calvi = Shom10kCatalog._box(
    id: 'med_calvi',
    name: 'Calvi',
    facade: Shom10kFacade.mediterraneeCorse,
    lat: 42.57,
    lng: 8.76,
  );
  static final ileRousse = Shom10kCatalog._box(
    id: 'med_ile_rousse',
    name: "L'Île-Rousse",
    facade: Shom10kFacade.mediterraneeCorse,
    lat: 42.63,
    lng: 8.94,
  );
  static final saintFlorent = Shom10kCatalog._box(
    id: 'med_saint_florent',
    name: 'Saint-Florent',
    facade: Shom10kFacade.mediterraneeCorse,
    lat: 42.68,
    lng: 9.30,
  );

  static final baieDeChingoudy = Shom10kCatalog._box(
    id: 'atl_baie_chingoudy',
    name: 'Baie de Chingoudy',
    facade: Shom10kFacade.atlantiqueSud,
    lat: 43.67,
    lng: -1.45,
    searchTerms: ['Chingoudy', 'Hossegor', 'Seignosse'],
  );
  static final capbreton = Shom10kCatalog._box(
    id: 'atl_capbreton',
    name: 'Capbreton',
    facade: Shom10kFacade.atlantiqueSud,
    lat: 43.64,
    lng: -1.43,
  );
  static final hossegor = Shom10kCatalog._box(
    id: 'atl_hossegor',
    name: 'Hossegor',
    facade: Shom10kFacade.atlantiqueSud,
    lat: 43.66,
    lng: -1.40,
  );
  static final bassinArcachon = Shom10kCatalog._box(
    id: 'atl_bassin_arcachon',
    name: "Bassin d'Arcachon",
    facade: Shom10kFacade.atlantiqueSud,
    lat: 44.65,
    lng: -1.15,
    latSpan: 0.20,
    lngSpan: 0.28,
    searchTerms: ['Arcachon', 'Cap Ferret', 'Andernos'],
  );
  static final estuaireGironde = Shom10kCatalog._box(
    id: 'atl_estuaire_gironde',
    name: 'Estuaire de la Gironde',
    facade: Shom10kFacade.atlantiqueSud,
    lat: 45.20,
    lng: -0.75,
    latSpan: 0.22,
    lngSpan: 0.35,
    searchTerms: ['Gironde', 'Bordeaux', 'Pauillac'],
  );
  static final leVerdon = Shom10kCatalog._box(
    id: 'atl_le_verdon',
    name: 'Le Verdon-sur-Mer',
    facade: Shom10kFacade.atlantiqueSud,
    lat: 45.55,
    lng: -1.06,
  );
  static final laRochelle = Shom10kCatalog._box(
    id: 'atl_la_rochelle',
    name: 'La Rochelle',
    facade: Shom10kFacade.atlantiqueSud,
    lat: 46.16,
    lng: -1.15,
    latSpan: 0.12,
    lngSpan: 0.16,
  );
  static final ileDeRe = Shom10kCatalog._box(
    id: 'atl_ile_de_re',
    name: 'Île de Ré',
    facade: Shom10kFacade.atlantiqueSud,
    lat: 46.20,
    lng: -1.40,
    latSpan: 0.14,
    lngSpan: 0.20,
    searchTerms: ['Saint-Martin-de-Ré', 'La Flotte'],
  );
  static final ileDOleron = Shom10kCatalog._box(
    id: 'atl_ile_oleron',
    name: "Île d'Oléron",
    facade: Shom10kFacade.atlantiqueSud,
    lat: 45.87,
    lng: -1.25,
    latSpan: 0.18,
    lngSpan: 0.24,
    searchTerms: ['Saint-Denis', 'Le Château'],
  );
  static final royan = Shom10kCatalog._box(
    id: 'atl_royan',
    name: 'Royan',
    facade: Shom10kFacade.atlantiqueSud,
    lat: 45.62,
    lng: -1.03,
  );
  static final bayonne = Shom10kCatalog._box(
    id: 'atl_bayonne',
    name: 'Bayonne / Anglet',
    facade: Shom10kFacade.atlantiqueSud,
    lat: 43.49,
    lng: -1.47,
  );
  static final saintJeanDeLuz = Shom10kCatalog._box(
    id: 'atl_saint_jean_de_luz',
    name: 'Saint-Jean-de-Luz',
    facade: Shom10kFacade.atlantiqueSud,
    lat: 43.39,
    lng: -1.66,
  );

  static final golfeDuMorbihan = Shom10kCatalog._box(
    id: 'bzh_sud_golfe_morbihan',
    name: 'Golfe du Morbihan',
    facade: Shom10kFacade.bretagneSudPonant,
    lat: 47.58,
    lng: -2.85,
    latSpan: 0.22,
    lngSpan: 0.30,
    searchTerms: ['Vannes', 'Auray', 'Locmariaquer'],
  );
  static final lorient = Shom10kCatalog._box(
    id: 'bzh_sud_lorient',
    name: 'Lorient',
    facade: Shom10kFacade.bretagneSudPonant,
    lat: 47.75,
    lng: -3.37,
    latSpan: 0.12,
    lngSpan: 0.16,
  );
  static final archipelGlenan = Shom10kCatalog._box(
    id: 'bzh_sud_glenan',
    name: 'Archipel des Glénan',
    facade: Shom10kFacade.bretagneSudPonant,
    lat: 47.82,
    lng: -3.90,
    latSpan: 0.10,
    lngSpan: 0.12,
    searchTerms: ['Glénan', 'Glenan'],
  );
  static final concarneau = Shom10kCatalog._box(
    id: 'bzh_sud_concarneau',
    name: 'Concarneau',
    facade: Shom10kFacade.bretagneSudPonant,
    lat: 47.87,
    lng: -3.92,
  );
  static final quiberon = Shom10kCatalog._box(
    id: 'bzh_sud_quiberon',
    name: 'Quiberon',
    facade: Shom10kFacade.bretagneSudPonant,
    lat: 47.55,
    lng: -3.12,
  );
  static final belleIle = Shom10kCatalog._box(
    id: 'bzh_sud_belle_ile',
    name: 'Belle-Île (Le Palais)',
    facade: Shom10kFacade.bretagneSudPonant,
    lat: 47.34,
    lng: -3.20,
    latSpan: 0.16,
    lngSpan: 0.14,
  );
  static final radeDeBrest = Shom10kCatalog._box(
    id: 'bzh_sud_rade_brest',
    name: 'Rade de Brest',
    facade: Shom10kFacade.bretagneSudPonant,
    lat: 48.38,
    lng: -4.49,
    latSpan: 0.18,
    lngSpan: 0.24,
    searchTerms: ['Brest'],
  );
  static final camaret = Shom10kCatalog._box(
    id: 'bzh_sud_camaret',
    name: 'Camaret-sur-Mer',
    facade: Shom10kFacade.bretagneSudPonant,
    lat: 48.27,
    lng: -4.60,
  );
  static final audierne = Shom10kCatalog._box(
    id: 'bzh_sud_audierne',
    name: 'Audierne',
    facade: Shom10kFacade.bretagneSudPonant,
    lat: 48.02,
    lng: -4.54,
  );
  static final douarnenez = Shom10kCatalog._box(
    id: 'bzh_sud_douarnenez',
    name: 'Douarnenez',
    facade: Shom10kFacade.bretagneSudPonant,
    lat: 48.09,
    lng: -4.33,
  );

  static final roscoff = Shom10kCatalog._box(
    id: 'bzh_nord_roscoff',
    name: 'Roscoff',
    facade: Shom10kFacade.bretagneNordManche,
    lat: 48.73,
    lng: -3.99,
  );
  static final saintMalo = Shom10kCatalog._box(
    id: 'bzh_nord_saint_malo',
    name: 'Saint-Malo',
    facade: Shom10kFacade.bretagneNordManche,
    lat: 48.65,
    lng: -2.02,
    latSpan: 0.12,
    lngSpan: 0.16,
  );
  static final baieDuMontSaintMichel = Shom10kCatalog._box(
    id: 'bzh_nord_mont_saint_michel',
    name: 'Baie du Mont-Saint-Michel',
    facade: Shom10kFacade.bretagneNordManche,
    lat: 48.64,
    lng: -1.51,
    latSpan: 0.18,
    lngSpan: 0.22,
    searchTerms: ['Mont-Saint-Michel', 'Cancale'],
  );
  static final granville = Shom10kCatalog._box(
    id: 'bzh_nord_granville',
    name: 'Granville',
    facade: Shom10kFacade.bretagneNordManche,
    lat: 48.84,
    lng: -1.60,
  );
  static final cherbourg = Shom10kCatalog._box(
    id: 'bzh_nord_cherbourg',
    name: 'Cherbourg',
    facade: Shom10kFacade.bretagneNordManche,
    lat: 49.64,
    lng: -1.62,
    latSpan: 0.14,
    lngSpan: 0.18,
  );
  static final leHavre = Shom10kCatalog._box(
    id: 'bzh_nord_le_havre',
    name: 'Le Havre',
    facade: Shom10kFacade.bretagneNordManche,
    lat: 49.49,
    lng: 0.11,
    latSpan: 0.12,
    lngSpan: 0.16,
  );
  static final honfleur = Shom10kCatalog._box(
    id: 'bzh_nord_honfleur',
    name: 'Honfleur',
    facade: Shom10kFacade.bretagneNordManche,
    lat: 49.42,
    lng: 0.23,
  );
  static final dieppe = Shom10kCatalog._box(
    id: 'bzh_nord_dieppe',
    name: 'Dieppe',
    facade: Shom10kFacade.bretagneNordManche,
    lat: 49.92,
    lng: 1.08,
  );
  static final boulogneSurMer = Shom10kCatalog._box(
    id: 'bzh_nord_boulogne',
    name: 'Boulogne-sur-Mer',
    facade: Shom10kFacade.bretagneNordManche,
    lat: 50.73,
    lng: 1.58,
  );
  static final calais = Shom10kCatalog._box(
    id: 'bzh_nord_calais',
    name: 'Calais',
    facade: Shom10kFacade.bretagneNordManche,
    lat: 50.95,
    lng: 1.85,
  );
  static final dunkerque = Shom10kCatalog._box(
    id: 'bzh_nord_dunkerque',
    name: 'Dunkerque',
    facade: Shom10kFacade.bretagneNordManche,
    lat: 51.04,
    lng: 2.37,
    latSpan: 0.12,
    lngSpan: 0.16,
  );
  static final paimpol = Shom10kCatalog._box(
    id: 'bzh_nord_paimpol',
    name: 'Paimpol',
    facade: Shom10kFacade.bretagneNordManche,
    lat: 48.78,
    lng: -3.05,
  );
  static final saintBrieuc = Shom10kCatalog._box(
    id: 'bzh_nord_saint_brieuc',
    name: 'Saint-Brieuc',
    facade: Shom10kFacade.bretagneNordManche,
    lat: 48.65,
    lng: -2.77,
  );
  static final carteret = Shom10kCatalog._box(
    id: 'bzh_nord_carteret',
    name: 'Carteret',
    facade: Shom10kFacade.bretagneNordManche,
    lat: 49.37,
    lng: -1.79,
  );
}
