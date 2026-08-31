import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:my_spots/core/app_bootstrap.dart';
import 'package:my_spots/core/app_initialization_status.dart';
import 'package:my_spots/views/home_page.dart';

/// Délai maximal d'initialisation avant bascule forcée en mode dégradé.
/// Évite qu'un blocage asynchrone (SharedPreferences corrompu, etc.)
/// ne retarde indéfiniment le lancement de l'UI.
const Duration _bootstrapTimeout = Duration(seconds: 5);

/// Tag utilisé pour les logs développeur.
const String _logName = 'MySpots.main';

/// Point d'entree de l'application.
Future<void> main() async {
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 1) Charger le .env depuis les assets package (et non le filesystem).
    try {
      await dotenv.load(fileName: 'assets/.env');
      developer.log('dotenv loaded', name: _logName);
    } catch (e, st) {
      developer.log(
        'dotenv.load a echoue (non-bloquant)',
        name: _logName,
        error: e,
        stackTrace: st,
      );
    }

    // 2) Initialiser les services applicatifs avec timeout dur.
    //    Si l'un des services critiques bloque au-delà de la fenêtre,
    //    l'UI est lancée quand même en mode dégradé.
    await _initializeWithTimeout();

    // 3) Toujours lancer l'UI, meme en cas d'erreur d'init.
    runApp(const MySpotsApp());
  }, (error, stack) {
    developer.log(
      'Unhandled zone error',
      name: _logName,
      error: error,
      stackTrace: stack,
    );
    debugPrint('Unhandled zone error: $error');
  });
}

/// Lance [AppBootstrap.initialize] sous un timeout dur.
///
/// - Sur succès : l'app démarre normalement.
/// - Sur `TimeoutException` : `AppInitializationStatus.criticalServicesOk`
///   passe à `false`, l'UI est avertie via les flags.
/// - Sur exception métier : même logique, les flags sont déjà positionnés
///   par `AppBootstrap`.
Future<void> _initializeWithTimeout() async {
  try {
    await AppBootstrap.initialize().timeout(_bootstrapTimeout);
    developer.log(
      'AppBootstrap.initialize terminé (degraded=${AppInitializationStatus.isDegraded})',
      name: _logName,
    );
  } on TimeoutException catch (e, st) {
    AppInitializationStatus.criticalServicesOk = false;
    AppInitializationStatus.errors['AppBootstrap.timeout'] = e;
    developer.log(
      'AppBootstrap.initialize a dépassé ${_bootstrapTimeout.inSeconds}s (timeout, mode dégradé forcé)',
      name: _logName,
      error: e,
      stackTrace: st,
    );
  } catch (e, st) {
    // Les flags granulaires sont déjà posés par AppBootstrap.
    developer.log(
      'AppBootstrap.initialize a planté (mode dégradé actif)',
      name: _logName,
      error: e,
      stackTrace: st,
    );
  }
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
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('fr', 'FR')],
      home: const HomePage(),
    );
  }
}
