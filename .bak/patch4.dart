import 'dart:io';

void main() {
  final path = r'C:\Users\JIM\AppData\Local\Pub\Cache\hosted\pub.dev\objectbox_generator-4.3.1\lib\src\entity_resolver.dart';
  var content = File(path).readAsStringSync();
  
  // Use a regex to find the dartFieldType line
  final pattern = RegExp(
    r'prop\.dartFieldType =\s*\(f\.type as ParameterizedType\)\.typeArguments\[0\]\.toString\(\)\.replaceAll\(RegExp\(r\"\[<>, ]\+\"\), \"\"\)\.trim\(\) \+ \(isNullable\(f\.type\) \? \'\?\' : \'\'\);',
  );
  
  if (pattern.hasMatch(content)) {
    print('Pattern found - replacing');
    content = content.replaceAll(
      pattern,
      '''prop.dartFieldType =
            (f.type is ParameterizedType && (f.type as ParameterizedType).typeArguments.isNotEmpty)
                ? (f.type as ParameterizedType).typeArguments[0].toString().replaceAll(RegExp(r\"[<>, ]+\"), \"\").trim()
                : f.type.toString().replaceAll(RegExp(r\"[<>, ]+\"), \"\").trim() + (isNullable(f.type) ? '?' : '');'''
    );
  } else {
    print('Pattern NOT found');
    // Try simpler match
    if (content.contains('prop.dartFieldType')) {
      final idx = content.indexOf('prop.dartFieldType');
      print(content.substring(idx, idx + 500));
    }
  }
  
  File(path).writeAsStringSync(content);
}
