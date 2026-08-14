import 'dart:io';

void main() {
  final file = File(r'c:\Users\HP\Desktop\27 may\myridedriverappletest\lib\controllers\auth_controller.dart');
  String content = file.readAsStringSync();
  
  // Regex to match AnimatedTopToast.show(...)
  final RegExp regex = RegExp(r'(\s*)(AnimatedTopToast\.show\([^;]+;\))');
  
  content = content.replaceAllMapped(regex, (match) {
    String indent = match.group(1)!;
    String toastCall = match.group(2)!;
    
    // Check if it's already wrapped (simple check)
    if (toastCall.contains('if (context.mounted)')) {
      return match.group(0)!;
    }
    
    String indentedCall = toastCall.replaceAll('\n', '\n    ');
    return '${indent}if (context.mounted) {\n$indent    $indentedCall\n$indent}';
  });
  
  file.writeAsStringSync(content);
  print('Fixed AnimatedTopToast in auth_controller.dart');
}
