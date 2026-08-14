import 'dart:io';

void main() {
  final file = File(r'c:\Users\HP\Desktop\27 may\myridedriverappletest\lib\controllers\auth_controller.dart');
  String content = file.readAsStringSync();
  
  content = content.replaceAll('AnimatedTopToast.show(', 'if (context.mounted) AnimatedTopToast.show(');
  
  file.writeAsStringSync(content);
  print('Replaced AnimatedTopToast.show with if (context.mounted) AnimatedTopToast.show in auth_controller.dart');
}
