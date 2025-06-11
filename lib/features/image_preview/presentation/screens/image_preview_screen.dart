import 'dart:io';
import 'package:flutter/material.dart';

class ImagePreviewScreen extends StatelessWidget {
  final String imagePath;

  const ImagePreviewScreen({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    final imageFile = File(imagePath);

    return Scaffold(
      backgroundColor: Colors.black, // Dark background for image preview
      appBar: AppBar(
        backgroundColor: Colors.transparent, // Transparent app bar
        elevation: 0,
        // leading: IconButton(
        //   icon: const Icon(Icons.arrow_back, color: Colors.white),
        //   onPressed: () => Navigator.of(context).pop(),
        // ),
      ),
      body: Center(
        child: FutureBuilder<bool>(
          future: imageFile.exists(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white));
            }
            if (snapshot.data == true) {
              return InteractiveViewer(
                panEnabled: true, // Enable panning
                minScale: 0.5,
                maxScale: 4.0,   // Enable zooming
                child: Image.file(
                  imageFile,
                  fit: BoxFit.contain, // Show the whole image, allow zooming for details
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image, color: Colors.white54, size: 60),
                          SizedBox(height: 10),
                          Text(
                            'Error loading image',
                            style: TextStyle(color: Colors.white54, fontSize: 16),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            } else {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image_not_supported_outlined, color: Colors.white54, size: 60),
                    SizedBox(height: 10),
                    Text(
                      'Image file not found',
                      style: TextStyle(color: Colors.white54, fontSize: 16),
                    ),
                  ],
                ),
              );
            }
          }
        ),
      ),
    );
  }
} 