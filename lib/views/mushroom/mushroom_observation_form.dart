import 'package:flutter/material.dart';
import 'package:my_spots/models/mushroom/mushroom_forecast.dart';
import 'package:my_spots/models/mushroom/mushroom_observation.dart';
import 'package:my_spots/models/mushroom/mushroom_species.dart';
import 'package:my_spots/services/mushroom/mushroom_forecast_provider.dart';
import 'package:my_spots/services/mushroom/mushroom_observation_store.dart';

Future<bool?> showMushroomObservationForm(
  BuildContext context, {
  required double latitude,
  required double longitude,
}) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  backgroundColor: const Color(0xFF0A1929),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
  ),
  builder: (_) =>
      MushroomObservationForm(latitude: latitude, longitude: longitude),
);

class MushroomObservationForm extends StatefulWidget {
  const MushroomObservationForm({
    super.key,
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;

  @override
  State<MushroomObservationForm> createState() =>
      _MushroomObservationFormState();
}

class _MushroomObservationFormState extends State<MushroomObservationForm> {
  DateTime _date = DateTime.now();
  MushroomAbundance? _abundance;
  final Set<MushroomMicroHabitat> _microHabitats = {};
  final _countController = TextEditingController();
  final _notesController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _countController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      locale: const Locale('fr'),
    );
    if (selected != null) setState(() => _date = selected);
  }

  Future<void> _save() async {
    if (_abundance == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisissez une abondance observée.')),
      );
      return;
    }
    final count = int.tryParse(_countController.text.trim());
    if (_countController.text.trim().isNotEmpty &&
        (count == null || count < 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saisissez un nombre entier positif.')),
      );
      return;
    }

    setState(() => _saving = true);
    MushroomForecast? forecast;
    try {
      forecast = await MushroomForecastProvider.forecastForObservation(
        latitude: widget.latitude,
        longitude: widget.longitude,
        date: _date,
      );
    } catch (_) {
      // La sortie reste enregistrable même si la prévision est indisponible.
    }

    final observation = MushroomObservation(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      date: _date,
      latitude: widget.latitude,
      longitude: widget.longitude,
      species: MushroomSpecies.boletusEdulis,
      abundance: _abundance!,
      approximateCount: count,
      microHabitats: _microHabitats.toList(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      forecastSnapshot: forecast == null
          ? null
          : MushroomForecastSnapshot.fromForecast(forecast),
    );

    try {
      await MushroomObservationStore.instance.add(observation);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Échec de l’enregistrement : $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        18 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Noter une observation',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Date',
                style: TextStyle(color: Colors.white70),
              ),
              subtitle: Text(
                '${_date.day.toString().padLeft(2, '0')}/'
                '${_date.month.toString().padLeft(2, '0')}/${_date.year}',
                style: const TextStyle(color: Colors.white),
              ),
              trailing: const Icon(Icons.calendar_month, color: Colors.white70),
              onTap: _pickDate,
            ),
            const SizedBox(height: 8),
            const Text('Abondance', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: MushroomAbundance.values
                  .map(
                    (value) => ChoiceChip(
                      label: Text(value.label),
                      selected: _abundance == value,
                      onSelected: (_) => setState(() => _abundance = value),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _countController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Nombre approximatif (facultatif)',
                labelStyle: TextStyle(color: Colors.white60),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Micro-habitats',
              style: TextStyle(color: Colors.white70),
            ),
            Wrap(
              spacing: 6,
              children: MushroomMicroHabitat.values
                  .map(
                    (value) => FilterChip(
                      label: Text(value.label),
                      selected: _microHabitats.contains(value),
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          _microHabitats.add(value);
                        } else {
                          _microHabitats.remove(value);
                        }
                      }),
                    ),
                  )
                  .toList(),
            ),
            TextField(
              controller: _notesController,
              minLines: 2,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Notes (facultatif)',
                labelStyle: TextStyle(color: Colors.white60),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text('Enregistrer'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
