import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:my_spots/app_settings.dart';
import 'package:my_spots/settings_page.dart';
import 'package:my_spots/services/gps_service.dart';
import 'package:my_spots/widgets/satellite_bottom_sheet.dart';
import 'package:my_spots/controllers/gps_controller.dart';
import 'package:my_spots/help_page.dart';
import 'package:my_spots/views/map_screen.dart';
import 'package:my_spots/views/waypoints_screen.dart';
import 'dart:async';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String gpsStatus = 'INITIALISATION...';
  Color gpsStatusColor = Colors.orange;
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<GpsState>? _stateSubscription;

  @override
  void initState() {
    super.initState();
    _startGpsController();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _stateSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startGpsController() async {
    // Écouter les changements de position
    _positionSubscription = GpsController.instance.positionStream.listen(
      (Position position) {
        if (mounted) {
          setState(() {
            // Utilisation de la logique unifiée du GpsService
            final status = GpsService.getGpsStatus(position.accuracy);
            gpsStatus = GpsService.getGpsStatusText(status);
            gpsStatusColor = GpsService.getGpsStatusColor(status);
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            gpsStatus = 'ERREUR GPS';
            gpsStatusColor = Colors.red;
          });
        }
      },
    );

    // Écouter les changements d'état du GPS
    _stateSubscription = GpsController.instance.stateStream.listen((
      GpsState state,
    ) {
      if (mounted) {
        setState(() {
          switch (state) {
            case GpsState.stopped:
              gpsStatus = 'GPS ARRÊTÉ';
              gpsStatusColor = Colors.grey;
              break;
            case GpsState.initializing:
              gpsStatus = 'INITIALISATION...';
              gpsStatusColor = Colors.orange;
              break;
            case GpsState.stationary:
              gpsStatus = 'GPS ACTIF (IMMOBILE)';
              gpsStatusColor = Colors.green;
              break;
            case GpsState.moving:
              gpsStatus = 'GPS ACTIF (EN MOUVEMENT)';
              gpsStatusColor = Colors.green;
              break;
            case GpsState.error:
              gpsStatus = 'ERREUR GPS';
              gpsStatusColor = Colors.red;
              break;
          }
        });
      }
    });

    // Démarrer le contrôleur GPS
    final success = await GpsController.instance.start();
    if (!success && mounted) {
      setState(() {
        gpsStatus = GpsController.instance.errorMessage ?? 'ERREUR GPS';
        gpsStatusColor = Colors.red;
      });
    }
  }

  Future<void> _openMarineWeather() async {
    final String weatherUrl = AppSettings.getWeatherUrl();

    // Vérifier si l'URL est vide
    if (weatherUrl.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Aucun port sélectionné. Veuillez configurer un port favori dans les paramètres.',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // Vérifier si l'URL est valide
    final Uri? url = Uri.tryParse(weatherUrl);
    if (url == null || !url.hasScheme || !url.hasAuthority) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'URL météo invalide. Veuillez vérifier la configuration du port.',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // Tenter d'ouvrir l'URL
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Impossible d\'ouvrir la météo marine. Vérifiez votre connexion internet.',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A1929), Color(0xFF1A2F42), Color(0xFF0D1B2A)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.all(isLandscape ? 8.0 : 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isLandscape ? 6 : 8,
                          vertical: isLandscape ? 4 : 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: gpsStatusColor.withValues(alpha: 0.5),
                            width: 2,
                          ),
                        ),
                        child: GestureDetector(
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) =>
                                  const SatelliteBottomSheet(),
                            );
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.gps_fixed,
                                color: gpsStatusColor,
                                size: isLandscape ? 14 : 16,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  gpsStatus,
                                  style: TextStyle(
                                    color: gpsStatusColor,
                                    fontSize: isLandscape ? 10 : 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                Icons.info_outline,
                                color: gpsStatusColor.withValues(alpha: 0.7),
                                size: isLandscape ? 10 : 12,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: Text(
                          'My Spots',
                          style: TextStyle(
                            fontSize: isLandscape ? 18 : 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.settings,
                        color: Colors.white70,
                        size: isLandscape ? 24 : 28,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SettingsScreen(),
                          ),
                        ).then((_) => setState(() {}));
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isLandscape ? 16.0 : 32.0,
                      vertical: isLandscape ? 8.0 : 20.0,
                    ),
                    child: isLandscape
                        ? _buildLandscapeLayout(context)
                        : _buildPortraitLayout(context),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(isLandscape ? 8.0 : 16.0),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: _openMarineWeather,
                            icon: const Icon(Icons.waves, color: Colors.white),
                            label: Text(
                              'Météo Marine',
                              style: TextStyle(
                                fontSize: isLandscape ? 14 : 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E3A5F),
                              padding: EdgeInsets.symmetric(
                                horizontal: isLandscape ? 16 : 24,
                                vertical: isLandscape ? 8 : 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: FloatingActionButton.small(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const HelpPage(),
                                ),
                              );
                            },
                            backgroundColor: Colors.grey.shade600,
                            heroTag: 'help',
                            child: const Icon(
                              Icons.help_outline,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isLandscape ? 4 : 8),
                    Text(
                      'Version 1.0.0',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: isLandscape ? 10 : 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPortraitLayout(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildMenuButton(
          context,
          icon: Icons.map,
          label: 'CARTE',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MapScreen()),
            );
          },
        ),
        const SizedBox(height: 16),
        _buildMenuButton(
          context,
          icon: Icons.forest,
          secondIcon: Icons.anchor,
          label: 'WAYPOINTS',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const WaypointsScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLandscapeLayout(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMenuButton(
                context,
                icon: Icons.map,
                label: 'CARTE',
                isCompact: true,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const MapScreen()),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildMenuButton(
          context,
          icon: Icons.forest,
          secondIcon: Icons.anchor,
          label: 'WAYPOINTS',
          isCompact: true,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const WaypointsScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMenuButton(
    BuildContext context, {
    required IconData icon,
    IconData? secondIcon,
    required String label,
    required VoidCallback onTap,
    bool isCompact = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: isCompact ? 12 : 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1E3A5F).withValues(alpha: 0.8),
              const Color(0xFF2C5282).withValues(alpha: 0.6),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: isCompact ? 32 : 40, color: Colors.white),
                if (secondIcon != null) ...[
                  const SizedBox(width: 4),
                  Icon(
                    secondIcon,
                    size: isCompact ? 32 : 40,
                    color: Colors.white,
                  ),
                ],
              ],
            ),
            SizedBox(height: isCompact ? 6 : 10),
            Text(
              label,
              style: TextStyle(
                fontSize: isCompact ? 14 : 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: isCompact ? 1.5 : 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
