import 'dart:io';

void main() {
  final file = File('assets/images/WhatsApp Video 2026-07-24 at 12.09.43 PM.gif');
  final bytes = file.readAsBytesSync();
  if (bytes.length > 13) {
    int packed = bytes[10];
    bool hasGlobalColorTable = (packed & 0x80) != 0;
    int bgColorIndex = bytes[11];
    
    if (hasGlobalColorTable) {
      int colorTableSize = 1 << ((packed & 0x07) + 1);
      int colorTableOffset = 13;
      int r = bytes[colorTableOffset + bgColorIndex * 3];
      int g = bytes[colorTableOffset + bgColorIndex * 3 + 1];
      int b = bytes[colorTableOffset + bgColorIndex * 3 + 2];
      print('Background color: #' + r.toRadixString(16).padLeft(2, '0') + g.toRadixString(16).padLeft(2, '0') + b.toRadixString(16).padLeft(2, '0'));
      
      int r0 = bytes[colorTableOffset];
      int g0 = bytes[colorTableOffset + 1];
      int b0 = bytes[colorTableOffset + 2];
      print('Color 0: #' + r0.toRadixString(16).padLeft(2, '0') + g0.toRadixString(16).padLeft(2, '0') + b0.toRadixString(16).padLeft(2, '0'));
    } else {
      print('No global color table');
    }
  }
}
