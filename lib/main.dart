import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:my_spots/app_settings.dart';
import 'package:my_spots/models/waypoint.dart';
import 'package:my_spots/settings_page.dart';
import 'package:my_spots/waypoint_export_screen.dart';
import 'package:my_spots/services/gps_service.dart';
import 'package:my_spots/services/waypoint_sort_service.dart';
import 'package:my_spots/services/alarm_service.dart';
import 'package:my_spots/widgets/satellite_status_dialog.dart';
import 'package:my_spots/widgets/waypoint_accuracy_indicator.dart';
import 'package:my_spots/widgets/satellite_bottom_sheet.dart';
import 'package:my_spots/widgets/navigation_overlay.dart';
import 'package:my_spots/utils/gps_status_utils.dart';
import 'package:my_spots/services/satellite_service.dart';
import 'package:my_spots/services/marine_map_service.dart';
import 'package:my_spots/services/map_tile_cache_service.dart';
import 'package:my_spots/help_page.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.loadSettings();
  await WaypointStore.load();
  await MapTileCacheService.initialise();

  // Initialiser le service des satellites pour synchronisation immédiate
  await SatelliteService.initialize();

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

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String gpsStatus = 'INITIALISATION...';
  Color gpsStatusColor = Colors.orange;
  Timer? _locationTimer;

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _requestLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        gpsStatus = 'GPS DÉSACTIVÉ';
        gpsStatusColor = Colors.red;
      });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          gpsStatus = 'PERMISSION REFUSÉE';
          gpsStatusColor = Colors.red;
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        gpsStatus = 'PERMISSION REFUSÉE';
        gpsStatusColor = Colors.red;
      });
      return;
    }

    _startLocationUpdates();
  }

  void _startLocationUpdates() {
    _locationTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        Position position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );

        setState(() {
          // Utilisation de la logique unifiée du GpsService
          final status = GpsService.getGpsStatus(position.accuracy);
          gpsStatus = GpsService.getGpsStatusText(status);
          gpsStatusColor = GpsService.getGpsStatusColor(status);
        });
      } catch (e) {
        setState(() {
          gpsStatus = 'ERREUR GPS';
          gpsStatusColor = Colors.red;
        });
      }
    });
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

class MapScreen extends StatefulWidget {
  final Waypoint? centerOn;

  const MapScreen({super.key, this.centerOn});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  LatLng? _currentPosition;
  double _currentSpeed = 0.0;
  double _currentHeading = 0.0;
  double _currentZoom = 15.0;
  bool _isLoading = true;
  bool _isFollowingUser = false;
  final TextEditingController _waypointNameController = TextEditingController();
  Waypoint? _selectedWaypoint;
  Waypoint? _navigationTarget; // Waypoint ciblé pour la navigation active
  String gpsStatus = 'INITIALISATION...';
  Color gpsStatusColor = Colors.orange;
  LatLngBounds? _mapVisibleBounds;

  void _onMapCameraChanged() {
    final bounds = _mapController.camera.visibleBounds;
    if (_mapVisibleBounds != null &&
        _mapVisibleBounds!.isOverlapping(bounds) &&
        _boundsNearlyEqual(_mapVisibleBounds!, bounds)) {
      return;
    }
    setState(() => _mapVisibleBounds = bounds);
  }

  bool _boundsNearlyEqual(LatLngBounds a, LatLngBounds b) {
    const epsilon = 0.002;
    return (a.north - b.north).abs() < epsilon &&
        (a.south - b.south).abs() < epsilon &&
        (a.east - b.east).abs() < epsilon &&
        (a.west - b.west).abs() < epsilon;
  }

  void _logMapTileError(TileImage tile, Object error, StackTrace? stackTrace) {
    MapTileErrorLogger.logTileError(tile, error, stackTrace);
  }

  Widget _buildBathymetryOverlayControls() {
    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () async {
                final enabled = !AppSettings.bathymetryOverlayEnabled;
                await AppSettings.saveBathymetryOverlayEnabled(enabled);
                setState(() {});
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Checkbox(
                      value: AppSettings.bathymetryOverlayEnabled,
                      onChanged: (value) async {
                        if (value == null) return;
                        await AppSettings.saveBathymetryOverlayEnabled(value);
                        setState(() {});
                      },
                      activeColor: Colors.blueAccent,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.terrain, color: Colors.white70, size: 16),
                  const SizedBox(width: 4),
                  const Text(
                    'LiDAR / Bathy',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (AppSettings.bathymetryOverlayEnabled) ...[
              const SizedBox(height: 4),
              SizedBox(
                width: 150,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: SliderComponentShape.noOverlay,
                  ),
                  child: Slider(
                    value: AppSettings.bathymetryOverlayOpacity,
                    min: 0,
                    max: 1,
                    divisions: 20,
                    label:
                        '${(AppSettings.bathymetryOverlayOpacity * 100).round()}%',
                    onChanged: (value) async {
                      await AppSettings.saveBathymetryOverlayOpacity(value);
                      setState(() {});
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    // Initialiser le service d'alarme
    AlarmService.initialize();
    AlarmService.setCallbacks(
      onSpeakerIconChanged: (bool show) {
        if (mounted) {
          setState(() {});
        }
      },
    );

    _startLocationTracking();

    if (widget.centerOn != null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _mapController.move(
          LatLng(widget.centerOn!.latitude, widget.centerOn!.longitude),
          16.0,
        );
      });
    }
  }

  @override
  void dispose() {
    GpsService.stopAdaptiveGpsTracking();
    AlarmService.dispose();
    _waypointNameController.dispose();
    super.dispose();
  }

  /// Démarre le suivi GPS en temps réel avec un stream de position
  /// Configure les paramètres selon le mode économie d'énergie
  Future<void> _startLocationTracking() async {
    await GpsService.startAdaptiveGpsTracking(
      onPositionUpdate: (Position position) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
          _currentSpeed = position.speed;
          _currentHeading = position.heading;
          _isLoading = false; // Important : débloquer l'écran de chargement
          // Utilisation de la logique unifiée pour le stream GPS
          final status = GpsService.getGpsStatus(position.accuracy);
          gpsStatus = GpsService.getGpsDetailedStatusText(status);
          gpsStatusColor = GpsService.getGpsStatusColor(status);
        });
        // Mettre à jour la position pour les alarmes
        AlarmService.updatePosition(_currentPosition!);
        // Recentre automatiquement la carte si le suivi est activé
        if (_isFollowingUser && _currentPosition != null) {
          _mapController.move(_currentPosition!, 15.0);
        }
      },
      onError: (String error) {
        setState(() {
          gpsStatus = error;
          gpsStatusColor = Colors.red;
          _isLoading = false;
        });
      },
    );
  }

