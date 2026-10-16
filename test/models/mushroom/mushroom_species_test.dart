import 'package:flutter_test/flutter_test.dart';
import 'package:my_spots/models/mushroom/mushroom_species.dart';

void main() {
  group('MushroomSpecies', () {
    test('code returns correct code for each species', () {
      expect(MushroomSpecies.boletusEdulis.code, 'boletus_edulis');
      expect(MushroomSpecies.chanterelle.code, 'chanterelle');
      expect(MushroomSpecies.blackTrumpet.code, 'black_trumpet');
      expect(MushroomSpecies.other.code, 'other');
    });

    test('mushroomSpeciesFromCode returns correct species', () {
      expect(
        mushroomSpeciesFromCode('boletus_edulis'),
        MushroomSpecies.boletusEdulis,
      );
      expect(
        mushroomSpeciesFromCode('chanterelle'),
        MushroomSpecies.chanterelle,
      );
      expect(
        mushroomSpeciesFromCode('black_trumpet'),
        MushroomSpecies.blackTrumpet,
      );
      expect(mushroomSpeciesFromCode('other'), MushroomSpecies.other);
    });

    test('mushroomSpeciesFromCode returns other for unknown code', () {
      expect(mushroomSpeciesFromCode('unknown'), MushroomSpecies.other);
    });
  });
}
