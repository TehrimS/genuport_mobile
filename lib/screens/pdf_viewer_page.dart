import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

class PdfViewerPage extends StatefulWidget {
  final File file;
  final Uint8List? bytes;
  const PdfViewerPage({required this.file, this.bytes, super.key});

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  PdfController? _pdfController;
  String? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      late Future<PdfDocument> document;

      if (widget.bytes != null) {
        // Use provided decrypted bytes
        print('📄 Loading PDF from bytes (${widget.bytes!.length} bytes)');
        document = PdfDocument.openData(widget.bytes!);
      } else {
        // Check if file exists and use file path
        if (!await widget.file.exists()) {
          throw Exception('File not found');
        }

        final fileSize = await widget.file.length();
        print('📄 Loading PDF: ${widget.file.path}');
        print('📊 File size: $fileSize bytes');

        if (fileSize == 0) {
          throw Exception('File is empty (0 bytes)');
        }

        document = PdfDocument.openFile(widget.file.path);
      }

      _pdfController = PdfController(document: document);

      setState(() {
        _isLoading = false;
      });

      print('✅ PDF loaded successfully');
    } catch (e) {
      print('❌ Failed to load PDF: $e');

      String errorMessage;
      if (e.toString().contains('err=3') ||
          e.toString().contains('Parse Document failed') ||
          e.toString().contains('Invalid PDF format')) {
        errorMessage = 'PDF file is corrupted or still password-protected.\n\n'
            'This might happen if:\n'
            '• The PDF password was incorrect\n'
            '• The file wasn\'t fully decrypted\n'
            '• The download was incomplete\n\n'
            'Try re-downloading the file.';
      } else if (e.toString().contains('password')) {
        errorMessage = 'This PDF is still password protected.\n\n'
            'The password removal failed during download.\n'
            'Please re-download and provide the correct password.';
      } else {
        errorMessage = 'Cannot open PDF file.\n\nError: ${e.toString()}';
      }

      setState(() {
        _error = errorMessage;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("View Document"),
        actions: [
          if (_error != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                _loadPdf();
              },
              tooltip: 'Retry',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading PDF...'),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red[300],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Cannot Open PDF',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => _loadPdf(),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.arrow_back),
                              label: const Text('Go Back'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
              : _pdfController != null
                  ? PdfView(controller: _pdfController!)
                  : const Center(child: Text('PDF controller not initialized')),
    );
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }
}