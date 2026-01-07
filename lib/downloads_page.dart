import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'pdf_viewer_page.dart';

class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});

  Future<List<File>> getDownloadedFiles() async {
    final dir = await getApplicationDocumentsDirectory();
    final files = dir
        .listSync()
        .whereType<File>()
        .toList();
    return files;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Downloaded Files")),
      body: FutureBuilder<List<File>>(
        future: getDownloadedFiles(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final files = snapshot.data!;
          if (files.isEmpty) return const Center(child: Text("No files"));

          return ListView.builder(
            itemCount: files.length,
            itemBuilder: (context, index) {
              final file = files[index];
              return ListTile(
                title: Text(file.path.split('/').last),
                trailing: const Icon(Icons.visibility),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PdfViewerPage(file: file),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
