import 'dart:io';

void main() {
  final path = r'C:\Users\JIM\AppData\Local\Pub\Cache\hosted\pub.dev\objectbox_generator-4.3.1\lib\src\entity_resolver.dart';
  var content = File(path).readAsStringSync();

  // Remove the debug print statement
  const debugLine = "        // DEBUG\r\n"
      "        print('DEBUG [resolver]: f.displayName=\${f.displayName}, ptStr=\$ptStr, ltIdx=\$ltIdx, relTargetName=\$relTargetName');";

  if (content.contains(debugLine)) {
    content = content.replaceFirst(debugLine, '');
    print('Removed debug print');
  } else {
    print('Debug line NOT found');
  }

  File(path).writeAsStringSync(content);
  print('Done');
}
