import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

class HelpPage extends StatefulWidget {
  const HelpPage({super.key});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  String _markdownContent = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHelpContent();
  }

  Future<void> _loadHelpContent() async {
    try {
      final String content = await rootBundle.loadString('CHANGELOG.md');
      setState(() {
        _markdownContent = content;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _markdownContent = 'Erreur lors du chargement du contenu d\'aide.';
        _isLoading = false;
      });
    }
  }

  Widget _buildMarkdownContent(String text) {
    final lines = text.split('\n');
    final List<Widget> widgets = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Filtrage anti-roadmap : arrêter la lecture si on rencontre des versions futures
      if (line.contains('Roadmap') ||
          line.contains('v1.01') ||
          line.contains('v1.02')) {
        break; // Arrête la lecture du fichier ici pour rester sur la V1
      }

      if (line.startsWith('# ')) {
        // Titre principal
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Text(
              line.substring(2),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        );
      } else if (line.startsWith('## ')) {
        // Sous-titre
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Text(
              line.substring(3),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        );
      } else if (line.startsWith('### ')) {
        // Sous-sous-titre
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              line.substring(4),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        );
      } else if (line.startsWith('#### ')) {
        // Sous-sous-sous-titre
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Text(
              line.substring(5),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        );
      } else if (line.startsWith('- ')) {
        // Liste à puces
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 16.0, bottom: 4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '• ',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                Expanded(
                  child: Text(
                    line.substring(2),
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        );
      } else if (line.startsWith('**') && line.endsWith('**')) {
        // Texte en gras
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Text(
              line.substring(2, line.length - 2),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        );
      } else if (line.startsWith('---')) {
        // Ligne de séparation
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Container(height: 1, color: Colors.white24),
          ),
        );
      } else if (line.trim().isEmpty) {
        // Ligne vide
        widgets.add(const SizedBox(height: 8));
      } else {
        // Texte normal
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Text(
              line,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1929),
      appBar: AppBar(
        title: const Text('Aide & Nouveautés'),
        backgroundColor: const Color(0xFF1A2332),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: _buildMarkdownContent(_markdownContent),
            ),
    );
  }
}
