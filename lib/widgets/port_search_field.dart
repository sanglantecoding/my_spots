import 'package:flutter/material.dart';
import 'package:my_spots/models/fishing_port.dart';
import 'package:my_spots/services/port_service.dart';

/// Widget réutilisable pour la recherche et sélection de ports avec autocomplete
class PortSearchWidget extends StatefulWidget {
  final TextEditingController nameController;
  final TextEditingController urlController;
  final String? labelText;
  final String? hintText;
  final bool allowManualUrlEdit;
  final VoidCallback? onPortSelected;

  const PortSearchWidget({
    super.key,
    required this.nameController,
    required this.urlController,
    this.labelText,
    this.hintText,
    this.allowManualUrlEdit = true,
    this.onPortSelected,
  });

  @override
  State<PortSearchWidget> createState() => _PortSearchWidgetState();
}

class _PortSearchWidgetState extends State<PortSearchWidget> {
  final PortService _portService = PortService.instance;

  @override
  Widget build(BuildContext context) {
    return Autocomplete<FishingPort>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        return _portService.searchPorts(textEditingValue.text);
      },
      displayStringForOption: (FishingPort option) => option.name,
      onSelected: (FishingPort selection) {
        widget.nameController.text = selection.name;
        widget.urlController.text = selection.weatherUrl;
        widget.onPortSelected?.call();
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: widget.labelText ?? 'Nom du port',
            labelStyle: const TextStyle(color: Colors.white70),
            hintText: widget.hintText ?? 'Rechercher un port...',
            hintStyle: const TextStyle(color: Colors.white54),
            border: const OutlineInputBorder(),
            suffixIcon: const Icon(Icons.search, color: Colors.white70),
          ),
          onSubmitted: (String value) {
            // Si l'utilisateur soumet manuellement, essayer de trouver l'URL
            final autoUrl = _portService.getAutoWeatherUrl(value);
            if (autoUrl != null && widget.urlController.text.isEmpty) {
              widget.urlController.text = autoUrl;
            }
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4.0,
            borderRadius: BorderRadius.circular(8),
            color: const Color(0xFF1A2F42),
            child: SizedBox(
              height: 200.0,
              child: ListView.builder(
                padding: const EdgeInsets.all(8.0),
                itemCount: options.length,
                itemBuilder: (BuildContext context, int index) {
                  final FishingPort option = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.anchor,
                      color: Colors.blueAccent,
                      size: 18,
                    ),
                    title: Text(
                      option.name,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    subtitle: Text(
                      option.weatherUrl,
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      onSelected(option);
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
