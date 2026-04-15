import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

/// Metadata stored inline inside every encrypted file.
class FileMetadata {
  final String fileName;
  final String sourceUrl;
  final String fetchedUrl;
  final String sha256Hash;
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

  bool verifyIntegrity(Uint8List decryptedBytes) {
    final hash = sha256.convert(decryptedBytes).toString();
    return hash == sha256Hash;
  }

  String get formattedTimestamp {
    final d = timestamp;
    final date = '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
    final time = '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
    return '$date at $time';
  }

  String get formattedSize {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> toJson() => {
    'fileName':      fileName,
    'sourceUrl':     sourceUrl,
    'fetchedUrl':    fetchedUrl,
    'sha256Hash':    sha256Hash,
    'timestamp':     timestamp.toIso8601String(),
    'fileSizeBytes': fileSizeBytes,
  };

  factory FileMetadata.fromJson(Map<String, dynamic> j) => FileMetadata(
    fileName:      j['fileName']      as String,
    sourceUrl:     j['sourceUrl']     as String,
    fetchedUrl:    j['fetchedUrl']    as String,
    sha256Hash:    j['sha256Hash']    as String,
    timestamp:     DateTime.parse(j['timestamp'] as String),
    fileSizeBytes: j['fileSizeBytes'] as int,
  );

  static FileMetadata create({
    required String fileName,
    required String sourceUrl,
    required String fetchedUrl,
    required Uint8List originalBytes,
  }) {
    final meta = FileMetadata(
      fileName:      fileName,
      sourceUrl:     sourceUrl,
      fetchedUrl:    fetchedUrl,
      sha256Hash:    sha256.convert(originalBytes).toString(),
      timestamp:     DateTime.now(),
      fileSizeBytes: originalBytes.length,
    );
    print('📋 [METADATA] Created metadata:');
    print('   • fileName: $fileName');
    print('   • sourceUrl: $sourceUrl');
    print('   • fetchedUrl: $fetchedUrl');
    print('   • sha256Hash: ${meta.sha256Hash}');
    print('   • timestamp: ${meta.formattedTimestamp}');
    print('   • fileSize: ${meta.formattedSize}');
    return meta;
  }
}