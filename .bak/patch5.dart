import 'dart:io';

void main() {
  final path = r'C:\Users\JIM\AppData\Local\Pub\Cache\hosted\pub.dev\objectbox_generator-4.3.1\lib\src\entity_resolver.dart';
  var content = File(path).readAsStringSync();

  // Simple string replace of the specific line
  const old = "(f.type as ParameterizedType).typeArguments[0].toString().replaceAll(RegExp(r\"[<>, ]+\"), \"\").trim() + (isNullable(f.type) ? '?' : '')";
  const replacement = "(f.type is ParameterizedType && (f.type as ParameterizedType).typeArguments.isNotEmpty) ? (f.type as ParameterizedType).typeArguments[0].toString().replaceAll(RegExp(r\"[<>, ]+\"), \"\").trim() : f.type.toString().replaceAll(RegExp(r\"[<>, ]+\"), \"\").trim() + (isNullable(f.type) ? '?' : '')";

  if (content.contains(old)) {
    print('Pattern found - replacing');
    content = content.replaceAll(old, replacement);
  } else {
    print('Pattern NOT found');
  }

  File(path).writeAsStringSync(content);
  print('Done');
}
