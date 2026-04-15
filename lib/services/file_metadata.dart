import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

/// Metadata stored for every downloaded file.
class FileMetadata {
  final String fileName;
  final String sourceUrl;      // URL user tapped / initiated download from
  final String fetchedUrl;     // Actual URL the file was fetched from (may differ for redirects/blobs)
  final String sha256Hash;     // SHA-256 of the DECRYPTED file bytes (for integrity check)
  final DateTime timestamp;
  final int fileSizeBytes;

  const FileMetadata({
    required this.fileName,
    required this.sourceUrl,
    required this.fetchedUrl,
    required this.sha256Hash,
    required this.timestamp,
    required this.fileSizeBytes,
  });

  /// Verify integrity: re-hash decrypted bytes and compare.
  bool verifyIntegrity(Uint8List decryptedBytes) {
    final hash = sha256.convert(decryptedBytes).toString();
    return hash == sha256Hash;
  }

  String get formattedTimestamp {
    final d = timestamp;
    final date = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    final time = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return '$date at $time';
  }

  String get formattedSize {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> toJson() => {
    'fileName': fileName,
    'sourceUrl': sourceUrl,
    'fetchedUrl': fetchedUrl,
    'sha256Hash': sha256Hash,
    'timestamp': timestamp.toIso8601String(),
    'fileSizeBytes': fileSizeBytes,
  };

  factory FileMetadata.fromJson(Map<String, dynamic> j) => FileMetadata(
    fileName: j['fileName'] as String,
    sourceUrl: j['sourceUrl'] as String,
    fetchedUrl: j['fetchedUrl'] as String,
    sha256Hash: j['sha256Hash'] as String,
    timestamp: DateTime.parse(j['timestamp'] as String),
    fileSizeBytes: j['fileSizeBytes'] as int,
  );
}

/// Persists metadata as a JSON sidecar file alongside each .enc file.
/// e.g. statement.pdf.enc → statement.pdf.enc.meta
class FileMetadataStore {
  /// Generate and compute metadata for a downloaded file.
  static FileMetadata create({
    required String fileName,
    required String sourceUrl,
    required String fetchedUrl,
    required Uint8List originalBytes, // decrypted bytes, before encryption
  }) {
    final hash = sha256.convert(originalBytes).toString();
    return FileMetadata(
      fileName: fileName,
      sourceUrl: sourceUrl,
      fetchedUrl: fetchedUrl,
      sha256Hash: hash,
      timestamp: DateTime.now(),
      fileSizeBytes: originalBytes.length,
    );
  }

  /// Save metadata next to the encrypted file.
  static Future<void> save(String encFilePath, FileMetadata meta) async {
    final metaFile = File('$encFilePath.meta');
    await metaFile.writeAsString(jsonEncode(meta.toJson()));
  }

  /// Load metadata for an encrypted file. Returns null if not found.
  static Future<FileMetadata?> load(String encFilePath) async {
    final metaFile = File('$encFilePath.meta');
    if (!await metaFile.exists()) return null;
    try {
      final raw = await metaFile.readAsString();
      return FileMetadata.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Delete metadata when the associated file is deleted.
  static Future<void> delete(String encFilePath) async {
    final metaFile = File('$encFilePath.meta');
    if (await metaFile.exists()) await metaFile.delete();
  }
}