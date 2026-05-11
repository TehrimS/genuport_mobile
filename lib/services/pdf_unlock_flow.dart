import 'dart:typed_data';
import 'package:genuport/services/encryption_service.dart';
import 'package:genuport/services/file_metadata.dart';
import 'package:genuport/services/pdf_unlocker.dart';

/// Handles the password-protected PDF unlock flow
/// Step 2: Prompt user for password (in-session)
/// Step 3: Unlock and compute unlockedHash
class PdfUnlockFlow {
  /// Step 3: Unlock PDF and compute both hashes
  /// Returns updated metadata with sourceHash and unlockedHash, plus unlocked bytes
  static Future<({Uint8List unlockedBytes, FileMetadata updatedMetadata})> unlockPdf(
    Uint8List protectedBytes,
    FileMetadata originalMeta,
    String password,
  ) async {
    print('🔓 [PDF_UNLOCK] Starting unlock flow:');
    print('   • sourceHash (original): ${originalMeta.sourceHash.substring(0, 16)}...');
    print('   • unlockedHash: computing...');

    // Unlock the PDF with provided password
    final unlockedBytes = await PdfUnlocker.unlockPdf(protectedBytes, password);
    if (unlockedBytes == null) {
      throw Exception('Failed to unlock PDF with provided password');
    }

    print('✅ [PDF_UNLOCK] PDF unlocked successfully (${unlockedBytes.length} bytes)');

    // Step 3: Create updated metadata with unlockedHash
    final updatedMeta = originalMeta.withUnlocked(unlockedBytes);

    print('🔐 [PDF_UNLOCK] Evidence payload ready:');
    print('   • sourceHash: ${updatedMeta.sourceHash.substring(0, 16)}...');
    print('   • unlockedHash: ${updatedMeta.unlockedHash!.substring(0, 16)}...');
    print('   • unlockMethod: ${updatedMeta.unlockMethod}');

    return (unlockedBytes: unlockedBytes, updatedMetadata: updatedMeta);
  }

  /// Step 4: Re-encrypt the unlocked PDF with both hashes in metadata
  static Future<Uint8List> reEncryptUnlocked(
    Uint8List unlockedBytes,
    FileMetadata updatedMetadata,
  ) async {
    print('🔐 [PDF_UNLOCK] Step 4: Re-encrypting unlocked PDF...');
    
    final encService = EncryptionService();
    final encrypted = await encService.encryptUnlockedFile(
      unlockedBytes,
      metadata: updatedMetadata.toJson(),
    );

    print('✅ [PDF_UNLOCK] Re-encrypted with metadata:');
    print('   • sourceHash: ${updatedMetadata.sourceHash.substring(0, 16)}...');
    print('   • unlockedHash: ${updatedMetadata.unlockedHash!.substring(0, 16)}...');
    print('   • unlockMethod: ${updatedMetadata.unlockMethod}');

    return encrypted;
  }
}
