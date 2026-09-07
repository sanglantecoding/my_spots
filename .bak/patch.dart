import 'dart:io';

void main() {
  final path = r'C:\Users\JIM\AppData\Local\Pub\Cache\hosted\pub.dev\objectbox_generator-4.3.1\lib\src\entity_resolver.dart';
  var content = File(path).readAsStringSync();
  
  // Replace multi-line .typeArguments[0].element!.displayName blocks
  content = content.replaceAllMapped(
    RegExp(r'\(f\.type as ParameterizedType\)\s*\.typeArguments\[0\]\s*\.element!\s*\.displayName'),
    (_) => "(f.type as ParameterizedType).typeArguments[0].toString().replaceAll(RegExp(r'[<>, ]+'), '').trim()"
  );
  
  // Replace entityRealClass.typeValue.element3!.displayName
  content = content.replaceAllMapped(
    RegExp(r'entityRealClass\.typeValue\.element!\.displayName'),
    (_) => "entityRealClass.typeValue.toString().replaceAll(RegExp(r'[<>, ]+'), '').trim()"
  );
  
  // Replace f.type.element3!.displayName
  content = content.replaceAllMapped(
    RegExp(r'f\.type\.element!\.displayName'),
    (_) => "f.type.toString().replaceAll(RegExp(r'[<>, ]+'), '').trim()"
  );
  
  // Replace dartType.element3!.displayName
  content = content.replaceAllMapped(
    RegExp(r'dartType\.element!\.displayName'),
    (_) => "dartType.toString().replaceAll(RegExp(r'[<>, ]+'), '').trim()"
  );
  
  // Replace f.type.element3!.name (nullable)
  content = content.replaceAllMapped(
    RegExp(r'f\.type\.element!\.name'),
    (_) => "f.type.element?.name"
  );
  
  // Replace remaining .element! with .element? for safety
  content = content.replaceAllMapped(
    RegExp(r'\.element!'),
    (_) => '.element?'
  );
  
  File(path).writeAsStringSync(content);
  print('Patches applied successfully');
}
