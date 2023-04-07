import 'package:flutter/material.dart';

showCircularProgressIndicator(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => const Center(
      child: CircularProgressIndicator(),
    ),
    barrierDismissible: false,
  );
}

hideCircularProgressIndicator(BuildContext context) {
  Navigator.of(context).pop();
}
