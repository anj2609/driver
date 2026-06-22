import 'dart:io';
import 'dart:ui' as ui;

Future<File> compressImageUnder2MB(File file) async {
  File resultFile = file;
  int fileSize = await resultFile.length();
  int targetWidth = 1000;

  while (fileSize > 2048 * 1024) {
    final bytes = await resultFile.readAsBytes();

    ui.Codec codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: targetWidth,
    );

    ui.FrameInfo frame = await codec.getNextFrame();

    /// 🔥 always convert to JPEG (best compression)
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);

    final resizedBytes = data!.buffer.asUint8List();

    final tempDir = Directory.systemTemp;
    resultFile = File(
      '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );

    await resultFile.writeAsBytes(resizedBytes);

    fileSize = await resultFile.length();
    print("🔁 COMPRESSED SIZE: ${fileSize / 1024} KB");

    targetWidth -= 200;

    if (targetWidth < 300) break;
  }

  return resultFile;
}

bool isValidImageFormat(File file) {
  String path = file.path.toLowerCase();

  return path.endsWith(".jpg") ||
      path.endsWith(".jpeg") ||
      path.endsWith(".png") ||
      path.endsWith(".webp");
}
