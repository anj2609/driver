import 'dart:io';

void main() {
  final file = File('assets/images/WhatsApp Video 2026-07-24 at 12.09.43 PM.gif');
  final bytes = file.readAsBytesSync();
  if (bytes.length > 13) {
    int width = bytes[6] | (bytes[7] << 8);
    int height = bytes[8] | (bytes[9] << 8);
    print('Width: ' + width.toString() + ', Height: ' + height.toString());
  }
}
