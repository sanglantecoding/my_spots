from pathlib import Path

p = Path('lib/views/widgets/offline_maps/new_zone_sheet.dart')
s = p.read_text(encoding='utf-8')

# 1) showNewZoneSheet: remove initialName
old_sig = """Future<ZoneConfig?> showNewZoneSheet(
  BuildContext context, {
  /// When provided, the name field is pre-filled with this value and the
  /// sheet validates immediately on open (bypassing the on-screen keyboard).
  String? initialName,
  NameUniquenessChecker? checkNameExists,
}) {
  return showModalBottomSheet<ZoneConfig>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _NewZoneSheet(
      initialName: initialName,
      checkNameExists: checkNameExists ?? _defaultNameExists,
    ),
  );
}"""
new_sig = """Future<ZoneConfig?> showNewZoneSheet(
  BuildContext context, {
  NameUniquenessChecker? checkNameExists,
}) {
  return showModalBottomSheet<ZoneConfig>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _NewZoneSheet(
      checkNameExists: checkNameExists ?? _defaultNameExists,
    ),
  );
}"""
if old_sig in s:
    s = s.replace(old_sig, new_sig, 1)
    print("removed initialName from showNewZoneSheet")
else:
    print("showNewZoneSheet sig already clean")

# 2) _NewZoneSheet widget: remove initialName
old_w = """  /// Pre-filled zone name (from an external entry point).
  final String? initialName;

  /// Repository-backed name-uniqueness check. Defaults to [_defaultNameExists]
  /// (reads [OfflineMapRepository.instance]).
  final NameUniquenessChecker checkNameExists;

  const _NewZoneSheet({this.initialName, required this.checkNameExists});"""
new_w = """  /// Repository-backed name-uniqueness check. Defaults to [_defaultNameExists]
  /// (reads [OfflineMapRepository.instance]).
  final NameUniquenessChecker checkNameExists;

  const _NewZoneSheet({required this.checkNameExists});"""
if old_w in s:
    s = s.replace(old_w, new_w, 1)
    print("removed initialName from _NewZoneSheet")
else:
    print("_NewZoneSheet already clean")

# 3) initState: remove pre-fill block
old_i = """    // Pre-fill the name field when coming from an external entry point
    // (e.g. OfflineMapsScreen).
    if (widget.initialName != null && widget.initialName!.isNotEmpty) {
      _nameController.text = widget.initialName!;
    }
    // Clear the duplicate warning as soon as the user starts typing again."""
new_i = """    // Clear the duplicate warning as soon as the user starts typing again."""
if old_i in s:
    s = s.replace(old_i, new_i, 1)
    print("removed pre-fill from initState")
else:
    print("initState already clean")

p.write_text(s, encoding='utf-8')
print("DONE")
