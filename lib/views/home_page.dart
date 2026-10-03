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
import 'package:my_spots/views/offline_maps_screen.dart';
import 'package:my_spots/repositories/offline_map_repository.dart';
import 'package:my_spots/core/app_initialization_status.dart';
import 'dart:async';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    _startGpsController();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _startGpsController() async {
    await GpsController.instance.start();
  }

  Future<void> _openMarineWeather() async {
    final String weatherUrl = AppSettings.getWeatherUrl();
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
    final Uri? url = Uri.tryParse(weatherUrl);
    if (url == null || !url.hasScheme || !url.hasAuthority) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('URL météo invalide.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible d\'ouvrir la météo marine.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// 🚨 Bannière d'alerte affichée en mode dégradé
  Widget _buildDegradedModeBanner(AppInitializationStatus status) {
    final failedServices = status.errors.keys.join(", ");
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Colors.redAccent.withValues(alpha: 0.15),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Mode dégradé actif ($failedServices)',
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
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
          // 👇 Écoute réactive du statut d'initialisation
          child: ListenableBuilder(
            listenable: AppInitializationStatus.instance,
            builder: (context, _) {
              final initStatus = AppInitializationStatus.instance;

              return Column(
                children: [
                  // Affichage conditionnel de la bannière d'erreur
                  if (initStatus.isDegraded)
                    _buildDegradedModeBanner(initStatus),

                  Padding(
                    padding: EdgeInsets.all(isLandscape ? 8.0 : 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Flexible(child: _GpsStatusBadge()),
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
                                icon: const Icon(
                                  Icons.waves,
                                  color: Colors.white,
                                ),
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
                          'Version 1.1.1',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: isLandscape ? 10 : 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Garde-fou : empêche d'ouvrir la carte en mode hors-ligne si aucune
  /// zone n'a été téléchargée.
  Future<void> _onOpenMap() async {
    // En mode en ligne, on ouvre la carte directement
    if (!AppSettings.offlineModeEnabled) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const MapScreen()),
      );
      return;
    }

    // En mode hors-ligne, on vérifie qu'au moins une zone est disponible
    final repo = OfflineMapRepository.instance;
    final hasZones = repo != null && repo.findReadyOrPartialMaps().isNotEmpty;

    if (hasZones) {
      // Au moins une zone disponible, on peut ouvrir la carte
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const MapScreen()),
      );
      return;
    }

    // Aucune zone disponible : on affiche un popup explicatif
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A2F42),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cloud_off, color: Colors.orangeAccent, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Aucune zone disponible',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        content: const Text(
          'Aucune zone hors-ligne n\'a été téléchargée.\n\n'
          'Pour utiliser la carte hors-ligne, vous devez d\'abord créer '
          'et télécharger une zone en mode en ligne.',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Annuler',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () async {
              // Désactive le mode hors-ligne
              await AppSettings.saveOfflineMode(false);

              if (!mounted || !dialogContext.mounted) return;
              Navigator.pop(dialogContext);

              // Ouvre la carte en mode en ligne
              if (!mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MapScreen()),
              );
            },
            child: const Text(
              'Passer en ligne',
              style: TextStyle(
                color: Colors.greenAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
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
          onTap: _onOpenMap,
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
        const SizedBox(height: 16),
        _buildMenuButton(
          context,
          icon: Icons.map_outlined,
          label: 'ZONES HORS-LIGNE',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const OfflineMapsScreen(),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        const _NetworkModeToggle(),
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
                onTap: _onOpenMap,
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
        const SizedBox(height: 12),
        _buildMenuButton(
          context,
          icon: Icons.map_outlined,
          label: 'ZONES HORS-LIGNE',
          isCompact: true,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const OfflineMapsScreen(),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        const _NetworkModeToggle(),
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

/// Pill-shaped switch sitting on the home page, directly under the
/// "ZONES HORS-LIGNE" button. The value is owned by [_HomePageState]
/// (`_offlineTestMode`) and is pushed into [MapScreen] as its initial
/// value when the user opens the map.
class _NetworkModeToggle extends StatefulWidget {
  const _NetworkModeToggle();

  @override
  State<_NetworkModeToggle> createState() => _NetworkModeToggleState();
}

class _NetworkModeToggleState extends State<_NetworkModeToggle> {
  @override
  Widget build(BuildContext context) {
    //  FIX : écoute le notifier global → le switch se met à jour même si
    // le mode a été changé depuis un autre écran (dialog "Passer en ligne"
    // de la carte), sans dépendre d'un rebuild du parent.
    return ValueListenableBuilder<bool>(
      valueListenable: AppSettings.offlineModeNotifier,
      builder: (context, isOffline, _) {
        return Material(
          color: const Color(0xFF0D1B2A).withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(20),
          child: Tooltip(
            message: isOffline
                ? 'Mode hors-ligne activé'
                : 'Mode en ligne activé',
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () async {
                await AppSettings.saveOfflineMode(!isOffline);
                // Le notifier se charge du rebuild, pas besoin de setState ici.
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isOffline ? Icons.cloud_off : Icons.public,
                      size: 18,
                      color: isOffline ? Colors.redAccent : Colors.greenAccent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isOffline ? 'HORS-LIGNE' : 'EN LIGNE',
                      style: TextStyle(
                        color: isOffline
                            ? Colors.redAccent
                            : Colors.greenAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Switch(
                      value: isOffline,
                      onChanged: (bool value) async {
                        await AppSettings.saveOfflineMode(value);
                        // Le notifier se charge du rebuild.
                      },
                      activeThumbColor: Colors.redAccent,
                      inactiveThumbColor: Colors.green,
                      inactiveTrackColor: Colors.green.withValues(alpha: 0.4),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Widget feuille GPS : s'abonne lui-même aux streams position + state
/// et se rebuild UNIQUEMENT quand le statut change. HomePage ne reçoit
/// plus aucun tick GPS → pas de rebuild de toute la sous-arborescence.
class _GpsStatusBadge extends StatefulWidget {
  const _GpsStatusBadge();

  @override
  State<_GpsStatusBadge> createState() => _GpsStatusBadgeState();
}

class _GpsStatusBadgeState extends State<_GpsStatusBadge> {
  String _status = 'INITIALISATION...';
  Color _color = Colors.orange;
  StreamSubscription<Position>? _positionSub;
  StreamSubscription<GpsState>? _stateSub;

  @override
  void initState() {
    super.initState();
    _startTracking();
  }

  Future<void> _startTracking() async {
    // Abonnement position : précision → statut textuel + couleur
    _positionSub = GpsController.instance.positionStream.listen(
      (Position position) {
        if (!mounted) return;
        final status = GpsService.getGpsStatus(position.accuracy);
        setState(() {
          _status = GpsService.getGpsStatusText(status);
          _color = GpsService.getGpsStatusColor(status);
        });
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _status = 'ERREUR GPS';
          _color = Colors.red;
        });
      },
    );

    // Abonnement état : démarré / arrêté / erreur
    _stateSub = GpsController.instance.stateStream.listen((GpsState state) {
      if (!mounted) return;
      setState(() {
        switch (state) {
          case GpsState.stopped:
            _status = 'GPS ARRÊTÉ';
            _color = Colors.grey;
            break;
          case GpsState.initializing:
            _status = 'INITIALISATION...';
            _color = Colors.orange;
            break;
          case GpsState.stationary:
            _status = 'GPS ACTIF (IMMOBILE)';
            _color = Colors.green;
            break;
          case GpsState.moving:
            _status = 'GPS ACTIF (EN MOUVEMENT)';
            _color = Colors.green;
            break;
          case GpsState.error:
            _status = 'ERREUR GPS';
            _color = Colors.red;
            break;
        }
      });
    });

    // Démarrage du contrôleur GPS (idempotent)
    final success = await GpsController.instance.start();
    if (!success && mounted) {
      setState(() {
        _status = GpsController.instance.errorMessage ?? 'ERREUR GPS';
        _color = Colors.red;
      });
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _stateSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isLandscape ? 6 : 8,
        vertical: isLandscape ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _color.withValues(alpha: 0.5), width: 2),
      ),
      child: GestureDetector(
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => const SatelliteBottomSheet(),
          );
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.gps_fixed, color: _color, size: isLandscape ? 14 : 16),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                _status,
                style: TextStyle(
                  color: _color,
                  fontSize: isLandscape ? 10 : 12,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.info_outline,
              color: _color.withValues(alpha: 0.7),
              size: isLandscape ? 10 : 12,
            ),
          ],
        ),
      ),
    );
  }
}
