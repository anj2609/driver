import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:myridedriverapp/config/utils/colors.dart';

/// Shows a bottom sheet letting the user choose where to pick an image
/// from — Camera, Gallery, and (optionally) Files — and returns the
/// selected [File], or null if the user picked nothing / cancelled.
Future<File?> pickImageFromSource(
  BuildContext context, {
  bool allowFiles = false,
}) async {
  final String? source = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Icon(Icons.camera_alt, color: ColorResources.appColor),
              title: const Text("Camera"),
              onTap: () => Navigator.pop(sheetContext, 'camera'),
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: ColorResources.appColor),
              title: const Text("Gallery"),
              onTap: () => Navigator.pop(sheetContext, 'gallery'),
            ),
            if (allowFiles)
              ListTile(
                leading: Icon(Icons.folder, color: ColorResources.appColor),
                title: const Text("Files"),
                onTap: () => Navigator.pop(sheetContext, 'files'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );

  if (source == null) return null;

  try {
    if (source == 'camera') {
      final XFile? picked = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      return picked != null ? File(picked.path) : null;
    }

    if (source == 'gallery') {
      final XFile? picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      return picked != null ? File(picked.path) : null;
    }

    // Files — browse the device's file system, restricted to images so
    // the downstream compression step (which only handles images) works.
    final FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.image,
    );
    final path = result?.files.single.path;
    return path != null ? File(path) : null;
  } catch (e) {
    debugPrint('pickImageFromSource error: $e');
    return null;
  }
}
