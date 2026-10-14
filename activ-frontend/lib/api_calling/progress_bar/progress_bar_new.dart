import 'package:activ_app/api_calling/progress_bar/workspace.dart';
import 'package:flutter/material.dart';


class ProgressBarNew {

  /*============exit alert dialog============*/
  showLoader(context) {
    return showDialog(
          context: context,
          builder: (context) =>
              initAlertDialog());
  }

  AlertDialog initAlertDialog() {
    return
    AlertDialog(
      content: WorkSpace(),
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      elevation: 0.0,

    );
  }
}