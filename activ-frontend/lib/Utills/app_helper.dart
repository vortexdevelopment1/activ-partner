import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';

class AppHelper {

  static Future<File?> cropImage(File imageFile) async
  {
    if(Platform.isAndroid)
    {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown,]);
      var _croppedFile = await ImageCropper().cropImage
        (
          sourcePath: imageFile.path,
          uiSettings: [
          AndroidUiSettings(
            toolbarColor: Color(0xFFB24B14),
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: Colors.white,
            hideBottomControls: true,
            statusBarColor: Colors.black,   // ✅ अलग रंग ताकि status bar clear हो
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: true,
            aspectRatioPresets: Platform.isAndroid
                ? [
              CropAspectRatioPreset.ratio16x9,
            ] : [
              CropAspectRatioPreset.ratio16x9,
            ],

            toolbarTitle: "Crop Image",  // Added a title to the toolbar

          ),
          IOSUiSettings(
            hidesNavigationBar: true,
            rotateClockwiseButtonHidden: true,
            rotateButtonsHidden: true,
            resetButtonHidden: true,
            aspectRatioPickerButtonHidden: true,
            minimumAspectRatio: 4.0,
            title: "Crop Image",  // Added title for iOS
          ),
        ],
      );
      return File(_croppedFile!.path.toString());
    }
    else
    {
      return imageFile;
    }
  }

  // For Image Compress
  /*static Future<File> compress({
    File? image,
    int quality = 50,
    int percentage = 100,
  }) async {
    var path = await FlutterNativeImage.compressImage(image.absolute.path,
        quality: quality, percentage: percentage);
    return path;
  }*/
}
