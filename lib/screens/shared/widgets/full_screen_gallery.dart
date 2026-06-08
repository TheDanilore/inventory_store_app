// ─── FULL SCREEN GALLERY ─────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:inventory_store_app/models/product_image_model.dart';

class FullScreenGallery extends StatelessWidget {
  final List<ProductImageModel> images;
  final int initialIndex;
  const FullScreenGallery({
    super.key,
    required this.images,
    required this.initialIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: PageView.builder(
        controller: PageController(initialPage: initialIndex),
        itemCount: images.length,
        itemBuilder:
            (context, index) => InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 1.0,
              maxScale: 4.0,
              child: Image.network(images[index].imageUrl, fit: BoxFit.contain),
            ),
      ),
    );
  }
}
