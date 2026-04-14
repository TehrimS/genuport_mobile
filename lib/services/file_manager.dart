import 'dart:io';
import 'package:path_provider/path_provider.dart';

class FileManager {
  // Get the Downloads directory path - uses app-specific external storage
  static Future<String> getDownloadPath() async {
    try {
      // Try external storage first
      Directory? externalDir;
      
      // Method 1: Try getExternalFilesDir (app-specific external directory)
      try {
        final tempDir = await getTemporaryDirectory();
        // Access external files via path manipulation
        final path = tempDir.path.replaceAll('/cache', '/files');
        externalDir = Directory(path);
        if (await externalDir.exists()) {
          print('✅ Using external files directory');
        } else {
          externalDir = null;
        }
      } catch (e) {
        print('⚠️ Method 1 failed: $e');
      }
      
      // Method 2: Use app documents directory as fallback
      if (externalDir == null) {
        externalDir = await getApplicationDocumentsDirectory();
        print('✅ Using app documents directory (fallback)');
      }
      
      final downloadPath = '${externalDir.path}/Downloads';
      
      // Ensure directory exists
      final downloadDir = Directory(downloadPath);
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
        print('✅ Created Downloads directory');
      }
      
      print('📂 FileManager using path: $downloadPath');
      return downloadPath;
    } catch (e) {
      print('❌ Error getting directory: $e');
      rethrow;
    }
  }

  static Future<String> getArchivedPath() async {
    final basePath = await getDownloadPath();
    final archivedPath = '$basePath/Archived';
    final dir = Directory(archivedPath);
    
    if (!await dir.exists()) {
      await dir.create(recursive: true);
      print('✅ Created Archived folder: $archivedPath');
    }
    
    return archivedPath;
  }

  /// Move file to Archived folder
  static Future<void> archiveFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File does not exist: $filePath');
      }

      final fileName = file.path.split('/').last;
      final archivedPath = await getArchivedPath();
      final newPath = '$archivedPath/$fileName';

      print('📦 Archiving file: $fileName');
      print('   From: $filePath');
      print('   To: $newPath');

      // Copy then delete (safer than move)
      await file.copy(newPath);
      await file.delete();
      
      print('✅ File archived successfully');
    } catch (e) {
      print('❌ Error archiving file: $e');
      throw Exception('Failed to archive file: $e');
    }
  }

  /// Delete a file
  static Future<void> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File does not exist: $filePath');
      }

      print('🗑️ Deleting file: ${file.path}');
      await file.delete();
      print('✅ File deleted successfully');
    } catch (e) {
      print('❌ Error deleting file: $e');
      throw Exception('Failed to delete file: $e');
    }
  }

  /// Unarchive a file (restore from Archived folder)
  static Future<void> unarchiveFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File does not exist: $filePath');
      }

      final fileName = file.path.split('/').last;
      // Remove '/Archived' from path to get the main downloads directory
      final downloadPath = await getDownloadPath();
      final newPath = '$downloadPath/$fileName';

      print('📂 Unarchiving file: $fileName');
      print('   From: $filePath');
      print('   To: $newPath');

      // Copy then delete
      await file.copy(newPath);
      await file.delete();
      
      print('✅ File unarchived successfully');
    } catch (e) {
      print('❌ Error unarchiving file: $e');
      throw Exception('Failed to unarchive file: $e');
    }
  }

  /// Get all files in a directory
  static Future<List<FileSystemEntity>> getFilesInDirectory(String path) async {
    try {
      final dir = Directory(path);
      if (!await dir.exists()) {
        return [];
      }

      final files = dir.listSync();
      return files.whereType<File>().toList();
    } catch (e) {
      print('❌ Error listing files: $e');
      return [];
    }
  }

  /// Get file size in human-readable format
  static String getFileSizeString(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Get last modified date in readable format
  static String getLastModifiedString(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else {
      return 'mm/dd/yyyy'.replaceAll('mm', dateTime.month.toString().padLeft(2, '0'))
          .replaceAll('dd', dateTime.day.toString().padLeft(2, '0'))
          .replaceAll('yyyy', dateTime.year.toString());
    }
  }
}