  void _recenterMap() {
    if (_currentPosition != null) {
      setState(() {
        _isFollowingUser = true;
      });
      _mapController.move(_currentPosition!, 15.0);
    }
  }

  String _formatDistance(double meters) {
    if (AppSettings.distanceUnit == DistanceUnit.nautical) {
      final nm = meters / 1852;
      return '${nm.toStringAsFixed(2)} nm';
    }
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  Future<void> _showAddWaypointDialog() async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Position GPS non disponible'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final frozenPosition = LatLng(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
    );

    final int waypointNumber = WaypointStore.waypoints.length + 1;
    final defaultName = 'WPT $waypointNumber';

    final outcome = await _showWaypointEditorSheet(
      context: context,
      title: 'NOUVEAU WAYPOINT',
      icon: Icons.anchor,
      position: frozenPosition,
      initialName: defaultName,
      initialCategory: WaypointCategory.fishing,
      initialColorHex: 'FFFFEB3B',
      initialDate: DateTime.now(),
      isEditing: false,
    );

    if (outcome?.waypoint == null) return;

    final newWaypoint = outcome!.waypoint!;
    setState(() {
      WaypointStore.waypoints.add(newWaypoint);
      _selectedWaypoint = newWaypoint; // devient la cible active
    });
    await WaypointStore.save();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Waypoint "${newWaypoint.name}" enregistré'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  String _getFormattedSpeed() {
    if (AppSettings.speedUnit == SpeedUnit.knots) {
      double knots = _currentSpeed * 1.94384;
      return knots.toStringAsFixed(1);
    } else {
      double kmh = _currentSpeed * 3.6;
      return kmh.toStringAsFixed(1);
    }
  }

  String _getSpeedUnit() {
    return AppSettings.speedUnit == SpeedUnit.knots ? 'nds' : 'km/h';
  }

  IconData _getWaypointCategoryIcon(Waypoint waypoint) {
    switch (waypoint.category) {
      case WaypointCategory.mushrooms:
        return Icons.park; // Champignons / forêt
      case WaypointCategory.fishing:
        return Icons.anchor; // Ancre pour la pêche
      case WaypointCategory.other:
        // Vérifier si le nom contient "Voiture"
        if (waypoint.name.toLowerCase().contains('voiture')) {
          return Icons.directions_car; // Voiture
        } else {
          return Icons.location_on; // Icône standard de waypoint
        }
    }
  }

  Future<void> _centerOnTargetAndUser() async {
    if (_currentPosition == null || _selectedWaypoint == null) return;
    final bounds = LatLngBounds.fromPoints([
      _currentPosition!,
      LatLng(_selectedWaypoint!.latitude, _selectedWaypoint!.longitude),
    ]);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)),
    );
  }

  String _formatDistanceForWaypoint(double meters, Waypoint waypoint) {
    // Champignons : toujours en mètres / kilomètres, jamais en milles nautiques
    if (waypoint.category == WaypointCategory.mushrooms) {
      if (meters < 1000) {
        return '${meters.round()} m';
      }
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    // Pêche : on respecte le choix de l'utilisateur (m / km ou nm)
    return _formatDistance(meters);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CARTE'),
        backgroundColor: const Color(0xFF0A1929),
        elevation: 0,
        leadingWidth: 100,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white70),
                onPressed: () {
                  Navigator.pop(context);
                },
                tooltip: 'Retour',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => const SatelliteBottomSheet(),
                  );
                },
                child: Icon(
                  gpsStatus == 'GPS OK' ? Icons.gps_fixed : Icons.gps_not_fixed,
                  color: gpsStatusColor,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white70),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
              setState(() {});
              // Si le mode économie d'énergie a changé, on redémarre le suivi GPS
              GpsService.stopAdaptiveGpsTracking();
              _startLocationTracking();
            },
            tooltip: 'Paramètres',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.blue),
                  SizedBox(height: 16),
                  Text(
                    'Chargement de la carte...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter:
                        _currentPosition ?? AppSettings.getDefaultMapCenter(),
                    initialZoom: _currentZoom,
                    minZoom: AppSettings.getMapMinZoom(),
                    maxZoom: AppSettings.getMapMaxZoom(),
                    onPositionChanged: (position, hasGesture) {
                      // Met à jour _currentZoom seulement en cas de changement significatif
                      if ((position.zoom - _currentZoom).abs() > 0.1) {
                        setState(() {
                          _currentZoom = position.zoom;
                        });
                      }
                    },
                    onMapEvent: (event) {
                      if (event is MapEventMove ||
                          event is MapEventRotate ||
                          event is MapEventNonRotatedSizeChange) {
                        _onMapCameraChanged();
                      }
                    },
                    onPointerDown: (event, point) {
                      // Désactiver le suivi automatique quand l'utilisateur déplace la carte manuellement
                      if (_isFollowingUser) {
                        setState(() {
                          _isFollowingUser = false;
                        });
                      }
                    },
                  ),
                  children: [
                    if (AppSettings.mapType == MapType.marine) ...[
                      ...MarineMapService.getActiveMarineTileLayers(
                        _currentZoom,
                      ),
                      if (AppSettings.bathymetryOverlayEnabled)
                        ...MarineMapService.getActiveLidarLayers(
                          _mapVisibleBounds,
                          opacity: AppSettings.bathymetryOverlayOpacity,
                        ),
                    ] else
                      TileLayer(
                        key: ValueKey('basemap_${AppSettings.mapType}'),
                        urlTemplate: AppSettings.getMapTileUrl(),
                        userAgentPackageName: MapTileCacheService.packageName,
                        minZoom: AppSettings.getMapMinZoom(),
                        minNativeZoom: AppSettings.getMapMinNativeZoom(),
                        maxNativeZoom: AppSettings.getMapMaxNativeZoom(),
                        maxZoom: AppSettings.getMapMaxZoom(),
                        tileProvider:
                            MapTileCacheService.getTileProviderForMapType(
                              AppSettings.mapType,
                            ),
                        errorTileCallback: _logMapTileError,
                      ),
                    if (_currentPosition != null && _selectedWaypoint != null)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: [
                              _currentPosition!,
                              LatLng(
                                _selectedWaypoint!.latitude,
                                _selectedWaypoint!.longitude,
                              ),
                            ],
                            color: Colors.white70.withValues(alpha: 0.8),
                            strokeWidth: 2,
                            pattern: const StrokePattern.dotted(
                              spacingFactor: 1.8,
                            ),
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        // Position GPS actuelle (en premier, donc en arrière-plan)
                        if (_currentPosition != null)
                          Marker(
                            point: _currentPosition!,
                            width: 80,
                            height: 80,
                            alignment: Alignment.center,
                            child: Transform.rotate(
                              angle: _currentHeading * (3.14159 / 180),
                              child: const Icon(
                                Icons.navigation,
                                color: Colors.blue,
                                size: 40,
                                shadows: [
                                  Shadow(color: Colors.black, blurRadius: 4),
                                ],
                              ),
                            ),
                          ),
                        // Waypoints de l'utilisateur (en dernier, donc au premier plan)
                        if (AppSettings.waypointsVisible)
                          ...WaypointStore.waypoints
                              .where((waypoint) {
                                if (waypoint.category ==
                                        WaypointCategory.fishing &&
                                    !AppSettings.showFishingWaypointsOnMap) {
                                  return false;
                                }
                                if (waypoint.category ==
                                        WaypointCategory.mushrooms &&
                                    !AppSettings.showMushroomWaypointsOnMap) {
                                  return false;
                                }
                                return true;
                              })
                              .map((waypoint) {
                                final showName =
                                    AppSettings.showWaypointNamesOnMap;
                                final showDate =
                                    AppSettings.showWaypointDateOnMap;
                                final hasLabel = showName || showDate;
                                final fontSize =
                                    AppSettings.waypointLabelFontSize;
                                final dateStr =
                                    '${waypoint.createdAt.day.toString().padLeft(2, '0')}/${waypoint.createdAt.month.toString().padLeft(2, '0')}/${waypoint.createdAt.year}';
                                final iconSize = hasLabel
                                    ? (24 + fontSize).roundToDouble()
                                    : 40.0;
                                final markerWidth = hasLabel
                                    ? (140 + fontSize * 3)
                                    : 80.0;
                                final markerHeight = hasLabel
                                    ? (65 + fontSize * 2.5)
                                    : 80.0;
                                return Marker(
                                  key: ValueKey(
                                    'wp_${waypoint.latitude}_${waypoint.longitude}_${waypoint.createdAt.millisecondsSinceEpoch}',
                                  ),
                                  point: LatLng(
                                    waypoint.latitude,
                                    waypoint.longitude,
                                  ),
                                  width: markerWidth,
                                  height: markerHeight,
                                  alignment: Alignment.center,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      setState(
                                        () => _selectedWaypoint = waypoint,
                                      );
                                    },
                                    child: hasLabel
                                        ? Align(
                                            alignment: Alignment.center,
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 0,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFFFFFDE7,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                    border: Border.all(
                                                      color: Colors.black,
                                                      width: 1,
                                                    ),
                                                  ),
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      if (showName)
                                                        Text(
                                                          waypoint.name,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          textAlign:
                                                              TextAlign.center,
                                                          style: TextStyle(
                                                            color:
                                                                Colors.black87,
                                                            fontSize: fontSize,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      if (showName && showDate)
                                                        const SizedBox(
                                                          height: 2,
                                                        ),
                                                      if (showDate)
                                                        Text(
                                                          dateStr,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          textAlign:
                                                              TextAlign.center,
                                                          style: TextStyle(
                                                            color:
                                                                Colors.black87,
                                                            fontSize:
                                                                fontSize * 0.85,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                                Opacity(
                                                  opacity: 0.65,
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      if (showName)
                                                        Text(
                                                          waypoint.name,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          textAlign:
                                                              TextAlign.center,
                                                          style: TextStyle(
                                                            color:
                                                                Colors.black87,
                                                            fontSize: fontSize,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      const SizedBox(height: 2),
                                                      if (showDate)
                                                        Text(
                                                          dateStr,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          textAlign:
                                                              TextAlign.center,
                                                          style: TextStyle(
                                                            color:
                                                                Colors.black87,
                                                            fontSize:
                                                                fontSize * 0.85,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                      Icon(
                                                        _getWaypointCategoryIcon(
                                                          waypoint,
                                                        ),
                                                        color: waypoint.color,
                                                        size: iconSize,
                                                        shadows: const [
                                                          Shadow(
                                                            color: Colors.black,
                                                            blurRadius: 4,
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        : Opacity(
                                            opacity: 0.65,
                                            child: Align(
                                              alignment: Alignment.center,
                                              child: Icon(
                                                _getWaypointCategoryIcon(
                                                  waypoint,
                                                ),
                                                color: waypoint.color,
                                                size: 40,
                                                shadows: const [
                                                  Shadow(
                                                    color: Colors.black,
                                                    blurRadius: 4,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                  ),
                                );
                              }),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  left: 16,
                  top: 16,
                  child: _buildBathymetryOverlayControls(),
                ),
                Positioned(
                  right: 16,
                  top: 16,
                  child: Column(
                    children: [
                      FloatingActionButton(
                        onPressed: _recenterMap,
                        backgroundColor: const Color(
                          0xFF1E3A5F,
                        ).withValues(alpha: 0.80),
                        heroTag: 'recenter',
                        child: const Icon(
                          Icons.my_location,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FloatingActionButton(
                        onPressed: () async {
                          setState(() {
                            AppSettings.waypointsVisible =
                                !AppSettings.waypointsVisible;
                          });
                          await AppSettings.saveWaypointsVisibility(
                            AppSettings.waypointsVisible,
                          );
                        },
                        backgroundColor: const Color(
                          0xFF1E3A5F,
                        ).withValues(alpha: 0.80),
                        heroTag: 'toggle_waypoints',
                        child: Icon(
                          AppSettings.waypointsVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FloatingActionButton(
                        onPressed: _showAddWaypointDialog,
                        backgroundColor: Colors.green.shade700.withValues(
                          alpha: 0.80,
                        ),
                        heroTag: 'add_waypoint',
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_selectedWaypoint != null)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 95,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFDE7).withValues(alpha: 0.80),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _selectedWaypoint!.color.withValues(
                            alpha: 0.7,
                          ),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Ligne 1 : Nom du waypoint
                          Text(
                            _selectedWaypoint!.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 0),
                          // Ligne 2 : Distance et boutons d'action
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Distance à gauche
                              Text(
                                _currentPosition != null
                                    ? _formatDistanceForWaypoint(
                                        GpsService.calculateDistance(
                                          _currentPosition!,
                                          _selectedWaypoint!,
                                        ),
                                        _selectedWaypoint!,
                                      )
                                    : '—',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueAccent,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              // Boutons d'action à droite
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.center_focus_strong,
                                      color: Colors.black87,
                                      size: 20,
                                    ),
                                    onPressed: _centerOnTargetAndUser,
                                    tooltip: 'Centrer carte',
                                    iconSize: 20,
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      color: Colors.black87,
                                      size: 20,
                                    ),
                                    onPressed: () async {
                                      final outcome =
                                          await _showWaypointEditorSheet(
                                            context: context,
                                            title: 'Modifier le waypoint',
                                            icon: _getWaypointCategoryIcon(
                                              _selectedWaypoint!,
                                            ),
                                            position: LatLng(
                                              _selectedWaypoint!.latitude,
                                              _selectedWaypoint!.longitude,
                                            ),
                                            initialName:
                                                _selectedWaypoint!.name,
                                            initialCategory:
                                                _selectedWaypoint!.category,
                                            initialColorHex:
                                                '#${_selectedWaypoint!.color.toARGB32().toRadixString(16).substring(2)}',
                                            initialDate:
                                                _selectedWaypoint!.createdAt,
                                            isEditing: true,
                                          );
                                      if (outcome != null) {
                                        if (outcome.deleted) {
                                          setState(() {
                                            WaypointStore.waypoints.remove(
                                              _selectedWaypoint,
                                            );
                                            _selectedWaypoint = null;
                                            _navigationTarget = null;
                                          });
                                          await WaypointStore.save();
                                        } else if (outcome.waypoint != null) {
                                          setState(() {
                                            final index = WaypointStore
                                                .waypoints
                                                .indexWhere(
                                                  (wp) =>
                                                      wp == _selectedWaypoint,
                                                );
                                            if (index != -1) {
                                              WaypointStore.waypoints[index] =
                                                  outcome.waypoint!;
                                              _selectedWaypoint =
                                                  outcome.waypoint;
                                              if (_navigationTarget ==
                                                  _selectedWaypoint) {
                                                _navigationTarget =
                                                    outcome.waypoint;
                                              }
                                            }
                                          });
                                          await WaypointStore.save();
                                        }
                                      }
                                    },
                                    tooltip: 'Éditer',
                                    iconSize: 20,
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.navigation,
                                      color: Colors.blue,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _navigationTarget = _selectedWaypoint;
                                      });
                                      // Activer explicitement le monitoring des alarmes pour la navigation
                                      if (_navigationTarget != null) {
                                        AlarmService.startMonitoring(
                                          _navigationTarget!,
                                        );
                                      }
                                    },
                                    tooltip: 'Y aller',
                                    iconSize: 20,
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.black54,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      AlarmService.stopMonitoring();
                                      setState(() {
                                        _selectedWaypoint = null;
                                        _navigationTarget =
                                            null; // Arrêter aussi la navigation
                                      });
                                    },
                                    tooltip: 'Annuler la cible',
                                    iconSize: 20,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: AppSettings.showSpeedOnMap
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black87.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.blueAccent.withValues(alpha: 0.5),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.speed,
                                color: Colors.blueAccent,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '${_getFormattedSpeed()} ${_getSpeedUnit()}',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                // Bandeau de navigation active
                if (_navigationTarget != null)
                  Positioned(
                    left: 16,
                    right: 16,
                    top: 16,
                    child: NavigationOverlay(
                      targetWaypoint: _navigationTarget!,
                      currentPosition: _currentPosition,
                      onStopNavigation: () {
                        setState(() {
                          _navigationTarget = null;
                        });
                        // Arrêter explicitement le monitoring des alarmes
                        AlarmService.stopMonitoring();
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}

class _WaypointEditorOutcome {
  final Waypoint? waypoint;
  final bool deleted;
  const _WaypointEditorOutcome._({
    required this.waypoint,
    required this.deleted,
  });
  const _WaypointEditorOutcome.saved(Waypoint waypoint)
    : this._(waypoint: waypoint, deleted: false);
  const _WaypointEditorOutcome.deleted()
    : this._(waypoint: null, deleted: true);
}

Future<_WaypointEditorOutcome?> _showWaypointEditorSheet({
  required BuildContext context,
  required String title,
  required IconData icon,
  required LatLng position,
  required String initialName,
  required WaypointCategory initialCategory,
  required String initialColorHex,
  required DateTime initialDate,
  required bool isEditing,
}) {
  return showModalBottomSheet<_WaypointEditorOutcome>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return _WaypointEditorSheet(
        title: title,
        icon: icon,
        position: position,
        initialName: initialName,
        initialCategory: initialCategory,
        initialColorHex: initialColorHex,
        initialDate: initialDate,
        isEditing: isEditing,
      );
    },
  );
}

class _WaypointEditorSheet extends StatefulWidget {
  final String title;
  final IconData icon;
  final LatLng position;
  final String initialName;
  final WaypointCategory initialCategory;
  final String initialColorHex;
  final DateTime initialDate;
  final bool isEditing;

  const _WaypointEditorSheet({
    required this.title,
    required this.icon,
    required this.position,
    required this.initialName,
    required this.initialCategory,
    required this.initialColorHex,
    required this.initialDate,
    required this.isEditing,
  });

  @override
  State<_WaypointEditorSheet> createState() => _WaypointEditorSheetState();
}

class _WaypointEditorSheetState extends State<_WaypointEditorSheet> {
  late WaypointCategory _category;
  late String _colorHex;
  late DateTime _createdAt;
  double? _currentAccuracy; // Précision GPS actuelle

  final Map<String, Color> _availableColors = const {
    'FFFFEB3B': Colors.yellow, // Jaune vif
    'FF4CAF50': Colors.green,
    'FF2196F3': Colors.blue,
    'FFFF9800': Colors.orange,
    'FFF44336': Colors.red, // Rouge en dernière position
  };

  static const List<String> _fishingSuggestions = [
    'Bonite',
    'Calamar',
    'Daurade',
    'Loup',
    'Maquereau',
    'Marbré',
    'Pagre',
    'Sar',
    'Seiche',
    'Thon',
  ];

  static const List<String> _mushroomSuggestions = [
    'Cèpes',
    'Chanterelles',
    'Girolles',
    'Morilles',
    'Pied de mouton',
    'Trompettes de la mort',
  ];

  static const List<String> _otherSuggestions = [
    'Voiture',
    'Parking',
    'Entrée',
    'Point de départ',
    'Base',
  ];

  late String _name;

  @override
  void initState() {
    super.initState();
    _name = widget.initialName;
    _category = widget.initialCategory;
    _colorHex = widget.initialColorHex;
    _createdAt = widget.initialDate;
    _updateCurrentAccuracy(); // Initialiser la précision
    // Forcer la couleur rouge pour la catégorie "Autre" avec "Voiture"
    if (_category == WaypointCategory.other &&
        _name.toLowerCase().contains('voiture') &&
        !widget.isEditing) {
      _colorHex = 'FFF44336'; // Rouge
    } else {
      _colorHex = widget.initialColorHex;
    }

    _createdAt = widget.initialDate;
  }

  @override
  void dispose() {
    super.dispose();
  }

  String _formatDateShort(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _createdAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _createdAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _createdAt.hour,
        _createdAt.minute,
        _createdAt.second,
      );
    });
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A2F42),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.redAccent),
            SizedBox(width: 12),
            Text('SUPPRIMER', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'Supprimer ce waypoint ?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Supprimer',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;
    Navigator.of(context).pop(const _WaypointEditorOutcome.deleted());
  }

  void _save() async {
    final name = _name.trim();
    if (name.isEmpty) return;

    // Définir le seuil de sécurité (15 mètres)
    const double safetyThreshold = 15.0;

    try {
      // Obtenir la position actuelle la plus précise possible
      final currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 3),
        ),
      );

      // Rafraîchir la position une dernière fois pour être le plus précis possible
      await _updateCurrentAccuracy();

      // Vérifier la précision GPS pour l'alerte de sécurité
      final accuracy = currentPosition.accuracy;

      if (accuracy > safetyThreshold) {
        // Afficher l'alerte de sécurité
        _showSafetyAccuracyDialog(accuracy, name);
        return;
      }

      // Si la précision est acceptable, enregistrer directement
      _createWaypoint(name);
    } catch (e) {
      // Si impossible d'obtenir la position, continuer avec l'enregistrement
      debugPrint('Impossible d\'obtenir la précision GPS: $e');
      _createWaypoint(name);
    }
  }

  Future<void> _updateCurrentAccuracy() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 2),
        ),
      );
      if (mounted) {
        setState(() {
          _currentAccuracy = position.accuracy;
        });
      }
    } catch (e) {
      // Ignorer les erreurs de précision
      if (mounted) {
        setState(() {
          _currentAccuracy = null;
        });
      }
    }
  }

  void _showSafetyAccuracyDialog(double accuracy, String name) {
    showDialog(
      context: context,
      barrierDismissible: false, // Empêcher la fermeture accidentelle
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange, size: 24),
              SizedBox(width: 8),
              Text('⚠️ Précision faible'),
            ],
          ),
          content: Text(
            'Votre précision actuelle est de ${accuracy.toStringAsFixed(1)}m. Le point risque d\'être mal placé sur la carte.\n\nVoulez-vous quand même créer ce waypoint ?',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Fermer la boîte de dialogue
              },
              child: Text('Annuler', style: TextStyle(color: Colors.grey[600])),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Fermer la boîte de dialogue
                _createWaypoint(name); // Forcer l'enregistrement
              },
              child: Text(
                'Créer quand même',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Obtient la couleur de précision GPS (utilise la logique unifiée)
  Color _getAccuracyColor() {
    return GpsService.getAccuracyColor(_currentAccuracy);
  }

  /// Obtient le texte de précision GPS (utilise la logique unifiée)
  String _getAccuracyText() {
    return GpsService.getAccuracyDetailedText(_currentAccuracy);
  }

  void _createWaypoint(String name) {
    final waypoint = Waypoint(
      name: name,
      latitude: widget.position.latitude,
      longitude: widget.position.longitude,
      createdAt: _createdAt,
      colorHex: _colorHex,
      category: _category,
      creationAccuracy: _currentAccuracy, // Enregistrement de la précision GPS
      gpsStatus: GpsStatusUtils.getGpsStatusLabel(
        _currentAccuracy,
      ), // Enregistrement du statut GPS
    );

    Navigator.of(context).pop(_WaypointEditorOutcome.saved(waypoint));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.88;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              child: Material(
                color: const Color(0xFF1A2F42),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Icon(widget.icon, color: Colors.blueAccent),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              widget.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white12, height: 1),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'NOM',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Autocomplete<String>(
                              optionsBuilder: (TextEditingValue value) {
                                List<String> base;
                                if (_category == WaypointCategory.fishing) {
                                  base = _fishingSuggestions;
                                } else if (_category ==
                                    WaypointCategory.mushrooms) {
                                  base = _mushroomSuggestions;
                                } else {
                                  base = _otherSuggestions;
                                }
                                final query = value.text.trim().toLowerCase();
                                if (query.isEmpty) {
                                  return const Iterable<String>.empty();
                                }
                                return base.where(
                                  (s) => s.toLowerCase().contains(query),
                                );
                              },
                              onSelected: (selection) {
                                setState(() {
                                  _name = selection;
                                  // Si catégorie "Autre" et "Voiture" sélectionné, basculer sur Rouge
                                  if (_category == WaypointCategory.other &&
                                      selection.toLowerCase().contains(
                                        'voiture',
                                      )) {
                                    _colorHex = 'FFF44336'; // Rouge
                                  }
                                });
                              },
                              fieldViewBuilder:
                                  (
                                    BuildContext context,
                                    TextEditingController textController,
                                    FocusNode focusNode,
                                    VoidCallback onFieldSubmitted,
                                  ) {
                                    if (textController.text.isEmpty &&
                                        _name.isNotEmpty) {
                                      textController.text = _name;
                                      textController.selection =
                                          TextSelection.collapsed(
                                            offset: textController.text.length,
                                          );
                                    }

                                    final List<String> base;
                                    if (_category == WaypointCategory.fishing) {
                                      base = _fishingSuggestions;
                                    } else if (_category ==
                                        WaypointCategory.mushrooms) {
                                      base = _mushroomSuggestions;
                                    } else {
                                      base = _otherSuggestions;
                                    }
                                    final quick = base.take(6).toList();

                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: quick
                                              .map(
                                                (label) => ActionChip(
                                                  label: Text(
                                                    label,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  onPressed: () {
                                                    setState(() {
                                                      _name = label;
                                                      // Si catégorie "Autre" et "Voiture" sélectionné, basculer sur Rouge
                                                      if (_category ==
                                                              WaypointCategory
                                                                  .other &&
                                                          label
                                                              .toLowerCase()
                                                              .contains(
                                                                'voiture',
                                                              )) {
                                                        _colorHex =
                                                            'FFF44336'; // Rouge
                                                      }
                                                    });
                                                    textController.text = label;
                                                    textController.selection =
                                                        TextSelection.collapsed(
                                                          offset: label.length,
                                                        );
                                                  },
                                                  materialTapTargetSize:
                                                      MaterialTapTargetSize
                                                          .shrinkWrap,
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                        ),
                                        const SizedBox(height: 8),
                                        // Indicateur de précision GPS
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(
                                              alpha: 0.3,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: Colors.white.withValues(
                                                alpha: 0.1,
                                              ),
                                            ),
                                          ),
                                          child: GestureDetector(
                                            onTap: () {
                                              showDialog(
                                                context: context,
                                                builder: (context) =>
                                                    const SatelliteStatusDialog(),
                                              );
                                            },
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.gps_fixed,
                                                  size: 16,
                                                  color: _getAccuracyColor(),
                                                ),
                                                const SizedBox(width: 12),
                                                Text(
                                                  _getAccuracyText(),
                                                  style: TextStyle(
                                                    color: _getAccuracyColor(),
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Icon(
                                                  Icons.info_outline,
                                                  size: 12,
                                                  color: _getAccuracyColor()
                                                      .withValues(alpha: 0.7),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        TextField(
                                          controller: textController,
                                          focusNode: focusNode,
                                          onChanged: (value) {
                                            setState(() {
                                              _name = value;
                                              // Si catégorie "Autre" et "Voiture" tapé, basculer sur Rouge
                                              if (_category ==
                                                      WaypointCategory.other &&
                                                  value.toLowerCase().contains(
                                                    'voiture',
                                                  )) {
                                                _colorHex = 'FFF44336'; // Rouge
                                              }
                                            });
                                          },
                                          onSubmitted: (_) =>
                                              onFieldSubmitted(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          decoration: InputDecoration(
                                            filled: true,
                                            fillColor: Colors.black26,
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide(
                                                color: Colors.white.withValues(
                                                  alpha: 0.2,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                              optionsViewBuilder:
                                  (
                                    BuildContext context,
                                    AutocompleteOnSelected<String> onSelected,
                                    Iterable<String> options,
                                  ) {
                                    return Align(
                                      alignment: Alignment.topLeft,
                                      child: Material(
                                        color: const Color(0xFF1A2F42),
                                        elevation: 4,
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxHeight: 200,
                                          ),
                                          child: ListView(
                                            shrinkWrap: true,
                                            padding: EdgeInsets.zero,
                                            children: options
                                                .map(
                                                  (opt) => ListTile(
                                                    title: Text(
                                                      opt,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                    onTap: () =>
                                                        onSelected(opt),
                                                  ),
                                                )
                                                .toList(),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'CATÉGORIE',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                ChoiceChip(
                                  label: const Text('Pêche'),
                                  avatar: const Icon(Icons.anchor, size: 18),
                                  selected:
                                      _category == WaypointCategory.fishing,
                                  onSelected: (s) {
                                    if (!s) return;
                                    setState(
                                      () =>
                                          _category = WaypointCategory.fishing,
                                    );
                                  },
                                ),
                                ChoiceChip(
                                  label: const Text('Champignons'),
                                  avatar: const Icon(Icons.grass, size: 18),
                                  selected:
                                      _category == WaypointCategory.mushrooms,
                                  onSelected: (s) {
                                    if (!s) return;
                                    setState(
                                      () => _category =
                                          WaypointCategory.mushrooms,
                                    );
                                  },
                                ),
                                ChoiceChip(
                                  label: const Text('Autre'),
                                  avatar: const Icon(Icons.category, size: 18),
                                  selected: _category == WaypointCategory.other,
                                  onSelected: (s) {
                                    if (!s) return;
                                    setState(
                                      () => _category = WaypointCategory.other,
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'DATE',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: _pickDate,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black26,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_month,
                                      color: Colors.white70,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      _formatDateShort(_createdAt),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const Spacer(),
                                    const Icon(
                                      Icons.chevron_right,
                                      color: Colors.white54,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'COULEUR',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: _availableColors.entries.map((entry) {
                                final isSelected = _colorHex == entry.key;
                                return GestureDetector(
                                  onTap: () =>
                                      setState(() => _colorHex = entry.key),
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: entry.value,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.transparent,
                                        width: 3,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.25,
                                          ),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.black26,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'COORDONNÉES',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Lat: ${widget.position.latitude.toStringAsFixed(6)}°',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  Text(
                                    'Lon: ${widget.position.longitude.toStringAsFixed(6)}°',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Row(
                        children: [
                          if (widget.isEditing)
                            IconButton(
                              onPressed: _confirmDelete,
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.redAccent,
                              ),
                              tooltip: 'Supprimer',
                            ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text(
                              'Annuler',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _save,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade700,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Enregistrer',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class WaypointsScreen extends StatefulWidget {
  const WaypointsScreen({super.key});

  @override
  State<WaypointsScreen> createState() => _WaypointsScreenState();
}

class _WaypointsScreenState extends State<WaypointsScreen> {
  final TextEditingController _editNameController = TextEditingController();
  LatLng? _currentPosition;
  StreamSubscription<Position>? _positionSubscription;

  @override
  void initState() {
    super.initState();
    _startLocationTracking();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _editNameController.dispose();
    super.dispose();
  }

  /// Démarre le suivi GPS pour le tri par distance
  void _startLocationTracking() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });

      _positionSubscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 50, // Rafraîchir tous les 50m
            ),
          ).listen((Position position) {
            setState(() {
              _currentPosition = LatLng(position.latitude, position.longitude);
            });
          });
    } catch (e) {
      // Erreur silencieuse si GPS indisponible
    }
  }

  String _formatDate(DateTime date) {
    return 'Créé le ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  /// Obtient la couleur selon la distance
  Color _getDistanceColor(LatLng? currentPosition, Waypoint waypoint) {
    if (currentPosition == null) return Colors.grey;

    final distance = GpsService.calculateDistance(currentPosition, waypoint);
    if (distance < 100) return Colors.green;
    if (distance < 500) return Colors.amber;
    if (distance < 1000) return Colors.orange;
    return Colors.red;
  }

  /// Rafraîchit manuellement le tri
  void _refreshSort() {
    _startLocationTracking();
    setState(() {});
  }

  Future<void> _editWaypoint(int index) async {
    final waypoint = WaypointStore.waypoints[index];

    final outcome = await _showWaypointEditorSheet(
      context: context,
      title: 'MODIFIER WAYPOINT',
      icon: Icons.edit_location,
      position: LatLng(waypoint.latitude, waypoint.longitude),
      initialName: waypoint.name,
      initialCategory: waypoint.category,
      initialColorHex: waypoint.colorHex,
      initialDate: waypoint.createdAt,
      isEditing: true,
    );

    if (outcome == null) return;

    if (outcome.deleted) {
      setState(() {
        WaypointStore.waypoints.removeAt(index);
      });
      await WaypointStore.save();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Waypoint "${waypoint.name}" supprimé'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    if (outcome.waypoint == null) return;

    setState(() {
      WaypointStore.waypoints[index] = outcome.waypoint!;
    });
    await WaypointStore.save();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Waypoint "${outcome.waypoint!.name}" modifié'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _viewOnMap(Waypoint waypoint) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MapScreen(centerOn: waypoint)),
    );
  }

  Future<void> _deleteWaypoint(Waypoint waypoint) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A2F42),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.redAccent),
            SizedBox(width: 12),
            Text('SUPPRIMER', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          'Supprimer le waypoint "${waypoint.name}" ?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Supprimer',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;

    // Trouver l'index du waypoint et le supprimer
    final index = WaypointStore.waypoints.indexOf(waypoint);
    if (index != -1) {
      setState(() {
        WaypointStore.waypoints.removeAt(index);
      });
      await WaypointStore.save();
    }

    // Afficher un message de confirmation
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Waypoint supprimé'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tri par distance si position disponible, sinon alphabétique
    final sortedWaypoints = WaypointSortService.sortWaypointsByDistance(
      WaypointStore.waypoints,
      _currentPosition,
    );

    final bool hasWaypoints = sortedWaypoints.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text('WAYPOINTS (${sortedWaypoints.length})'),
        backgroundColor: const Color(0xFF0A1929),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _refreshSort,
            tooltip: 'Rafraîchir le tri',
          ),
          IconButton(
            icon: const Icon(Icons.import_export, color: Colors.white70),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const WaypointExportScreen(),
                ),
              );

              // Si des waypoints ont été importés, rafraîchir l'interface
              if (result == true && mounted) {
                setState(() {});
              }
            },
            tooltip: 'Exporter/Importer des waypoints',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A1929), Color(0xFF1A2F42)],
          ),
        ),
        child: hasWaypoints
            ? ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: sortedWaypoints.length,
                itemBuilder: (context, index) {
                  final waypoint = sortedWaypoints[index];
                  final originalIndex = WaypointStore.waypoints.indexOf(
                    waypoint,
                  );

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                    child: ListTile(
                      onTap: () => _editWaypoint(originalIndex),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: waypoint.color,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              waypoint.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          // Indicateur de précision GPS
                          WaypointAccuracyIndicator(
                            waypoint: waypoint,
                            size: 16,
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          // Distance si position disponible
                          if (_currentPosition != null)
                            Text(
                              WaypointSortService.getFormattedDistance(
                                _currentPosition,
                                waypoint,
                              ),
                              style: TextStyle(
                                color: _getDistanceColor(
                                  _currentPosition,
                                  waypoint,
                                ),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          const SizedBox(height: 2),
                          Text(
                            _formatDate(waypoint.createdAt),
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Lat: ${waypoint.latitude.toStringAsFixed(6)}°',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                          Text(
                            'Lon: ${waypoint.longitude.toStringAsFixed(6)}°',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.map,
                              color: Colors.blueAccent,
                              size: 24,
                            ),
                            onPressed: () => _viewOnMap(waypoint),
                            tooltip: 'Voir sur la carte',
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.redAccent,
                              size: 24,
                            ),
                            onPressed: () => _deleteWaypoint(waypoint),
                            tooltip: 'Supprimer le waypoint',
                          ),
                        ],
                      ),
                    ),
                  );
                },
              )
            : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.anchor, size: 120, color: Colors.white30),
                    const SizedBox(height: 24),
                    const Text(
                      'AUCUN WAYPOINT',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Allez sur la CARTE et appuyez sur +',
                      style: TextStyle(fontSize: 16, color: Colors.white38),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
