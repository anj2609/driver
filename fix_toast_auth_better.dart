import 'dart:io';

void main() {
  final file = File(r'c:\Users\HP\Desktop\27 may\myridedriverappletest\lib\controllers\auth_controller.dart');
  String content = file.readAsStringSync();
  
  // Clean up any double wraps first if they exist
  // (We don't know if some are already double wrapped)

  int i = 0;
  while (true) {
    i = content.indexOf('AnimatedTopToast.show(', i);
    if (i == -1) break;
    
    // Check if we are already wrapped
    int lastIf = content.lastIndexOf('if (context.mounted)', i);
    if (lastIf != -1) {
      // Check if there is only whitespace between lastIf and i
      String between = content.substring(lastIf + 'if (context.mounted) {'.length, i);
      if (between.trim().isEmpty) {
        // already wrapped, skip
        i++;
        continue;
      }
    }
    
    // Find the end of the statement );
    int end = content.indexOf(');', i);
    if (end == -1) break;
    
    // Extract the call
    String call = content.substring(i, end + 2);
    
    // Wrap
    String wrapped = 'if (context.mounted) {\n' + call + '\n}';
    
    content = content.substring(0, i) + wrapped + content.substring(end + 2);
    
    // update i to not match the same one again
    i = i + wrapped.length;
  }
  
  file.writeAsStringSync(content);
  print('Fixed AnimatedTopToast in auth_controller.dart');
}
