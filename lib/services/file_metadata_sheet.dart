import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:genuport/services/encryption_service.dart';
import 'package:genuport/services/file_metadata.dart';
import 'package:genuport/themes/gp_colors.dart';

class FileMetadataSheet extends StatefulWidget {
  final File file;
  final String displayName;

  const FileMetadataSheet({required this.file, required this.displayName, super.key});

  @override
  State<FileMetadataSheet> createState() => _FileMetadataSheetState();
}

class _FileMetadataSheetState extends State<FileMetadataSheet> {
  FileMetadata? _meta;
  bool _loading = true;
  bool? _integrityOk;
  bool _checkingIntegrity = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
  try {
    final encBytes = await widget.file.readAsBytes();
    final result   = await EncryptionService().decryptFileWithMeta(encBytes);
    final metaMap  = result.metadata;
    if (metaMap.isNotEmpty) {
      final meta = FileMetadata.fromJson(metaMap);
      print('📋 [METADATA_SHEET] Loaded metadata for display:');
      print('   • File: ${widget.displayName}');
      print('   • fileName: ${meta.fileName}');
      print('   • sourceUrl: ${meta.sourceUrl}');
      print('   • fetchedUrl: ${meta.fetchedUrl}');
      print('   • timestamp: ${meta.formattedTimestamp}');
      print('   • fileSize: ${meta.formattedSize}');
      print('   • hash: ${meta.sha256Hash}');
      if (mounted) setState(() { _meta = meta; _loading = false; });
    } else {
      print('⚠️  [METADATA_SHEET] No metadata found in file');
      if (mounted) setState(() { _loading = false; }); // no metadata
    }
  } catch (e) {
    print('❌ [METADATA_SHEET] Error loading metadata: $e');
    if (mounted) setState(() { _loading = false; });
  }
}
Future<void> _checkIntegrity() async {
  if (_meta == null) return;
  setState(() => _checkingIntegrity = true);
  try {
    final encBytes = await widget.file.readAsBytes();
    final result   = await EncryptionService().decryptFileWithMeta(encBytes);
    final ok       = _meta!.verifyIntegrity(result.bytes);
    print('🔐 [METADATA_SHEET] Integrity check:');
    print('   • Expected hash: ${_meta!.sha256Hash}');
    print('   • File matches: $ok');
    if (mounted) setState(() { _integrityOk = ok; _checkingIntegrity = false; });
  } catch (e) {
    print('❌ [METADATA_SHEET] Integrity check failed: $e');
    if (mounted) setState(() { _integrityOk = false; _checkingIntegrity = false; });
  }
}

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: GPColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            decoration: BoxDecoration(color: GPColors.border, borderRadius: BorderRadius.circular(2)),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.info_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('File Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: GPColors.textPrimary)),
                  Text(widget.displayName, style: const TextStyle(fontSize: 12, color: GPColors.textSecondary), overflow: TextOverflow.ellipsis),
                ]),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: GPColors.textMuted, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),

          Divider(height: 24, indent: 20, endIndent: 20, color: GPColors.border),

          if (_loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: GPColors.primaryLight),
            )
          else if (_meta == null)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(children: [
                const Icon(Icons.info_outline_rounded, color: GPColors.textMuted, size: 32),
                const SizedBox(height: 12),
                const Text('No metadata available', style: TextStyle(fontSize: 14, color: GPColors.textSecondary)),
                const SizedBox(height: 4),
                const Text('This file was downloaded before metadata tracking was added.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: GPColors.textMuted, height: 1.4)),
              ]),
            )
          else
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: Column(children: [
                  _card([
                    _metaRow(Icons.calendar_today_rounded, 'Downloaded', _meta!.formattedTimestamp),
                    _metaRow(Icons.data_usage_rounded, 'File Size', _meta!.formattedSize),
                  ]),
                  const SizedBox(height: 12),
                  _card([
                    _metaRowCopyable(Icons.language_rounded, 'Source URL', _meta!.sourceUrl),
                    Divider(height: 1, color: GPColors.border.withOpacity(0.6)),
                    _metaRowCopyable(Icons.download_rounded, 'Fetched URL', _meta!.fetchedUrl),
                  ]),
                  const SizedBox(height: 12),
                  _card([
                    _metaRowCopyable(Icons.tag_rounded, 'SHA-256 Hash', _meta!.sha256Hash, mono: true),
                  ]),
                  const SizedBox(height: 12),

                  // Integrity check
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _integrityOk == null
                          ? GPColors.surfacePage
                          : _integrityOk!
                              ? GPColors.surfaceTint
                              : GPColors.errorSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _integrityOk == null
                            ? GPColors.border
                            : _integrityOk!
                                ? GPColors.borderGreen
                                : GPColors.errorBorder,
                      ),
                    ),
                    child: Row(children: [
                      Icon(
                        _integrityOk == null
                            ? Icons.security_rounded
                            : _integrityOk!
                                ? Icons.verified_rounded
                                : Icons.gpp_bad_rounded,
                        color: _integrityOk == null
                            ? GPColors.textMuted
                            : _integrityOk!
                                ? GPColors.primaryLight
                                : GPColors.error,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(
                          _integrityOk == null
                              ? 'File Integrity'
                              : _integrityOk!
                                  ? 'Not Tampered'
                                  : 'Tampered / Corrupted',
                          style: TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w600,
                            color: _integrityOk == null
                                ? GPColors.textPrimary
                                : _integrityOk!
                                    ? GPColors.primary
                                    : GPColors.error,
                          ),
                        ),
                        Text(
                          _integrityOk == null
                              ? 'Verify the file has not been altered'
                              : _integrityOk!
                                  ? 'SHA-256 matches original download'
                                  : 'Hash mismatch — file may be corrupt',
                          style: const TextStyle(fontSize: 11.5, color: GPColors.textSecondary),
                        ),
                      ])),
                      const SizedBox(width: 8),
                      if (_integrityOk == null)
                        SizedBox(
                          height: 34,
                          child: ElevatedButton(
                            onPressed: _checkingIntegrity ? null : _checkIntegrity,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: GPColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: _checkingIntegrity
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Verify', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                        ),
                    ]),
                  ),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: GPColors.surfacePage,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GPColors.border),
      ),
      child: Column(children: children),
    );
  }

  Widget _metaRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Icon(icon, size: 14, color: GPColors.textMuted),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12.5, color: GPColors.textSecondary)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: GPColors.textPrimary)),
      ]),
    );
  }

  Widget _metaRowCopyable(IconData icon, String label, String value, {bool mono = false}) {
    final isLong = value.length > 30;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 14, color: GPColors.textMuted),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12.5, color: GPColors.textSecondary)),
          const Spacer(),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$label copied', style: const TextStyle(fontSize: 13)),
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  backgroundColor: GPColors.primary,
                ),
              );
            },
            child: const Icon(Icons.copy_rounded, size: 14, color: GPColors.primaryLight),
          ),
        ]),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 11.5,
            fontFamily: mono ? 'monospace' : null,
            color: GPColors.textPrimary,
            height: 1.4,
          ),
          maxLines: isLong ? 3 : 2,
          overflow: TextOverflow.ellipsis,
        ),
      ]),
    );
  }
}