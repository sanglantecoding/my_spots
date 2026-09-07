import 'dart:io';

void main() {
  final path = r'C:\Users\JIM\AppData\Local\Pub\Cache\hosted\pub.dev\objectbox_generator-4.3.1\lib\src\entity_resolver.dart';
  var content = File(path).readAsStringSync();
  
  // Replace the prop.dartFieldType line with a safe version
  content = content.replaceAll(
    "prop.dartFieldType =\n            (f.type as ParameterizedType).typeArguments[0].toString().replaceAll(RegExp(r\"[<>, ]+\"), \"\").trim() + (isNullable(f.type) ? '?' : '');",
    "prop.dartFieldType =\n            (f.type is ParameterizedType && (f.type as ParameterizedType).typeArguments.isNotEmpty)\n                ? (f.type as ParameterizedType).typeArguments[0].toString().replaceAll(RegExp(r\"[<>, ]+\"), \"\").trim()\n                : f.type.toString().replaceAll(RegExp(r\"[<>, ]+\"), \"\").trim() + (isNullable(f.type) ? '?' : '');"
  );
  
  File(path).writeAsStringSync(content);
  print('Fixed line 339');
}
