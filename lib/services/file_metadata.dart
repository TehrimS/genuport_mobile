import 'package:crypto/crypto.dart';

class FileMetadata {
  final String fileName;
  final String sourceUrl;
  final String fetchedUrl;
  final DateTime timestamp;
  final int fileSize;
  
  /// DEPRECATED: Use sourceHash instead for password-protected files
  /// For regular files, sourceHash and sha256Hash are identical
  final String sha256Hash;
  
  /// Hash of the original file as received (e.g., password-protected PDF)
  /// Step 1: Computed immediately when file arrives, before any processing
  final String sourceHash;
  
  /// Hash of the unlocked/processed content
  /// Step 3: Computed after password unlocking or content modification
  /// If null, file was not password-protected
  final String? unlockedHash;
  
  /// How the file was unlocked: 'in-session', 'pre-unlocked', or null if not unlocked
  final String? unlockMethod;

  FileMetadata({
    required this.fileName,
    required this.sourceUrl,
    required this.fetchedUrl,
    required this.timestamp,
    required this.fileSize,
    required this.sha256Hash,
    required this.sourceHash,
    this.unlockedHash,
    this.unlockMethod,
  });

  /// Factory: Create from original bytes (Step 1)
  /// Computes sourceHash immediately
  factory FileMetadata.create({
    required String fileName,
    required String sourceUrl,
    required String fetchedUrl,
    required List<int> originalBytes,
  }) {
    final hash = sha256.convert(originalBytes).toString();
    return FileMetadata(
      fileName: fileName,
      sourceUrl: sourceUrl,
      fetchedUrl: fetchedUrl,
      timestamp: DateTime.now(),
      fileSize: originalBytes.length,
      sha256Hash: hash,
      sourceHash: hash, // sourceHash = hash of original file
      unlockedHash: null,
      unlockMethod: null,
    );
  }

  factory FileMetadata.fromJson(Map<String, dynamic> json) {
    return FileMetadata(
      fileName: json['fileName'] as String? ?? '',
      sourceUrl: json['sourceUrl'] as String? ?? '',
      fetchedUrl: json['fetchedUrl'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int)
          : DateTime.now(),
      fileSize: json['fileSize'] as int? ?? 0,
      sha256Hash: json['sha256Hash'] as String? ?? '',
      sourceHash: json['sourceHash'] as String? ?? (json['sha256Hash'] as String? ?? ''),
      unlockedHash: json['unlockedHash'] as String?,
      unlockMethod: json['unlockMethod'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'fileName': fileName,
        'sourceUrl': sourceUrl,
        'fetchedUrl': fetchedUrl,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'fileSize': fileSize,
        'sha256Hash': sha256Hash,
        'sourceHash': sourceHash,
        if (unlockedHash != null) 'unlockedHash': unlockedHash,
        if (unlockMethod != null) 'unlockMethod': unlockMethod,
      };

  String get formattedTimestamp {
    return '${timestamp.year}-${_pad(timestamp.month)}-${_pad(timestamp.day)} '
        '${_pad(timestamp.hour)}:${_pad(timestamp.minute)}:${_pad(timestamp.second)}';
  }

  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(2)} KB';
    if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Verify integrity of unlocked/processed content (Step 4 onwards)
  bool verifyIntegrity(List<int> fileBytes) {
    final computed = sha256.convert(fileBytes).toString();
    
    // If file was unlocked, verify against unlockedHash
    if (unlockedHash != null) {
      return computed.toLowerCase() == unlockedHash!.toLowerCase();
    }
    
    // Otherwise verify against sourceHash (or sha256Hash for backwards compat)
    return computed.toLowerCase() == sourceHash.toLowerCase();
  }

  /// Create a copy with unlockedHash set (for password-protected files)
  /// Step 3: After unlocking, compute hash of unlocked content
  FileMetadata withUnlocked(List<int> unlockedBytes) {
    final unlockedHashValue = sha256.convert(unlockedBytes).toString();
    return FileMetadata(
      fileName: fileName,
      sourceUrl: sourceUrl,
      fetchedUrl: fetchedUrl,
      timestamp: timestamp,
      fileSize: fileSize,
      sha256Hash: sha256Hash,
      sourceHash: sourceHash,
      unlockedHash: unlockedHashValue,
      unlockMethod: 'in-session',
    );
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}
