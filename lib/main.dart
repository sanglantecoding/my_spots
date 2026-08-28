import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:my_spots/core/app_bootstrap.dart';
import 'package:my_spots/views/home_page.dart';

/// Point d'entrée de l'application.
/// Le fichier .env est chargé AVANT toute initialisation pour que les
/// variables d'environnement (comme THUNDERFOREST_API_KEY) soient disponibles.
///
/// ⚠️ Le fichier .env est git-ignored et ne doit JAMAIS être commité.
/// Voir .env.example pour le template.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Charger les variables d'environnement AVANT l'initialisation de l'app
  await dotenv.load(fileName: '.env');

  await AppBootstrap.initialize();
  runApp(const MySpotsApp());
}

class MySpotsApp extends StatelessWidget {
  const MySpotsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Spots',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A1929),
      ),
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('fr', 'FR')],
      home: const HomePage(),
    );
  }
}
