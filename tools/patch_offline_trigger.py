from pathlib import Path

p = Path('lib/views/offline_maps_screen.dart')
s = p.read_text(encoding='utf-8')

# 1) Remove showNewZoneSheet import
s = s.replace(
    "import 'package:my_spots/views/widgets/offline_maps/new_zone_sheet.dart';\n",
    ""
)

# 2) Replace _showNewZoneSheet
old = """  /// Shows the zone-name sheet first (same UX as long-press on the map),
  /// then navigates to the map with the name already pre-filled so the
  /// rectangle editor opens directly.
  Future<void> _showNewZoneSheet() async {
    final config = await showNewZoneSheet(context);
    if (config == null) return; // cancelled
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MapScreen(
          autoStartZoneEdit: true,
          pendingZoneName: config.name,
        ),
      ),
    );
  }"""
new = """  /// Navigates immediately to the map screen. The map will open the
  /// zone-name sheet right after the first frame renders (via
  /// [MapScreen.triggerZoneCreation]), then enter zone-edit mode on
  /// confirmation.
  void _showNewZoneSheet() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const MapScreen(triggerZoneCreation: true),
      ),
    );
  }"""
assert old in s, f"_showNewZoneSheet not found in:\n{s[s.find('Future<void> _showNewZoneSheet'):s.find('Future<void> _showNewZoneSheet')+400]}"
s = s.replace(old, new, 1)

p.write_text(s, encoding='utf-8')

for i, line in enumerate(s.splitlines(), 1):
    if 'MapScreen' in line or 'triggerZoneCreation' in line:
        print(f"offline:{i}: {line.strip()}")
