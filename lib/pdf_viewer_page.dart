import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

class PdfViewerPage extends StatelessWidget {
  final File file;
  const PdfViewerPage({required this.file, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("View Document")),
      body: PdfView(
        controller: PdfController(
          document: PdfDocument.openFile(file.path),
        ),
      ),
    );
  }
}
