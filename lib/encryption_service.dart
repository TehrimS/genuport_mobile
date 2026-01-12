import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt_pkg;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';

class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  final _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  static const String _keyStorageKey = 'bank_statements_encryption_key';
  static const String _ivStorageKey = 'bank_statements_encryption_iv';

  encrypt_pkg.Key? _encryptionKey;
  encrypt_pkg.IV? _iv;

  /// Initialize or retrieve the encryption key
  Future<void> initialize() async {
    try {
      // Try to retrieve existing key
      String? storedKey = await _secureStorage.read(key: _keyStorageKey);
      String? storedIV = await _secureStorage.read(key: _ivStorageKey);

      if (storedKey != null && storedIV != null) {
        // Use existing key
        _encryptionKey = encrypt_pkg.Key.fromBase64(storedKey);
        _iv = encrypt_pkg.IV.fromBase64(storedIV);
        print('🔑 Retrieved existing encryption key');
      } else {
        // Generate new key
        await _generateNewKey();
        print('🔑 Generated new encryption key');
      }
    } catch (e) {
      print('❌ Error initializing encryption: $e');
      // If there's any error, generate a new key
      await _generateNewKey();
    }
  }

  /// Generate a new encryption key and IV
  Future<void> _generateNewKey() async {
    _encryptionKey = encrypt_pkg.Key.fromSecureRandom(32); // 256-bit key
    _iv = encrypt_pkg.IV.fromSecureRandom(16); // 128-bit IV

    // Store securely
    await _secureStorage.write(
      key: _keyStorageKey,
      value: _encryptionKey!.base64,
    );
    await _secureStorage.write(
      key: _ivStorageKey,
      value: _iv!.base64,
    );
  }

  /// Encrypt file bytes
  Future<Uint8List> encryptFile(Uint8List fileBytes) async {
    if (_encryptionKey == null || _iv == null) {
      await initialize();
    }

    try {
      final encrypter = encrypt_pkg.Encrypter(
        encrypt_pkg.AES(_encryptionKey!, mode: encrypt_pkg.AESMode.cbc),
      );

      // Encrypt the file bytes
      final encrypted = encrypter.encryptBytes(fileBytes, iv: _iv!);

      // Add a custom header to identify encrypted files
      final header = utf8.encode('GENUP_ENC_V1:');
      final result = Uint8List.fromList([...header, ...encrypted.bytes]);

      print('🔒 File encrypted successfully (${fileBytes.length} → ${result.length} bytes)');
      return result;
    } catch (e) {
      print('❌ Encryption error: $e');
      throw Exception('Failed to encrypt file: $e');
    }
  }

  /// Decrypt file bytes
  Future<Uint8List> decryptFile(Uint8List encryptedBytes) async {
    if (_encryptionKey == null || _iv == null) {
      await initialize();
    }

    try {
      // Check for our custom header
      final header = utf8.encode('GENUP_ENC_V1:');
      final hasHeader = encryptedBytes.length > header.length &&
          _bytesEqual(
            encryptedBytes.sublist(0, header.length),
            header,
          );

      Uint8List dataToDecrypt;
      if (hasHeader) {
        // Remove header before decryption
        dataToDecrypt = encryptedBytes.sublist(header.length);
      } else {
        // File might not be encrypted (legacy file)
        print('⚠️ File does not have encryption header, might be unencrypted');
        return encryptedBytes;
      }

      final encrypter = encrypt_pkg.Encrypter(
        encrypt_pkg.AES(_encryptionKey!, mode: encrypt_pkg.AESMode.cbc),
      );

      final encrypted = encrypt_pkg.Encrypted(dataToDecrypt);
      final decrypted = encrypter.decryptBytes(encrypted, iv: _iv!);

      print('🔓 File decrypted successfully (${encryptedBytes.length} → ${decrypted.length} bytes)');
      return Uint8List.fromList(decrypted);
    } catch (e) {
      print('❌ Decryption error: $e');
      throw Exception('Failed to decrypt file: $e');
    }
  }

  /// Check if a file is encrypted
  bool isFileEncrypted(Uint8List fileBytes) {
    final header = utf8.encode('GENUP_ENC_V1:');
    if (fileBytes.length < header.length) return false;

    return _bytesEqual(
      fileBytes.sublist(0, header.length),
      header,
    );
  }

  /// Helper to compare byte arrays
  bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Generate a hash of the file for integrity verification (optional)
  String generateFileHash(Uint8List fileBytes) {
    final digest = sha256.convert(fileBytes);
    return digest.toString();
  }

  /// Clear all encryption keys (use with caution!)
  Future<void> resetEncryption() async {
    await _secureStorage.delete(key: _keyStorageKey);
    await _secureStorage.delete(key: _ivStorageKey);
    _encryptionKey = null;
    _iv = null;
    print('🔄 Encryption keys cleared');
  }
}