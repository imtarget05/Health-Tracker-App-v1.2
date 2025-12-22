import 'dart:io';
import 'package:flutter/material.dart';
// assets_manager import not required here; keep widget minimal to avoid unused import lint

class BuildDisplayImage extends StatelessWidget {
  const BuildDisplayImage({
    super.key,
    required this.file,
    required this.userImage,
    required this.onPressed,
  });

  final File? file;
  final String userImage;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final imageProvider = getImageToShow();
    return Stack(
      children: [
        CircleAvatar(
          radius: 60.0,
          backgroundColor: Colors.grey[200],
          backgroundImage: imageProvider,
          child: imageProvider == null ? const Icon(Icons.person, size: 40, color: Colors.white) : null,
        ),
        Positioned(
          bottom: 0.0,
          right: 0.0,
          child: InkWell(
            onTap: onPressed,
            child: const CircleAvatar(
              backgroundColor: Colors.blue,
              radius: 20.0,
              child: Icon(
                Icons.camera_alt,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  ImageProvider<Object>? getImageToShow() {
    if (file != null) {
      return FileImage(File(file!.path));
    } else if (userImage.isNotEmpty) {
      return FileImage(File(userImage));
    } else {
      // asset may be missing in some branches; return null so CircleAvatar shows placeholder
      return null;
    }
  }
}
