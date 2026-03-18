import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'pdf_viewer_page.dart';
import 'encryption_service.dart';
import 'pdf_unlocker.dart';

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  final _encryptionService = EncryptionService();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeEncryption();
  }

  Future<void> _initializeEncryption() async {
    try {
      await _encryptionService.initialize();
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      print('Failed to initialize encryption: $e');
    }
  }

  Future<List<File>> getDownloadedFiles() async {
    if (Platform.isAndroid) {
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

  String _getDisplayFileName(String fileName) {
    if (fileName.endsWith('.enc')) {
      return fileName.substring(0, fileName.length - 4);
    }
    return fileName;
  }

  bool _isEncryptedFile(String fileName) {
    return fileName.endsWith('.enc');
  }

  /// Ask user for PDF password
  Future<String?> _askForPdfPassword(BuildContext context) async {
    final TextEditingController passwordController = TextEditingController();
    
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock_open, color: Colors.orange),
            SizedBox(width: 8),
            Text('PDF Password Required'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This PDF is password protected.\nEnter password to view it:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                hintText: 'e.g., DOB (DDMMYYYY) or PAN',
                prefixIcon: Icon(Icons.key),
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '💡 Common bank passwords:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  SizedBox(height: 4),
                  Text('• Date of Birth: DDMMYYYY', style: TextStyle(fontSize: 12)),
                  Text('• PAN Card: ABCDE1234F', style: TextStyle(fontSize: 12)),
                  Text('• "password" or "statement"', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context, passwordController.text);
            },
            icon: const Icon(Icons.lock_open),
            label: const Text('Unlock'),
          ),
        ],
      ),
    );
  }

  Future<void> _openFile(BuildContext context, File file, String displayName, bool isEncrypted) async {
    if (!displayName.toLowerCase().endsWith('.pdf')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only PDF files can be viewed')),
      );
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Decrypting file...', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );

    try {
      File fileToView;

      if (isEncrypted) {
        if (!_isInitialized) {
          throw Exception('Encryption service not initialized');
        }

        // Read encrypted file
        final encryptedBytes = await file.readAsBytes();
        
        // Decrypt app encryption
        var decryptedBytes = await _encryptionService.decryptFile(encryptedBytes);
        
        // Check if PDF is password protected
        if (PdfUnlocker.isPasswordProtected(decryptedBytes)) {
          print('🔒 PDF is still password protected after app decryption');
          
          // Close loading dialog
          if (context.mounted) Navigator.pop(context);
          
          // Ask for password
          String? password;
          if (context.mounted) {
            password = await _askForPdfPassword(context);
          }
          
          if (password == null || password.isEmpty) {
            // User cancelled
            return;
          }
          
          // Show loading again
          if (context.mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Unlocking PDF...', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            );
          }
          
          // Try to unlock with password
          var unlockedBytes = await PdfUnlocker.unlockPdf(decryptedBytes, password);
          
          // If failed, try common passwords
          if (unlockedBytes == null) {
            print('⚠️ User password failed, trying common passwords...');
            unlockedBytes = await PdfUnlocker.tryUnlockWithCommonPasswords(
              decryptedBytes,
              dob: password,
              pan: password,
            );
          }
          
          if (unlockedBytes == null) {
            // Close loading dialog
            if (context.mounted) Navigator.pop(context);
            
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('❌ Wrong password. Cannot unlock PDF.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }
          
          // Successfully unlocked!
          decryptedBytes = unlockedBytes;
          print('✅ PDF unlocked successfully!');
          
          // Update the encrypted file with unlocked version
          // (so user doesn't need to enter password again)
          try {
            final reEncryptedBytes = await _encryptionService.encryptFile(decryptedBytes);
            await file.writeAsBytes(reEncryptedBytes);
            print('✅ Updated file with unlocked version');
          } catch (e) {
            print('⚠️ Could not update file: $e');
          }
        }
        
        // Create temporary file for viewing
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/${displayName}_temp.pdf');
        await tempFile.writeAsBytes(decryptedBytes);
        
        fileToView = tempFile;
      } else {
        // File is not encrypted, view directly
        fileToView = file;
      }

      // Close loading dialog
      if (context.mounted) Navigator.pop(context);
      
      // Open PDF viewer
      if (context.mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PdfViewerPage(file: fileToView),
          ),
        );
        
        // Clean up temp file after viewing
        if (isEncrypted) {
          try {
            await fileToView.delete();
          } catch (e) {
            print('Failed to delete temp file: $e');
          }
        }
      }
    } catch (e) {
      // Close loading dialog
      if (context.mounted) Navigator.pop(context);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
                  title: Row(
                    children: [
                      Icon(Icons.shield, color: Colors.green[700]),
                      const SizedBox(width: 8),
                      const Text('Secure Downloads'),
                    ],
                  ),
                  content: const Text(
                    'Files are encrypted and saved in:\n'
                    '/storage/emulated/0/Download/MyBrowserDownloads\n\n'
                    '🔒 All files are encrypted with AES-256.\n\n'
                    '✓ Files are decrypted when you view them.\n\n'
                    '✓ Password-protected PDFs will ask for password on first view.\n\n'
                    'Files in this folder cannot be opened without this app.'
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
              final displayName = _getDisplayFileName(fileName);
              final isEncrypted = _isEncryptedFile(fileName);
              final fileSize = _formatFileSize(file.lengthSync());
              final fileDate = _formatDate(file.statSync().modified);
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: Stack(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.blue[100],
                        child: Icon(
                          displayName.toLowerCase().endsWith('.pdf') 
                              ? Icons.picture_as_pdf 
                              : Icons.insert_drive_file,
                          color: Colors.blue[700],
                        ),
                      ),
                      if (isEncrypted)
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.green[700],
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.lock,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: Text(
                    displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Row(
                    children: [
                      Text('$fileSize • $fileDate'),
                      if (isEncrypted) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Encrypted',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.green[800],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _openFile(context, file, displayName, isEncrypted),
                  onLongPress: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete file?'),
                        content: Text('Delete "$displayName"?'),
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
                              setState(() {});
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