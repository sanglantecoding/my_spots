import 'dart:io';

void main() {
  final path = r'C:\Users\JIM\AppData\Local\Pub\Cache\hosted\pub.dev\objectbox_generator-4.3.1\lib\src\entity_resolver.dart';
  var content = File(path).readAsStringSync();

  // The detectObjectBoxType function uses (dartType as ParameterizedType) which fails for non-parameterized types like DateTime?
  // Solution: wrap the whole else-if chain that depends on ParameterizedType inside a single 'if (dartType is ParameterizedType)'

  // Add an early type check at the start of the function (after "final dartType = field.type;")
  const startMarker = 'final dartType = field.type;';
  if (content.contains(startMarker)) {
    // Add the early-return logic after the marker
    content = content.replaceFirst(
      startMarker,
      '$startMarker\n    final isParam = dartType is ParameterizedType;',
    );
  }

  File(path).writeAsStringSync(content);
  print('Done');
}
