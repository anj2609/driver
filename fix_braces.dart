import 'dart:io';

void main() {
  final file = File(r'c:\Users\HP\Desktop\27 may\myridedriverappletest\lib\controllers\auth_controller.dart');
  String content = file.readAsStringSync();
  
  final regex = RegExp(r'if \(context\.mounted\) AnimatedTopToast\.show\([\s\S]*?\);');
  content = content.replaceAllMapped(regex, (match) {
    String found = match.group(0)!;
    String replaced = found.replaceFirst('if (context.mounted) AnimatedTopToast.show(', 'if (context.mounted) {\n      AnimatedTopToast.show(');
    return replaced + '\n    }';
  });
  
  file.writeAsStringSync(content);
  print('Fixed braces in auth_controller.dart');
}
