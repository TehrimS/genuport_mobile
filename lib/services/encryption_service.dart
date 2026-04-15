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
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const String _keyStorageKey = 'encryption_key';
  static const String _ivStorageKey = 'encryption_iv';
  // Header: 13 bytes "GENUP_ENC_V1:"
  static final List<int> _header = utf8.encode('GENUP_ENC_V1:');

  encrypt_pkg.Key? _encryptionKey;
  encrypt_pkg.IV? _iv;

  Future<void> initialize() async {
    try {
      String? storedKey = await _secureStorage.read(key: _keyStorageKey);
      String? storedIV  = await _secureStorage.read(key: _ivStorageKey);
      if (storedKey != null && storedIV != null) {
        _encryptionKey = encrypt_pkg.Key.fromBase64(storedKey);
        _iv = encrypt_pkg.IV.fromBase64(storedIV);
      } else {
        await _generateNewKey();
      }
    } catch (e) {
      await _generateNewKey();
    }
  }

  Future<void> _generateNewKey() async {
    _encryptionKey = encrypt_pkg.Key.fromSecureRandom(32);
    _iv = encrypt_pkg.IV.fromSecureRandom(16);
    await _secureStorage.write(key: _keyStorageKey, value: _encryptionKey!.base64);
    await _secureStorage.write(key: _ivStorageKey,  value: _iv!.base64);
  }

  /// Encrypt file bytes, optionally embedding metadata JSON inline.
  /// File format: [header 13B][metaLen 4B big-endian][metaJSON nB][encryptedBytes]
  Future<Uint8List> encryptFile(Uint8List fileBytes, {Map<String, dynamic>? metadata}) async {
    if (_encryptionKey == null || _iv == null) await initialize();

    final encrypter = encrypt_pkg.Encrypter(
      encrypt_pkg.AES(_encryptionKey!, mode: encrypt_pkg.AESMode.cbc),
    );
    final encrypted = encrypter.encryptBytes(fileBytes, iv: _iv!);

    // Serialize metadata (empty object if none provided)
    final metaJson  = utf8.encode(jsonEncode(metadata ?? {}));
    final metaLen   = metaJson.length;

    // 4-byte big-endian length prefix for metadata
    final metaLenBytes = Uint8List(4)
      ..[0] = (metaLen >> 24) & 0xFF
      ..[1] = (metaLen >> 16) & 0xFF
      ..[2] = (metaLen >> 8)  & 0xFF
      ..[3] =  metaLen        & 0xFF;

    return Uint8List.fromList([
      ..._header,
      ...metaLenBytes,
      ...metaJson,
      ...encrypted.bytes,
    ]);
  }

  /// Decrypt file bytes. Returns decrypted bytes and embedded metadata.
  Future<({Uint8List bytes, Map<String, dynamic> metadata})> decryptFileWithMeta(
      Uint8List encryptedBytes) async {
    if (_encryptionKey == null || _iv == null) await initialize();

    final hLen = _header.length; // 13

    // Validate header
    if (encryptedBytes.length < hLen + 4) {
      throw Exception('File too short to be a valid encrypted file');
    }
    if (!_bytesEqual(encryptedBytes.sublist(0, hLen), _header)) {
      // Legacy file without metadata — just decrypt as-is
      return (bytes: await _decryptLegacy(encryptedBytes), metadata: <String, dynamic>{});
    }

    // Read 4-byte metadata length
    int metaLen = (encryptedBytes[hLen]     << 24) |
                  (encryptedBytes[hLen + 1] << 16) |
                  (encryptedBytes[hLen + 2] << 8)  |
                   encryptedBytes[hLen + 3];

    final metaStart = hLen + 4;
    final dataStart = metaStart + metaLen;

    if (dataStart > encryptedBytes.length) {
      throw Exception('Corrupted file: metadata length exceeds file size');
    }

    // Parse metadata
    Map<String, dynamic> meta = {};
    try {
      final metaBytes = encryptedBytes.sublist(metaStart, dataStart);
      meta = jsonDecode(utf8.decode(metaBytes)) as Map<String, dynamic>;
      print('📖 [METADATA] Extracted metadata from encrypted file:');
      print('   • Metadata length: $metaLen bytes');
      print('   • Metadata content: $meta');
    } catch (e) {
      print('⚠️  [METADATA] Failed to extract metadata: $e');
    }

    // Decrypt
    final encrypter = encrypt_pkg.Encrypter(
      encrypt_pkg.AES(_encryptionKey!, mode: encrypt_pkg.AESMode.cbc),
    );
    final dataBytes = encryptedBytes.sublist(dataStart);
    final decrypted = encrypter.decryptBytes(encrypt_pkg.Encrypted(dataBytes), iv: _iv!);

    return (bytes: Uint8List.fromList(decrypted), metadata: meta);
  }

  /// Convenience wrapper — returns only decrypted bytes (for callers that don't need metadata).
  Future<Uint8List> decryptFile(Uint8List encryptedBytes) async {
    final result = await decryptFileWithMeta(encryptedBytes);
    return result.bytes;
  }

  Future<Uint8List> _decryptLegacy(Uint8List encryptedBytes) async {
    final hLen = _header.length;
    final hasOldHeader = encryptedBytes.length > hLen &&
        _bytesEqual(encryptedBytes.sublist(0, hLen), _header);
    final dataToDecrypt = hasOldHeader
        ? encryptedBytes.sublist(hLen)
        : encryptedBytes;
    final encrypter = encrypt_pkg.Encrypter(
      encrypt_pkg.AES(_encryptionKey!, mode: encrypt_pkg.AESMode.cbc),
    );
    return Uint8List.fromList(
      encrypter.decryptBytes(encrypt_pkg.Encrypted(dataToDecrypt), iv: _iv!),
    );
  }

  bool isFileEncrypted(Uint8List fileBytes) {
    if (fileBytes.length < _header.length) return false;
    return _bytesEqual(fileBytes.sublist(0, _header.length), _header);
  }

  bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  String generateFileHash(Uint8List fileBytes) => sha256.convert(fileBytes).toString();

  Future<void> resetEncryption() async {
    await _secureStorage.delete(key: _keyStorageKey);
    await _secureStorage.delete(key: _ivStorageKey);
    _encryptionKey = null;
    _iv = null;
  }
}