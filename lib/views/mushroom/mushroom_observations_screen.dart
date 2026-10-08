import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:my_spots/models/mushroom/mushroom_observation.dart';
import 'package:my_spots/services/mushroom/mushroom_observation_store.dart';

class MushroomObservationsScreen extends StatefulWidget {
  const MushroomObservationsScreen({super.key});

  @override
  State<MushroomObservationsScreen> createState() =>
      _MushroomObservationsScreenState();
}

class _MushroomObservationsScreenState
    extends State<MushroomObservationsScreen> {
  final _store = MushroomObservationStore.instance;
  List<MushroomObservation> _observations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final observations = await _store.load();
    observations.sort((a, b) => b.date.compareTo(a.date));
    if (mounted) {
      setState(() {
        _observations = observations;
        _loading = false;
      });
    }
  }

  Future<void> _delete(MushroomObservation observation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cette observation ?'),
        content: const Text('Cette action est définitive.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _store.delete(observation.id);
    await _load();
  }

  Future<void> _export() async {
    final json = await _store.exportJson();
    try {
      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}${Platform.pathSeparator}observations_champignons.json',
      );
      await file.writeAsString(json, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/json')],
          subject: 'Observations champignons My Spots',
        ),
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: json));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('JSON copié dans le presse-papiers.')),
        );
      }
    }
  }

  String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0A1929),
    appBar: AppBar(
      title: const Text('Observations champignons'),
      backgroundColor: const Color(0xFF0A1929),
      actions: [
        IconButton(
          onPressed: _export,
          tooltip: 'Exporter',
          icon: const Icon(Icons.ios_share),
        ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _observations.isEmpty
        ? const Center(
            child: Text(
              'Aucune observation enregistrée.',
              style: TextStyle(color: Colors.white70),
            ),
          )
        : ListView.separated(
            itemCount: _observations.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, color: Colors.white12),
            itemBuilder: (context, index) {
              final observation = _observations[index];
              final forecastIndex = observation.forecastSnapshot?.index;
              return ListTile(
                title: Text(
                  '${_date(observation.date)} · ${observation.abundance.label}',
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  '${observation.latitude.toStringAsFixed(5)}, '
                  '${observation.longitude.toStringAsFixed(5)} · '
                  'Indice : ${forecastIndex == null ? '—' : '$forecastIndex/100'}',
                  style: const TextStyle(color: Colors.white60),
                ),
                trailing: IconButton(
                  tooltip: 'Supprimer',
                  onPressed: () => _delete(observation),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                ),
              );
            },
          ),
  );
}
