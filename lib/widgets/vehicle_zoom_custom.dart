import 'package:flutter/material.dart';
import 'package:myridedriverapp/config/utils/constants.dart';
import 'package:photo_view/photo_view.dart';

class FullImageViewer extends StatefulWidget {
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
            imageProvider: NetworkImage(
              "${ApiConstants.fileUrl}${widget.images[index]}",
            ),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 3,
          );
        },
      ),
    );
  }
}
