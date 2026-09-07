import 'dart:io';

void main() {
  final path = r'C:\Users\JIM\AppData\Local\Pub\Cache\hosted\pub.dev\objectbox_generator-4.3.1\lib\src\entity_resolver.dart';
  var content = File(path).readAsStringSync();

  // Wrap the vector type checks in a "dartType is ParameterizedType" guard
  // Use CRLF since the file uses CRLF
  final oldBlock =
      '    } else if ([\r\n'
      '      \'Int8List\',\r\n'
      '      \'Uint8List\',\r\n'
      '    ].contains((dartType as ParameterizedType).typeArguments[0].toString().replaceAll(RegExp(r"[<>, ]+"), "").trim())) {\r\n'
      '      return OBXPropertyType.ByteVector;\r\n'
      '    } else if ([\r\n'
      '      \'Int16List\',\r\n'
      '      \'Uint16List\',\r\n'
      '    ].contains((dartType as ParameterizedType).typeArguments[0].toString().replaceAll(RegExp(r"[<>, ]+"), "").trim())) {\r\n'
      '      return OBXPropertyType.ShortVector;\r\n'
      '    } else if ([\r\n'
      '      \'Int32List\',\r\n'
      '      \'Uint32List\',\r\n'
      '    ].contains((dartType as ParameterizedType).typeArguments[0].toString().replaceAll(RegExp(r"[<>, ]+"), "").trim())) {\r\n'
      '      return OBXPropertyType.IntVector;\r\n'
      '    } else if ([\r\n'
      '      \'Int64List\',\r\n'
      '      \'Uint64List\',\r\n'
      '    ].contains((dartType as ParameterizedType).typeArguments[0].toString().replaceAll(RegExp(r"[<>, ]+"), "").trim())) {\r\n'
      '      return OBXPropertyType.LongVector;\r\n'
      '    } else if ((dartType as ParameterizedType).typeArguments[0].toString().replaceAll(RegExp(r"[<>, ]+"), "").trim() == \'Float32List\') {\r\n'
      '      return OBXPropertyType.FloatVector;\r\n'
      '    } else if ((dartType as ParameterizedType).typeArguments[0].toString().replaceAll(RegExp(r"[<>, ]+"), "").trim() == \'Float64List\') {\r\n'
      '      return OBXPropertyType.DoubleVector;\r\n'
      '    } else if ((dartType as ParameterizedType).typeArguments[0].toString().replaceAll(RegExp(r"[<>, ]+"), "").trim() == \'DateTime\') {\r\n';

  final newBlock =
      '    } else if (dartType is ParameterizedType) {\r\n'
      '      final ta = (dartType as ParameterizedType).typeArguments;\r\n'
      '      if (ta.isNotEmpty) {\r\n'
      '        final ta0 = ta[0].toString().replaceAll(RegExp(r"[<>, ]+"), "").trim();\r\n'
      '        if ([\'Int8List\', \'Uint8List\'].contains(ta0)) {\r\n'
      '          return OBXPropertyType.ByteVector;\r\n'
      '        } else if ([\'Int16List\', \'Uint16List\'].contains(ta0)) {\r\n'
      '          return OBXPropertyType.ShortVector;\r\n'
      '        } else if ([\'Int32List\', \'Uint32List\'].contains(ta0)) {\r\n'
      '          return OBXPropertyType.IntVector;\r\n'
      '        } else if ([\'Int64List\', \'Uint64List\'].contains(ta0)) {\r\n'
      '          return OBXPropertyType.LongVector;\r\n'
      '        } else if (ta0 == \'Float32List\') {\r\n'
      '          return OBXPropertyType.FloatVector;\r\n'
      '        } else if (ta0 == \'Float64List\') {\r\n'
      '          return OBXPropertyType.DoubleVector;\r\n'
      '        } else if (ta0 == \'DateTime\') {\r\n';

  if (content.contains(oldBlock)) {
    content = content.replaceFirst(oldBlock, newBlock);
    print('Block replaced');
  } else {
    print('Block NOT found - showing actual content:');
    final idx = content.indexOf("'Int8List'");
    if (idx > 0) {
      print(content.substring(idx, idx + 200));
    }
  }

  // Need to also close the inner block by adding closing braces
  // The DateTime block continues with a warning - we need to find the right spot
  // For now, let's find the matching closing brace of the function
  // We'll close the new inner block after the DateTime log.warning block
  // The original structure is:
  //   } else if (... == 'DateTime') {
  //     log.warning(...);
  //   } (this is the closing brace for the function body)
  // We need to add 2 more closing braces: one for "if (ta.isNotEmpty)" and one for "if (dartType is ParameterizedType)"

  // Find the next 'return OBXPropertyType.Date;' or end of function
  final dateTimeIdx = content.indexOf('return OBXPropertyType.Date;\r\n');
  if (dateTimeIdx > 0) {
    // Check the position of the return OBXPropertyType.Date
    print('DateTime position: $dateTimeIdx');
    final beforeDate = content.substring(0, dateTimeIdx + 'return OBXPropertyType.Date;\r\n'.length);
    // Find what comes after
    final afterDate = content.substring(dateTimeIdx + 'return OBXPropertyType.Date;\r\n'.length, Math.min(content.length, dateTimeIdx + 500));
    print('After date: ${afterDate.substring(0, Math.min(200, afterDate.length))}');
  }

  File(path).writeAsStringSync(content);
  print('Done');
}

class Math {
  static int min(int a, int b) => a < b ? a : b;
}
