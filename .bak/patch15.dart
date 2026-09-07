import 'dart:io';

void main() {
  final path = r'C:\Users\JIM\AppData\Local\Pub\Cache\hosted\pub.dev\objectbox_generator-4.3.1\lib\src\entity_resolver.dart';
  var content = File(path).readAsStringSync();

  // Replace the relTargetName computation
  // For ToOne<SomeEntity> or ToMany<SomeEntity>, extract the entity name from the type string
  // The toString() of ParameterizedType gives "ToOne<SomeEntity>" or "ToMany<SomeEntity>"
  const old = "        // Use element displayName if available, fallback to toString()\r\n"
      "        final typeArg0 = (f.type as ParameterizedType).typeArguments[0];\r\n"
      "        final elem = typeArg0.element;\r\n"
      "        relTargetName = elem != null && elem.displayName != 'InvalidType'\r\n"
      "            ? elem.displayName\r\n"
      "            : typeArg0.toString().replaceAll(RegExp(r'[<>, ]+'), '').trim();";

  const replacement = "        // Extract entity name from ParameterizedType's toString() (e.g., 'ToMany<OfflineMapLayer>'\r\n"
      "        // Use element name if properly resolved, otherwise parse from toString()\r\n"
      "        final ptStr = f.type.toString();\r\n"
      "        // Extract content between '<' and '>' to get the entity name\r\n"
      "        final ltIdx = ptStr.indexOf('<');\r\n"
      "        final gtIdx = ptStr.lastIndexOf('>');\r\n"
      "        relTargetName = (ltIdx >= 0 && gtIdx > ltIdx)\r\n"
      "            ? ptStr.substring(ltIdx + 1, gtIdx).trim()\r\n"
      "            : (f.type as ParameterizedType).typeArguments[0].toString().replaceAll(RegExp(r'[<>, ]+'), '').trim();";

  if (content.contains(old)) {
    content = content.replaceFirst(old, replacement);
    print('Updated relTargetName');
  } else {
    print('Old NOT found');
  }

  File(path).writeAsStringSync(content);
  print('Done');
}
