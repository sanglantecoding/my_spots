import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:my_spots/models/mushroom/mushroom_observation.dart';

/// Stockage JSON des observations, séparé du schéma ObjectBox.
class MushroomObservationStore {
  MushroomObservationStore({File? file}) : _fileOverride = file;

  static final MushroomObservationStore instance = MushroomObservationStore();

  final File? _fileOverride;
  Future<File>? _resolvedFile;
  Future<void>? _operationQueue;
  bool _loadFailed = false;

  Future<File> get file async => _resolvedFile ??= _resolveFile();

  Future<File> _resolveFile() async {
    if (_fileOverride != null) return _fileOverride;
    final directory = await getApplicationDocumentsDirectory();
    return File(
      '${directory.path}${Platform.pathSeparator}mushroom_observations.json',
    );
  }

  Future<List<MushroomObservation>> load() async {
    try {
      final target = await file;
      if (!await target.exists()) {
        // Si le fichier principal manque, tente de restaurer depuis .bak
        final backup = File('${target.path}.bak');
        if (await backup.exists()) {
          await backup.rename(target.path);
        } else {
          return [];
        }
      }
      final decoded = jsonDecode(await target.readAsString());
      if (decoded is! List) {
        throw FormatException('Expected a List, got ${decoded.runtimeType}');
      }
      final observations = <MushroomObservation>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        try {
          observations.add(
            MushroomObservation.fromJson(Map<String, dynamic>.from(item)),
          );
        } catch (_) {
          // Une ligne illisible ne doit pas empêcher l'accès aux autres.
        }
      }
      _loadFailed = false;
      return observations;
    } catch (e) {
      // Fichier illisible : renommer avec horodatage et lever exception
      _loadFailed = true;
      final target = await file;
      if (await target.exists()) {
        final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
        final corruptFile = File('${target.path}.corrupt-$timestamp.json');
        await target.rename(corruptFile.path);
      }
      throw Exception('Failed to load mushroom observations: $e');
    }
  }

  Future<void> save(List<MushroomObservation> observations) async {
    final target = await file;
    await target.parent.create(recursive: true);
    final temporary = File('${target.path}.tmp');
    final backup = File('${target.path}.bak');
    await temporary.writeAsString(
      const JsonEncoder.withIndent('  ').convert(
        observations.map((observation) => observation.toJson()).toList(),
      ),
      flush: true,
    );

    if (!await target.exists()) {
      await temporary.rename(target.path);
      return;
    }

    if (await backup.exists()) await backup.delete();
    await target.rename(backup.path);
    try {
      await temporary.rename(target.path);
      await backup.delete();
    } catch (_) {
      if (!await target.exists() && await backup.exists()) {
        await backup.rename(target.path);
      }
      rethrow;
    }
  }

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final run = (_operationQueue ?? Future<void>.value())
        .catchError((_) {})
        .then((_) => action());
    _operationQueue = run.then<void>((_) {}, onError: (_) {});
    return run;
  }

  Future<void> add(MushroomObservation observation) => _enqueue(() async {
    if (_loadFailed) {
      throw StateError('Cannot add observation after failed load');
    }
    final observations = await load();
    observations.add(observation);
    await save(observations);
  });

  Future<void> delete(String id) => _enqueue(() async {
    if (_loadFailed) {
      throw StateError('Cannot delete observation after failed load');
    }
    final observations = await load();
    observations.removeWhere((observation) => observation.id == id);
    await save(observations);
  });

  Future<String> exportJson() async {
    final observations = await load();
    final json = const JsonEncoder.withIndent(
      '  ',
    ).convert(observations.map((observation) => observation.toJson()).toList());

    // Supprime le fichier d'export temporaire après le partage
    final target = await file;
    final exportFile = File('${target.path}.export.tmp');
    if (await exportFile.exists()) {
      await exportFile.delete();
    }

    return json;
  }
}
