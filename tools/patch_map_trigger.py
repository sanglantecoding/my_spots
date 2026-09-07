from pathlib import Path

p = Path('lib/views/map_screen.dart')
s = p.read_text(encoding='utf-8')

# 1) Rename constructor param: autoStartZoneEdit → triggerZoneCreation
s = s.replace('final bool autoStartZoneEdit;', 'final bool triggerZoneCreation;')
s = s.replace('this.autoStartZoneEdit = false,', 'this.triggerZoneCreation = false,')

# 2) Remove pendingZoneName param
old_p = """  /// When provided together with [autoStartZoneEdit], the zone-name sheet
  /// ([showNewZoneSheet]) is skipped and the rectangle editor opens directly
  /// with this name already filled in.
  final String? pendingZoneName;

  const MapScreen({"""
new_p = """  const MapScreen({"""
assert new_p in s
s = s.replace(old_p, new_p)

# 3) Remove _pendingZoneName state field
old_s = """  /// Zone name already collected from an external entry point
  /// (e.g. [OfflineMapsScreen]). When set, [_openNewOfflineZone] skips the
  /// [showNewZoneSheet] and uses this name directly.
  String? _pendingZoneName;

  /// Configuration (name + layers) collected from NewZoneSheet before
  /// entering _zoneEditMode.
  ZoneConfig? _pendingZoneConfig;"""
new_s = """  /// Configuration (name + layers) collected from NewZoneSheet before
  /// entering _zoneEditMode.
  ZoneConfig? _pendingZoneConfig;"""
assert old_s in s
s = s.replace(old_s, new_s, 1)

# 4) Replace initState block + remove scheduling methods
old_init = """    // Auto-start the zone-creation flow when the screen is opened from
    // OfflineMapsScreen 'Creer une zone' button. We schedule the trigger
    // after a short delay so the map tiles + GPS have a chance to settle.
    if (widget.autoStartZoneEdit) {
      _pendingZoneName = widget.pendingZoneName;
      _scheduleAutoStartZoneEdit();
    }
  }

  /// Polls (with a short timeout) for either a GPS position or for the
  /// FlutterMap camera to become ready, then triggers the same flow as
  /// a long-press on the map. Falls back to [AppSettings.getDefaultMapCenter]
  /// when neither the GPS nor the camera are usable within the window.
  void _scheduleAutoStartZoneEdit() {
    if (_zoneEditStarted) return;
    const timeout = Duration(seconds: 5);
    const tick = Duration(milliseconds: 250);
    final deadline = DateTime.now().add(timeout);
    Future<void>.delayed(tick, () async {
      if (!mounted || _zoneEditStarted) return;
      final cam = _mapController.camera;
      final hasCam = cam.center.latitude.isFinite && cam.center.longitude.isFinite;
      if (_currentPosition != null || hasCam || DateTime.now().isAfter(deadline)) {
        _zoneEditStarted = true;
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (!mounted) return;
        _startZoneEditAuto();
        return;
      }
      _scheduleAutoStartZoneEdit();
    });
  }

  /// Opens the NewZoneSheet and enters zone-adjustment mode centred on the
  /// current GPS position (or default map center as a fallback).
  Future<void> _startZoneEditAuto() async {
    if (_zoneEditMode) return;
    final center = _currentPosition ?? AppSettings.getDefaultMapCenter();
    _mapController.move(center, _currentZoom);
    _openNewOfflineZone(center);
  }

  @override
  void dispose() {"""
new_init = """    // Auto-start: after the first frame, open the name sheet immediately.
    if (widget.triggerZoneCreation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final center = _currentPosition ?? AppSettings.getDefaultMapCenter();
        _openNewOfflineZoneWithCenter(center);
      });
    }
  }

  @override
  void dispose() {"""
assert old_init in s
s = s.replace(old_init, new_init, 1)

# 5) Simplify _openNewOfflineZone
old_open = """  /// Opens the zone-name + layers sheet, then enters zone-adjustment mode
  /// centred on the long-pressed point.
  ///
  /// When [_pendingZoneName] is already set (pre-filled from an external entry
  /// point such as [OfflineMapsScreen]), the sheet is skipped and the editor
  /// opens directly with this name.
  void _openNewOfflineZone(LatLng centerPoint) async {
    ZoneConfig config;

    if (_pendingZoneName != null) {
      // Name already collected externally — skip the sheet.
      config = ZoneConfig(name: _pendingZoneName!, layers: const []);
      _pendingZoneName = null; // consumed
    } else {
      final sheetResult = await showNewZoneSheet(context);
      if (sheetResult == null) return;
      if (!mounted) return;
      config = sheetResult;
    }

    setState(() {
      _zoneEditMode = true;
      _pendingZoneConfig = config;
    });
    _mapController.move(centerPoint, _currentZoom);
  }"""
new_open = """  /// Opens the zone-name sheet, then enters zone-adjustment mode
  /// centred on [centerPoint]. Used both for long-press and for the
  /// [OfflineMapsScreen] entry point.
  void _openNewOfflineZone(LatLng centerPoint) async {
    final config = await showNewZoneSheet(context);
    if (config == null) return;
    if (!mounted) return;

    setState(() {
      _zoneEditMode = true;
      _pendingZoneConfig = config;
    });
    _mapController.move(centerPoint, _currentZoom);
  }

  /// Variant used by the post-frame callback: opens the sheet immediately
  /// with [center] as the initial map position after confirmation.
  void _openNewOfflineZoneWithCenter(LatLng center) {
    _openNewOfflineZone(center);
  }"""
assert old_open in s
s = s.replace(old_open, new_open, 1)

p.write_text(s, encoding='utf-8')

# Verify
for i, line in enumerate(s.splitlines(), 1):
    if any(k in line for k in ['triggerZoneCreation', 'addPostFrameCallback',
                                 '_openNewOfflineZoneWithCenter', 'pendingZoneName',
                                 '_pendingZoneName']):
        print(f"map_screen:{i}: {line.strip()}")
