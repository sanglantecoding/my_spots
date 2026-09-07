import 'dart:io';

void main() {
  final path = r'C:\Users\JIM\AppData\Local\Pub\Cache\hosted\pub.dev\objectbox_generator-4.3.1\lib\src\entity_resolver.dart';
  var content = File(path).readAsStringSync();

  const oldLine = "        relTargetName =\r\n"
      "            (f.type as ParameterizedType).typeArguments[0].toString().replaceAll(RegExp(r'[<>, ]+'), '').trim();";

  const newLine = "        // Use element displayName if available, fallback to toString()\r\n"
      "        final typeArg0 = (f.type as ParameterizedType).typeArguments[0];\r\n"
      "        final elem = typeArg0.element;\r\n"
      "        relTargetName = elem != null && elem.displayName != 'InvalidType'\r\n"
      "            ? elem.displayName\r\n"
      "            : typeArg0.toString().replaceAll(RegExp(r'[<>, ]+'), '').trim();";

  if (content.contains(oldLine)) {
    content = content.replaceFirst(oldLine, newLine);
    print('Patched relTargetName');
  } else {
    print('Old line NOT found');
  }

  File(path).writeAsStringSync(content);
  print('Done');
}
