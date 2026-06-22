import 'dart:io';
import 'package:flutter/material.dart';

class FullImageView extends StatelessWidget {
  final File? file;
  final String? imageUrl;

  const FullImageView({super.key, this.file, this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final imageWidget = file != null
        ? Image.file(file!, fit: BoxFit.contain)
        : (imageUrl != null && imageUrl!.isNotEmpty)
            ? Image.network(imageUrl!, fit: BoxFit.contain)
            : const Icon(Icons.image, color: Colors.white, size: 80);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [

          Positioned.fill(
            child: Opacity(
              opacity: 0.3,
              child: file != null
                  ? Image.file(file!, fit: BoxFit.cover)
                  : (imageUrl != null && imageUrl!.isNotEmpty)
                      ? Image.network(imageUrl!, fit: BoxFit.cover)
                      : Container(color: Colors.black),
            ),
          ),
          Center(
            child: Hero(
              tag: "profileImage",
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: imageWidget,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  
                  /// CLOSE BUTTON
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),

                  /// DOWNLOAD BUTTON (optional)
                  IconButton(
                    icon: const Icon(Icons.download, color: Colors.white),
                    onPressed: () {
                      // TODO: download logic
                    },
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}