import 'dart:io';

void main() {
  final path = r'C:\Users\JIM\AppData\Local\Pub\Cache\hosted\pub.dev\objectbox_generator-4.3.1\lib\src\entity_resolver.dart';
  var content = File(path).readAsStringSync();

  // The current code after patch10 - find and replace the DateTime block
  // Need to escape $ signs in the replacement string
  final oldEnd = "        } else if (ta0 == 'DateTime') {\r\n"
      "      log.warning(\r\n"
      "        \"  DateTime property '\${field.displayName}' in entity '\$classDisplayName' is stored and read using millisecond precision. \"\r\n"
      "        'To silence this warning, add an explicit type using @Property(type: PropertyType.date) or @Property(type: PropertyType.dateNano) annotation.',\r\n"
      "      );\r\n"
      "      return OBXPropertyType.Date;\r\n"
      "    } else if (isToOneRelationField(field)) {";

  final newEnd = "        } else if (ta0 == 'DateTime') {\r\n"
      "          log.warning(\r\n"
      "            \"  DateTime property '\${field.displayName}' in entity '\$classDisplayName' is stored and read using millisecond precision. \"\r\n"
      "            'To silence this warning, add an explicit type using @Property(type: PropertyType.date) or @Property(type: PropertyType.dateNano) annotation.',\r\n"
      "          );\r\n"
      "          return OBXPropertyType.Date;\r\n"
      "        }\r\n"
      "      }\r\n"
      "    } else if (isToOneRelationField(field)) {";

  if (content.contains(oldEnd)) {
    content = content.replaceFirst(oldEnd, newEnd);
    print('End block replaced');
  } else {
    print('End block NOT found');
    final idx = content.indexOf("ta0 == 'DateTime'");
    if (idx > 0) {
      print(content.substring(idx, idx + 500));
    }
  }

  File(path).writeAsStringSync(content);
  print('Done');
}
