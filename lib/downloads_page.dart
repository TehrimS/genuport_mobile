import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'pdf_viewer_page.dart';

class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});

  Future<List<File>> getDownloadedFiles() async {
    if (Platform.isAndroid) {
      // Read from PUBLIC Downloads folder
      Directory dir = Directory('/storage/emulated/0/Download/MyBrowserDownloads');
      
      if (!await dir.exists()) {
        return [];
      }
      
      try {
        final files = dir
            .listSync()
            .whereType<File>()
            .toList()
          ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
        
        return files;
      } catch (e) {
        print('Error reading files: $e');
        return [];
      }
    } else {
      // iOS
      final docDir = await getApplicationDocumentsDirectory();
      final customPath = '${docDir.path}/MyBrowserDownloads';
      Directory dir = Directory(customPath);
      
      if (!await dir.exists()) {
        return [];
      }
      
      final files = dir
          .listSync()
          .whereType<File>()
          .toList()
        ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
      
      return files;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return '${diff.inMinutes} min ago';
      }
      return '${diff.inHours} hours ago';
    }
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Downloads"),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Downloads Location'),
                  content: const Text(
                    'Files are saved in:\n'
                    '/storage/emulated/0/MyBrowserDownloads\n\n'
                    'You can find this folder in your file manager app.'
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<List<File>>(
        future: getDownloadedFiles(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final files = snapshot.data!;
          
          if (files.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No downloads yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Files will appear here when you download them',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: files.length,
            itemBuilder: (context, index) {
              final file = files[index];
              final fileName = file.path.split('/').last;
              final fileSize = _formatFileSize(file.lengthSync());
              final fileDate = _formatDate(file.statSync().modified);
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue[100],
                    child: Icon(
                      fileName.endsWith('.pdf') ? Icons.picture_as_pdf : Icons.insert_drive_file,
                      color: Colors.blue[700],
                    ),
                  ),
                  title: Text(
                    fileName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text('$fileSize • $fileDate'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    if (fileName.endsWith('.pdf')) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PdfViewerPage(file: file),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Only PDF files can be viewed')),
                      );
                    }
                  },
                  onLongPress: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete file?'),
                        content: Text('Delete "$fileName"?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              file.deleteSync();
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('File deleted')),
                              );
                              // Refresh the page
                              (context as Element).markNeedsBuild();
                            },
                            child: const Text('Delete', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}