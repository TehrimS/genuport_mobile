import 'dart:io';
import 'package:flutter/material.dart';
import 'package:inapp_download_demo/services/encryption_service.dart';
import 'package:inapp_download_demo/services/pdf_unlocker.dart';
import 'package:inapp_download_demo/themes/gp_colors.dart';
import 'package:path_provider/path_provider.dart';
import 'pdf_viewer_page.dart';


class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  final _encryptionService = EncryptionService();
  bool _isInitialized = false;
  bool _isSelecting = false;
  final Set<String> _selectedPaths = {};

  @override
  void initState() {
    super.initState();
    _initEncryption();
  }

  Future<void> _initEncryption() async {
    try {
      await _encryptionService.initialize();
      setState(() => _isInitialized = true);
    } catch (e) {
      print('Failed to initialize encryption: $e');
    }
  }

  Future<List<File>> _getFiles() async {
    final dir = Platform.isAndroid
        ? Directory('/storage/emulated/0/Download/GenuPortDownloads')
        : Directory(
            '${(await getApplicationDocumentsDirectory()).path}/GenuPortDownloads',
          );

    if (!await dir.exists()) return [];
    try {
      return dir.listSync().whereType<File>().toList()
        ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    } catch (_) {
      return [];
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) {
      if (diff.inHours == 0) return '${diff.inMinutes}m ago';
      return '${diff.inHours}h ago';
    }
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  String _displayName(String fileName) =>
      fileName.endsWith('.enc') ? fileName.substring(0, fileName.length - 4) : fileName;

  bool _isPdf(String name) => name.toLowerCase().endsWith('.pdf');

  Future<void> _deleteSelected(List<File> allFiles) async {
    final count = _selectedPaths.length;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.delete_sweep_rounded, color: Color(0xFFE53935), size: 22),
                  SizedBox(width: 10),
                  Text('Delete Files', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: GPColors.textPrimary)),
                ]),
                const SizedBox(height: 12),
                Text(
                  'Delete $count selected file${count > 1 ? 's' : ''}?\nThis cannot be undone.',
                  style: const TextStyle(fontSize: 13.5, color: GPColors.textMuted, height: 1.5),
                ),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: GPColors.textMuted,
                        side: const BorderSide(color: GPColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE53935),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text('Delete $count', style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirmed == true) {
      for (final path in _selectedPaths) {
        try { await File(path).delete(); } catch (_) {}
      }
      setState(() {
        _selectedPaths.clear();
        _isSelecting = false;
      });
    }
  }

  Future<String?> _askPdfPassword() async {
    final tc = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──
                Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: GPColors.surfaceTint,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: GPColors.border),
                      ),
                      child: const Icon(Icons.lock_rounded, color: GPColors.primaryMid, size: 18),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PDF Password',
                          style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700,
                            color: GPColors.textPrimary,
                          ),
                        ),
                        Text(
                          'This document is protected',
                          style: TextStyle(fontSize: 11, color: GPColors.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Input ──
                TextField(
                  controller: tc,
                  obscureText: true,
                  autofocus: true,
                  style: const TextStyle(fontSize: 14, color: GPColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Enter password…',
                    hintStyle: const TextStyle(color: GPColors.textMuted, fontSize: 14),
                    prefixIcon: const Icon(Icons.key_rounded, color: GPColors.primaryMid, size: 18),
                    filled: true,
                    fillColor: GPColors.surfaceTint,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: GPColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: GPColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: GPColors.primaryLight, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Hint box ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: GPColors.surfaceTint,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: GPColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 13, color: GPColors.primaryLight),
                          const SizedBox(width: 5),
                          const Text(
                            'Common bank passwords',
                            style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 12,
                              color: GPColors.primaryMid,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text('• Date of Birth: DDMMYYYY', style: TextStyle(fontSize: 12, color: GPColors.textMuted)),
                      const Text('• PAN Card number', style: TextStyle(fontSize: 12, color: GPColors.textMuted)),
                      const Text('• "password" / "statement"', style: TextStyle(fontSize: 12, color: GPColors.textMuted)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Actions ──
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, null),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: GPColors.textMuted,
                          side: const BorderSide(color: GPColors.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: const Text('Cancel', style: TextStyle(fontSize: 14)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, tc.text),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GPColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock_open_rounded, size: 15),
                            SizedBox(width: 6),
                            Text('Unlock', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLoadingDialog(String msg) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: GPColors.primaryLight),
                ),
                const SizedBox(width: 16),
                Text(msg, style: const TextStyle(color: GPColors.textPrimary, fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openFile(File file, String displayName, bool isEncrypted) async {
    if (!_isPdf(displayName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only PDF files can be viewed')),
      );
      return;
    }

    _showLoadingDialog('Decrypting…');

    try {
      File fileToView;

      if (isEncrypted) {
        if (!_isInitialized) throw Exception('Encryption service not initialized');
        final encryptedBytes = await file.readAsBytes();
        var decryptedBytes = await _encryptionService.decryptFile(encryptedBytes);

        if (PdfUnlocker.isPasswordProtected(decryptedBytes)) {
          if (context.mounted) Navigator.pop(context);

          final password = await _askPdfPassword();
          if (password == null || password.isEmpty) return;

          if (context.mounted) _showLoadingDialog('Unlocking PDF…');

          var unlockedBytes = await PdfUnlocker.unlockPdf(decryptedBytes, password);
          if (unlockedBytes == null) {
            unlockedBytes = await PdfUnlocker.tryUnlockWithCommonPasswords(
              decryptedBytes, dob: password, pan: password,
            );
          }

          if (unlockedBytes == null) {
            if (context.mounted) Navigator.pop(context);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('❌ Wrong password. Cannot unlock PDF.'),
                  backgroundColor: Color(0xFFE53935),
                ),
              );
            }
            return;
          }

          decryptedBytes = unlockedBytes;
          try {
            final reEncrypted = await _encryptionService.encryptFile(decryptedBytes);
            await file.writeAsBytes(reEncrypted);
          } catch (_) {}
        }

        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/${displayName}_view.pdf');
        await tempFile.writeAsBytes(decryptedBytes);
        fileToView = tempFile;
      } else {
        fileToView = file;
      }

      if (context.mounted) Navigator.pop(context);

      if (context.mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PdfViewerPage(file: fileToView)),
        );
        if (isEncrypted) {
          try { await fileToView.delete(); } catch (_) {}
        }
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GPColors.surface,
      appBar: AppBar(
        backgroundColor: GPColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: GPColors.primaryMid, size: 20),
          onPressed: () {
            if (_isSelecting) {
              setState(() { _isSelecting = false; _selectedPaths.clear(); });
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: _isSelecting
            ? Text(
                '${_selectedPaths.length} selected',
                style: const TextStyle(
                  color: GPColors.primary, fontWeight: FontWeight.w600, fontSize: 16,
                ),
              )
            : Row(
                children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [GPColors.primaryMid, GPColors.primary],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Icon(Icons.shield_rounded, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Downloads',
                    style: TextStyle(color: GPColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 17),
                  ),
                ],
              ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: GPColors.border),
        ),
        actions: [
          if (_isSelecting && _selectedPaths.isNotEmpty)
            FutureBuilder<List<File>>(
              future: _getFiles(),
              builder: (ctx, snap) => IconButton(
                icon: const Icon(Icons.delete_rounded, color: Color(0xFFE53935)),
                onPressed: () => _deleteSelected(snap.data ?? []),
              ),
            ),
          if (!_isSelecting)
            IconButton(
              icon: const Icon(Icons.info_outline_rounded, color: GPColors.primaryMid),
              onPressed: _showInfoDialog,
            ),
        ],
      ),
      body: FutureBuilder<List<File>>(
        future: _getFiles(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: GPColors.primaryLight),
            );
          }

          final files = snapshot.data!;

          if (files.isEmpty) {
            return _buildEmptyState();
          }

          return Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: GPColors.surfaceTint,
                child: Row(
                  children: [
                    Icon(Icons.folder_rounded, size: 14, color: GPColors.primaryLight),
                    const SizedBox(width: 6),
                    Text(
                      '${files.length} file${files.length != 1 ? 's' : ''} · GenuPortDownloads',
                      style: const TextStyle(fontSize: 12, color: GPColors.textMuted),
                    ),
                    const Spacer(),
                    if (!_isSelecting)
                      GestureDetector(
                        onTap: () => setState(() => _isSelecting = true),
                        child: const Text(
                          'Select',
                          style: TextStyle(fontSize: 12, color: GPColors.primaryMid, fontWeight: FontWeight.w600),
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            if (_selectedPaths.length == files.length) {
                              _selectedPaths.clear();
                            } else {
                              _selectedPaths.addAll(files.map((f) => f.path));
                            }
                          });
                        },
                        child: Text(
                          _selectedPaths.length == files.length ? 'Deselect All' : 'Select All',
                          style: const TextStyle(fontSize: 12, color: GPColors.primaryMid, fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
              ),

              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: files.length,
                  itemBuilder: (context, index) {
                    final file = files[index];
                    final fileName = file.path.split('/').last;
                    final displayName = _displayName(fileName);
                    final isEncrypted = fileName.endsWith('.enc');
                    final isSelected = _selectedPaths.contains(file.path);

                    return _buildFileCard(
                      file: file,
                      displayName: displayName,
                      isEncrypted: isEncrypted,
                      isSelected: isSelected,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFileCard({
    required File file,
    required String displayName,
    required bool isEncrypted,
    required bool isSelected,
  }) {
    final size = _formatSize(file.lengthSync());
    final date = _formatDate(file.statSync().modified);
    final isPdf = _isPdf(displayName);

    return Dismissible(
      key: Key(file.path),
      direction: DismissDirection.endToStart,
      onDismissed: (_) async {
        try { await file.delete(); } catch (_) {}
        setState(() {});
      },
      confirmDismiss: (_) async {
        final confirm = await showDialog<bool>(
          context: context,
          barrierColor: Colors.black.withOpacity(0.45),
          builder: (_) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.delete_outline_rounded, color: Color(0xFFE53935), size: 22),
                      SizedBox(width: 10),
                      Text('Delete File', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: GPColors.textPrimary)),
                    ]),
                    const SizedBox(height: 12),
                    Text(
                      'Delete "$displayName"?\nThis cannot be undone.',
                      style: const TextStyle(fontSize: 13.5, color: GPColors.textMuted, height: 1.5),
                    ),
                    const SizedBox(height: 20),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: GPColors.textMuted,
                            side: const BorderSide(color: GPColors.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE53935),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        );
        return confirm ?? false;
      },
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_rounded, color: Color(0xFFE53935), size: 24),
            SizedBox(height: 4),
            Text('Delete', style: TextStyle(color: Color(0xFFE53935), fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      child: GestureDetector(
        onTap: () {
          if (_isSelecting) {
            setState(() {
              if (isSelected) {
                _selectedPaths.remove(file.path);
                if (_selectedPaths.isEmpty) _isSelecting = false;
              } else {
                _selectedPaths.add(file.path);
              }
            });
          } else {
            _openFile(file, displayName, isEncrypted);
          }
        },
        onLongPress: () {
          setState(() {
            _isSelecting = true;
            _selectedPaths.add(file.path);
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFE8F5E9) : GPColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? GPColors.primaryLight : GPColors.border,
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected ? [] : [
              BoxShadow(
                color: GPColors.primary.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // File icon
                if (_isSelecting)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: isSelected ? GPColors.primaryLight : GPColors.border,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isSelected ? Icons.check_rounded : Icons.circle_outlined,
                      color: isSelected ? Colors.white : GPColors.textMuted,
                      size: 20,
                    ),
                  )
                else
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 40, height: 44,
                        decoration: BoxDecoration(
                          color: isPdf
                              ? const Color(0xFFFFF3E0)
                              : GPColors.surfaceTint,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isPdf ? const Color(0xFFFFCC80) : GPColors.border,
                          ),
                        ),
                        child: Icon(
                          isPdf ? Icons.picture_as_pdf_rounded : Icons.insert_drive_file_rounded,
                          color: isPdf ? Colors.orange.shade700 : GPColors.primaryMid,
                          size: 22,
                        ),
                      ),
                      if (isEncrypted)
                        Positioned(
                          right: -4, bottom: -4,
                          child: Container(
                            width: 18, height: 18,
                            decoration: BoxDecoration(
                              color: GPColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: const Icon(Icons.lock_rounded, size: 10, color: Colors.white),
                          ),
                        ),
                    ],
                  ),

                const SizedBox(width: 12),

                // File info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: GPColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '$size · $date',
                            style: const TextStyle(fontSize: 11.5, color: GPColors.textMuted),
                          ),
                          if (isEncrypted) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: GPColors.border),
                              ),
                              child: const Text(
                                '🔒 Encrypted',
                                style: TextStyle(
                                  fontSize: 10, color: GPColors.primaryMid,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Actions
                if (!_isSelecting && isPdf)
                  GestureDetector(
                    onTap: () => _openFile(file, displayName, isEncrypted),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: GPColors.surfaceTint,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: GPColors.border),
                      ),
                      child: const Text(
                        'Open',
                        style: TextStyle(
                          fontSize: 12, color: GPColors.primaryMid,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: GPColors.surfaceTint,
              shape: BoxShape.circle,
              border: Border.all(color: GPColors.border, width: 1.5),
            ),
            child: const Icon(Icons.folder_open_rounded, size: 40, color: GPColors.accent),
          ),
          const SizedBox(height: 20),
          const Text(
            'No downloads yet',
            style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w700, color: GPColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Files you download will appear here,\nencrypted and secured.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: GPColors.textMuted, height: 1.5),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: GPColors.surfaceTint,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: GPColors.border),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_rounded, size: 14, color: GPColors.primaryLight),
                SizedBox(width: 6),
                Text(
                  'All files are AES-256 encrypted',
                  style: TextStyle(fontSize: 12, color: GPColors.primaryMid),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [GPColors.primaryMid, GPColors.primary],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.shield_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Secure Downloads',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: GPColors.textPrimary),
                  ),
                ]),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: GPColors.surfaceTint,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: GPColors.border),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(
                    children: [
                      _infoRow(Icons.folder_rounded, 'Saved to GenuPortDownloads'),
                      _infoRow(Icons.lock_rounded, 'AES-256 encrypted at rest'),
                      _infoRow(Icons.visibility_rounded, 'Decrypted only when viewing'),
                      _infoRow(Icons.key_rounded, 'PDF passwords removed after unlock'),
                      _infoRow(Icons.block_rounded, 'Cannot be opened by other apps'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GPColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: const Text('Got it', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 16, color: GPColors.primaryLight),
          const SizedBox(width: 10),
          Text(text, style: const TextStyle(fontSize: 13, color: GPColors.textPrimary)),
        ],
      ),
    );
  }
}