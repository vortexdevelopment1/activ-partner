import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class MultiImagePickerExample extends StatefulWidget {
  @override
  _MultiImagePickerExampleState createState() =>
      _MultiImagePickerExampleState();
}

class _MultiImagePickerExampleState extends State<MultiImagePickerExample> {
  final ImagePicker _picker = ImagePicker();
  List<XFile> _images = [];

  Future<void> pickImages() async {
    final List<XFile>? selectedImages = await _picker.pickMultiImage();

    if (selectedImages != null) {
      if (selectedImages.length < 4) {
        // Agar 4 se kam hai to error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Please select at least 4 images")),
        );
      } else if (selectedImages.length > 4) {
        // Agar 4 se zyada select kare to error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("You can select only 4 images")),
        );
      } else {
        setState(() {
          _images = selectedImages;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Pick Multiple Images")),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: pickImages,
            child: Text("Pick Images"),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _images.isNotEmpty
                ? GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: _images.length,
              itemBuilder: (context, index) {
                return Image.file(
                  File(_images[index].path),
                  fit: BoxFit.cover,
                );
              },
            )
                : Center(child: Text("No images selected")),
          ),
        ],
      ),
    );
  }
}
