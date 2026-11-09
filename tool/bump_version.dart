import 'dart:io';

void main() {
  final file = File('pubspec.yaml');
  if (!file.existsSync()) return;
  var content = file.readAsStringSync();
  final reg = RegExp(r'version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)');
  final match = reg.firstMatch(content);
  if (match != null) {
    final ver = match.group(1);
    final build = int.parse(match.group(2)!) + 1;
    content = content.replaceFirst(reg, 'version: $ver+$build');
    file.writeAsStringSync(content);
    print('>>> [Version] Auto-incremented to: $ver (build $build)');
  }
}
