import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final inputPath = 'assets/images/N driver app icon white v1.png';
  final outputPath = 'assets/images/N driver app icon white v1_zoomed.png';

  final bytes = File(inputPath).readAsBytesSync();
  var image = img.decodeImage(bytes);

  if (image == null) {
    print('Failed to decode image');
    return;
  }

  // Define zoom factor (e.g., 0.8 means we keep the center 80% of the image)
  // To zoom MORE, we decrease this number.
  double zoomFactor = 0.75; 

  int newWidth = (image.width * zoomFactor).round();
  int newHeight = (image.height * zoomFactor).round();

  int offsetX = (image.width - newWidth) ~/ 2;
  int offsetY = (image.height - newHeight) ~/ 2;

  // Crop the center
  var cropped = img.copyCrop(image, x: offsetX, y: offsetY, width: newWidth, height: newHeight);
  
  // Resize back to original dimensions for good resolution
  var resized = img.copyResize(cropped, width: image.width, height: image.height);

  final png = img.encodePng(resized);
  File(outputPath).writeAsBytesSync(png);

  print('Saved manually zoomed image to $outputPath');
}
