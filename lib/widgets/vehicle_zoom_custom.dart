import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

class FullImageViewer extends StatefulWidget {
  /// Full, already-resolved image URLs — NOT raw storage-relative paths.
  /// Callers must run each path through their own URL-building logic (see
  /// _vehicleImageUrl in vehicles_screen.dart) before passing it here. This
  /// widget used to prepend ApiConstants.fileUrl itself, which duplicated
  /// (and diverged from) that logic and left zoomed images 404ing even
  /// after the grid thumbnails were fixed to build the right URL.
  final List<String> images;
  final int initialIndex;

  const FullImageViewer({
    super.key,
    required this.images,
    required this.initialIndex,
  });

  @override
  State<FullImageViewer> createState() => _FullImageViewerState();
}

class _FullImageViewerState extends State<FullImageViewer> {
  late PageController pageController;

  @override
  void initState() {
    super.initState();
    pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: PageView.builder(
        controller: pageController,
        itemCount: widget.images.length,
        itemBuilder: (context, index) {
          return PhotoView(
            imageProvider: NetworkImage(widget.images[index]),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 3,
          );
        },
      ),
    );
  }
}
