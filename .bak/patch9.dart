import 'dart:io';

void main() {
  final path = r'C:\Users\JIM\AppData\Local\Pub\Cache\hosted\pub.dev\objectbox_generator-4.3.1\lib\src\entity_resolver.dart';
  var content = File(path).readAsStringSync();

  // Add early return for ToOne/ToMany relation types at the start of detectObjectBoxType
  // Uses CRLF line endings since that's what the file uses
  const target = 'int? detectObjectBoxType(FieldElement2 field, String classDisplayName) {\r\n    final dartType = field.type;\r\n\r\n    if (dartType.isDartCoreInt) {';
  const replacement = 'int? detectObjectBoxType(FieldElement2 field, String classDisplayName) {\r\n    final dartType = field.type;\r\n\r\n    // Skip ToOne/ToMany relations - they have no direct scalar type mapping\r\n    final elementName = dartType.element?.name;\r\n    if (elementName == \'ToOne\' || elementName == \'ToMany\') {\r\n      return null;\r\n    }\r\n\r\n    if (dartType.isDartCoreInt) {';

  if (content.contains(target)) {
    content = content.replaceFirst(target, replacement);
    print('Patched detectObjectBoxType');
  } else {
    print('Target NOT found');
    // Debug: print what's there
    final idx = content.indexOf('detectObjectBoxType');
    if (idx >= 0) {
      print('Around detectObjectBoxType: ${content.substring(idx, idx + 200)}');
    }
  }

  File(path).writeAsStringSync(content);
  print('Done');
}
