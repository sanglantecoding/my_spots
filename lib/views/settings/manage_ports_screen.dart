import 'package:flutter/material.dart';
import 'package:my_spots/app_settings.dart';
import 'package:my_spots/models/fishing_port.dart';
import 'package:my_spots/widgets/port_search_field.dart';

class ManagePortsScreen extends StatefulWidget {
  const ManagePortsScreen({super.key});

  @override
  State<ManagePortsScreen> createState() => _ManagePortsScreenState();
}

class _ManagePortsScreenState extends State<ManagePortsScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();

  late List<FishingPort> _ports;

  @override
  void initState() {
    super.initState();
    _ports = List<FishingPort>.from(AppSettings.getEffectiveFavoritePorts());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _savePorts() async {
    await AppSettings.saveFavoritePorts(_ports);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ports enregistrés'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _addPort() {
    final name = _nameController.text.trim();
    final url = _urlController.text.trim();
    if (name.isEmpty || url.isEmpty) return;
    setState(() {
      _ports.add(FishingPort.legacy(name: name, url: url));
    });
    _nameController.clear();
    _urlController.clear();
    _savePorts();
  }

  void _removePort(int index) {
    final removedPort = _ports[index];
    setState(() {
      _ports.removeAt(index);
    });

    // Si le port supprimé était le port sélectionné, réinitialiser
    if (AppSettings.selectedPortKey == removedPort.key) {
      AppSettings.selectedPortKey = null;
      AppSettings.saveSelectedPort(null);
    }

    _savePorts();
  }

  void _editPort(int index) {
    final port = _ports[index];
    _nameController.text = port.name;
    _urlController.text = port.url;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2F42),
        title: const Text(
          'Modifier le port',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PortSearchWidget(
              nameController: _nameController,
              urlController: _urlController,
              labelText: 'Nom du port',
              hintText: 'Rechercher un port...',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'URL météo marine',
                labelStyle: TextStyle(color: Colors.white70),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _nameController.clear();
              _urlController.clear();
              Navigator.of(context).pop();
            },
            child: const Text(
              'Annuler',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final name = _nameController.text.trim();
              final url = _urlController.text.trim();
              if (name.isEmpty || url.isEmpty) return;

              setState(() {
                _ports[index] = FishingPort.legacy(name: name, url: url);
              });

              _nameController.clear();
              _urlController.clear();
              Navigator.of(context).pop();
              _savePorts();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GÉRER MES PORTS'),
        backgroundColor: const Color(0xFF0A1929),
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A1929), Color(0xFF1A2F42)],
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ajouter un port',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  PortSearchWidget(
                    nameController: _nameController,
                    urlController: _urlController,
                    labelText: 'Nom du port',
                    hintText: 'Rechercher un port...',
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _urlController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'URL météo marine',
                      labelStyle: TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: _addPort,
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            Expanded(
              child: _ports.isEmpty
                  ? const Center(
                      child: Text(
                        'Aucun port favori.\nAjoutez-en un ci-dessus.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _ports.length,
                      itemBuilder: (context, index) {
                        final port = _ports[index];
                        return ListTile(
                          leading: const Icon(
                            Icons.anchor,
                            color: Colors.white70,
                          ),
                          title: Text(
                            port.name,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            port.url,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.blueAccent,
                                ),
                                onPressed: () => _editPort(index),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () => _removePort(index),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
