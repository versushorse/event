import 'dart:io';

void main() {
  for (var f in [File('pubspec.yaml')]) {
    if (f.existsSync()) {
      f.writeAsStringSync(f.readAsStringSync().replaceAll('\r\n', '\n'));
      print('Normalized: ${f.path}');
    }
  }
}
