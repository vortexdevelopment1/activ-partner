import 'package:activ_app/api_calling/progress_bar/workspace.dart';
import 'package:flutter/material.dart';

class ProgressBar1 {
  bool _isLoading = false;


  void showLoader(BuildContext context) {
    if (!_isLoading) {
      _isLoading = true;
      showDialog(
        context: context,
        barrierDismissible: false, // Prevent dismissing dialog by tapping outside
        builder: (context) {
          // Set _isLoading to false when dialog is dismissed
          return WillPopScope(
            onWillPop: () async {
              _isLoading = false;
              return true;
            },
            child: initAlertDialog(),
          );
        },
      ).then((value) {
        // Reset _isLoading when dialog is dismissed
        _isLoading = false;
      }).catchError((error) {
        // Reset _isLoading if there's an error
        _isLoading = false;
      });
    }
  }

  AlertDialog initAlertDialog() {
    return AlertDialog(
      content: WorkSpace(),
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      elevation: 0.0,
    );
  }

  bool isLoading() {
    return _isLoading;
  }
}
