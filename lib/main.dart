import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:my_spots/core/app_bootstrap.dart';
import 'package:my_spots/core/app_initialization_status.dart';
import 'package:my_spots/views/home_page.dart';

const bool kVerboseMain = false;
const Duration _bootstrapTimeout = Duration(seconds: 5);
const String _logName = 'MySpots.main';

Future<void> main() async {
  runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

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

      await _initializeWithTimeout();
      runApp(const MySpotsApp());
    },
    (error, stack) {
      developer.log(
        'Unhandled zone error',
        name: _logName,
        error: error,
        stackTrace: stack,
      );
      if (kVerboseMain) {
        debugPrint('Unhandled zone error: $error');
      }
    },
  );
}

Future<void> _initializeWithTimeout() async {
  final status = AppInitializationStatus.instance;
  try {
    await AppBootstrap.initialize().timeout(_bootstrapTimeout);
    developer.log(
      'AppBootstrap.initialize terminé (degraded=${status.isDegraded})',
      name: _logName,
    );
  } on TimeoutException catch (e, st) {
    // Le timeout est une failure critique globale
    status.reportCriticalFailure('AppBootstrap.timeout', e);
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
