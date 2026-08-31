import 'package:flutter/material.dart';
import 'package:my_spots/app_settings.dart';
import 'package:my_spots/models/fishing_port.dart';
import 'package:my_spots/services/port_service.dart';

// Couleurs locales reservees aux indicateurs du selecteur de port meteo.
// Vert : port actuellement actif.
// Jaune/dore : port favori.
// Ces couleurs ne modifient pas le theme global et ne sont utilisees
// que par les icones d'etat de ce widget.
const Color _kActivePortGreen = Color(0xFF2E7D32); // vert material 800
const Color _kFavoriteStarGold = Color(0xFFFFC107); // ambre material 500
const Color _kFavoriteStarOff = Color(0xFF616161); // gris pour etoile non favori

/// Widget de selection du port meteo.
/// Permet de choisir un port francais dans une liste deroulante,
/// de decocher le port actif, et de gerer les favoris (etoile).
class MeteoPortSetting extends StatefulWidget {
  const MeteoPortSetting({super.key});

  @override
  State<MeteoPortSetting> createState() => _MeteoPortSettingState();
}

class _MeteoPortSettingState extends State<MeteoPortSetting> {
  int _version = 0;

  void _rebuild() {
    setState(() {
      _version++;
    });
  }

  Future<void> _openPicker() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (ctx) => _PortPickerSheet(onChanged: _rebuild),
    );
  }

  @override
  Widget build(BuildContext context) {
    // _version est lu pour forcer le rebuild apres modif (favoris, selection).
    // ignore: unused_local_variable
    final v = _version;
    final selected = AppSettings.selectedPortKey == null
        ? null
        : PortService.instance.getPortByKey(AppSettings.selectedPortKey!);
    final label = selected == null
        ? 'Aucun (meteo generale)'
        : selected.name;
    return ListTile(
      leading: const Icon(Icons.wb_cloudy),
      title: const Text('Port meteo'),
      subtitle: Text(label),
      trailing: const Icon(Icons.edit),
      onTap: _openPicker,
    );
  }
}

/// Feuille modale affichant la liste complete des ports.
class _PortPickerSheet extends StatefulWidget {
  const _PortPickerSheet({required this.onChanged});

  final VoidCallback onChanged;

  @override
  State<_PortPickerSheet> createState() => _PortPickerSheetState();
}

class _PortPickerSheetState extends State<_PortPickerSheet> {
  String _query = '';

  Future<void> _toggleSelection(FishingPort port) async {
    final isActive = AppSettings.selectedPortKey == port.key;
    // On await saveSelectedPort pour que AppSettings.selectedPortKey soit
    // deja mis a jour (la mutation se fait apres l'await interne de
    // SharedPreferences) AVANT le setState, sinon le build suivant peut
    // capturer l'ancienne valeur et la liste ne se met pas a jour.
    if (isActive) {
      await AppSettings.saveSelectedPort(null);
    } else {
      await AppSettings.saveSelectedPort(port.key);
    }
    widget.onChanged();
    if (mounted) setState(() {});
  }

  Future<void> _toggleNone() async {
    await AppSettings.saveSelectedPort(null);
    widget.onChanged();
    if (mounted) setState(() {});
  }

  Future<void> _toggleFavorite(FishingPort port) async {
    final favs = AppSettings.favoritePortKeys;
    if (favs.contains(port.key)) {
      await AppSettings.removeFavorite(port.key);
    } else {
      await AppSettings.addFavorite(port.key);
    }
    widget.onChanged();
    setState(() {});
  }

  Future<void> _editPort(FishingPort port) async {
    final nameCtrl = TextEditingController(text: port.name);
    final urlCtrl = TextEditingController(text: port.weatherUrl);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        title: Text(
          'Modifier le port',
          style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'Nom',
                  labelStyle: TextStyle(
                    color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
              TextField(
                controller: urlCtrl,
                style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'URL meteo',
                  labelStyle: TextStyle(
                    color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Annuler',
              style: TextStyle(
                color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Sauvegarder',
              style: TextStyle(color: Theme.of(ctx).colorScheme.primary),
            ),
          ),
        ],
      ),
    );
    if (result == true) {
      PortService.instance.updatePortInfo(
        key: port.key,
        name: nameCtrl.text.trim().isEmpty ? null : nameCtrl.text.trim(),
        weatherUrl:
            urlCtrl.text.trim().isEmpty ? null : urlCtrl.text.trim(),
      );
      widget.onChanged();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final ports = PortService.instance.allPorts;
    final favKeys = AppSettings.favoritePortKeys;
    final selectedKey = AppSettings.selectedPortKey;
    final ordered = PortService.instance.orderByFavoritesFirst(
      ports,
      favKeys,
      selectedPortKey: selectedKey,
    );
    final filtered = _query.isEmpty
        ? ordered
        : ordered.where((p) {
            final q = PortService.instance.normalizeSearchQuery(_query);
            final n = PortService.instance.normalizeSearchQuery(p.name);
            return n.contains(q);
          }).toList();

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'S\u00e9lectionner un port',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Rechercher un port...',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(height: 8),
            // Option explicite "Aucun (meteo generale)" toujours visible en tete.
            _buildNoneRow(),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (ctx, i) {
                  final port = filtered[i];
                  final isActive = AppSettings.selectedPortKey == port.key;
                  final isFav = AppSettings.favoritePortKeys.contains(port.key);
                  return _buildPortRow(port, isActive, isFav);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoneRow() {
    final isActive = AppSettings.selectedPortKey == null;
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: SizedBox(
        width: 40,
        child: Icon(
          Icons.cloud_off,
          color: colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      ),
      title: Text(
        'Aucun (meteo generale)',
        style: TextStyle(color: colorScheme.onSurface),
      ),
      trailing: isActive
          ? const Icon(Icons.check_circle, color: _kActivePortGreen)
          : Icon(
              Icons.radio_button_unchecked,
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
      onTap: _toggleNone,
    );
  }

  Widget _buildPortRow(FishingPort port, bool isActive, bool isFav) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: SizedBox(
        width: 40,
        child: isActive
            ? const Icon(Icons.check_circle, color: _kActivePortGreen)
            : Icon(
                Icons.radio_button_unchecked,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
      ),
      title: Text(
        port.name,
        style: TextStyle(color: colorScheme.onSurface),
      ),
      subtitle: Text(
        port.weatherUrl,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6)),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              isFav ? Icons.star : Icons.star_border,
              color: isFav ? _kFavoriteStarGold : _kFavoriteStarOff,
            ),
            onPressed: () => _toggleFavorite(port),
          ),
          IconButton(
            icon: Icon(
              Icons.edit_outlined,
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            onPressed: () => _editPort(port),
          ),
        ],
      ),
      onTap: () => _toggleSelection(port),
    );
  }
}