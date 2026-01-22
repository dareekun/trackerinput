
import 'package:flutter/material.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});
  

  @override
  Widget build(BuildContext context) {
    // Mendapatkan ukuran layar/window
    Size size = MediaQuery.of(context).size;
    double width = size.width;
    double height = size.height;

    return Scaffold(
      body: Center(
        child: Text("Ukuran Window: ${width.toInt()} x ${height.toInt()}"),
      ),
    );
  }
}
