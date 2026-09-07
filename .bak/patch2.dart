import 'dart:io';

void main() {
  final path = r'C:\Users\JIM\AppData\Local\Pub\Cache\hosted\pub.dev\objectbox_generator-4.3.1\lib\src\entity_resolver.dart';
  var content = File(path).readAsStringSync();
  
  // For dartType.typeArguments[0] -> use (dartType as ParameterizedType).typeArguments[0]
  content = content.replaceAllMapped(
    RegExp(r'dartType\.typeArguments\[0\]'),
    (_) => "(dartType as ParameterizedType).typeArguments[0]"
  );
  
  // For entityRealClass.typeValue.typeArguments[0] -> already a typeValue, may not be ParameterizedType
  content = content.replaceAllMapped(
    RegExp(r'entityRealClass\.typeValue\.typeArguments\[0\]'),
    (_) => "(entityRealClass.typeValue as ParameterizedType).typeArguments[0]"
  );
  
  // For f.type.typeArguments[0] -> need cast
  content = content.replaceAllMapped(
    RegExp(r'f\.type\.typeArguments\[0\]'),
    (_) => "(f.type as ParameterizedType).typeArguments[0]"
  );
  
  File(path).writeAsStringSync(content);
  print('Patches applied');
}
