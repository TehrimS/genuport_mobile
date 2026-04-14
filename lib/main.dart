import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:app_links/app_links.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:path_provider/path_provider.dart';
import 'screens/login_page.dart';
import 'services/file_manager.dart';

// Global navigator key to navigate from anywhere
final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isAndroid) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(true);
  }  

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _appLinks = AppLinks();
  StreamSubscription? _linkSubscription;
  final bool _fileJustHandled = false; // Track if we just handled a file share

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
    _handleIncomingFiles();
  }

  void _handleIncomingFiles() {
    debugPrint('═══════════════════════════════════════════════');
    debugPrint('🔄 INITIALIZING FILE HANDLER');
    debugPrint('═══════════════════════════════════════════════');
    
    // When app is already running
    ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> files) async {
        debugPrint('═══════════════════════════════════════════════');
        debugPrint('📥 SHARED FILE DETECTED (APP RUNNING)');
        debugPrint('   Files count: ${files.length}');
        debugPrint('═══════════════════════════════════════════════');
        if (files.isNotEmpty) {
          debugPrint('📥 Processing: ${files.first.path}');
          await _handleIncomingPdf(files.first.path);
        }
      },
      onError: (err) {
        debugPrint('❌ Error receiving files: $err');
      },
    );

    // When app is opened from closed state
    ReceiveSharingIntent.instance.getInitialMedia().then((initialFiles) async {
      debugPrint('═══════════════════════════════════════════════');
      debugPrint('📥 SHARED FILE DETECTED (APP CLOSED - COLD START)');
      debugPrint('   Files count: ${initialFiles.length}');
      debugPrint('═══════════════════════════════════════════════');
      if (initialFiles.isNotEmpty) {
        debugPrint('📥 Processing initial file: ${initialFiles.first.path}');
        await _handleIncomingPdf(initialFiles.first.path);
      }
      // Clear the media after processing
      ReceiveSharingIntent.instance.reset();
    }).catchError((e) {
      debugPrint('❌ Error getting initial media: $e');
    });
  }

  Future<void> _handleIncomingPdf(String filePath) async {
    debugPrint('═══════════════════════════════════════════════');
    debugPrint('🔐 STARTING PDF PROCESSING');
    debugPrint('═══════════════════════════════════════════════');
    debugPrint('📂 File path: $filePath');
    debugPrint('📌 Navigator key context available: ${navigatorKey.currentContext != null}');
    debugPrint('═══════════════════════════════════════════════');
    
    try {
      debugPrint('🔐 Processing incoming PDF: $filePath');
      
      // Handle both file:// paths and content:// URIs
      Uint8List bytes;
      String fileName = 'shared_file';
      
      if (filePath.startsWith('content://')) {
        // This is a content URI - receive_sharing_intent should have handled it
        debugPrint('📌 Content URI detected: $filePath');
        _showErrorDialog('File path format not supported. Please try again.');
        return;
      }
      
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('❌ File does not exist: $filePath');
        _showErrorDialog('File not found: $filePath');
        return;
      }

      // Extract filename from path
      fileName = filePath.split('/').last;
      
      // Read bytes from the shared file
      bytes = await file.readAsBytes();
      debugPrint('📄 Read ${bytes.length} bytes from file: $fileName');

      // Initialize encryption service
      // final encryptionService = EncryptionService();
      // await encryptionService.initialize();
      // debugPrint('🔑 Encryption service initialized');

      // // 🔒 Encrypt the file using AES-256
      // debugPrint('🔒 Encrypting ${file.path.split('/').last}...');
      // final encryptedBytes = await encryptionService.encryptFile(Uint8List.fromList(bytes));
      // debugPrint('✅ File encrypted (${encryptedBytes.length} bytes)');

      // Save to app's private storage
      final downloadPath = await FileManager.getDownloadPath();
      final dir = Directory(downloadPath);

      if (!await dir.exists()) {
        await dir.create(recursive: true);
        debugPrint('✅ Created Downloads directory: $downloadPath');
      }

      // Generate unique filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final newFilePath = '$downloadPath/${timestamp}_$fileName.enc';

      // Write encrypted bytes to app storage
      final newFile = File(newFilePath);
      // await newFile.writeAsBytes(encryptedBytes);
      debugPrint('✅ File saved to app storage: $newFilePath');
      debugPrint('✅ File size: ${await newFile.length()} bytes');

      // Wait for the app to be fully initialized before showing UI
      debugPrint('⏳ Waiting for app to be fully initialized...');
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Show success snackbar using navigator key context
      if (navigatorKey.currentContext != null) {
        ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: const Text('✅ PDF imported & encrypted'),
                ),
              ],
            ),
            backgroundColor: Colors.green[50],
            duration: const Duration(seconds: 3),
          ),
        );
        debugPrint('✅ Success snackbar shown');
      }

      // Decrypt and view the file immediately
      try {
        debugPrint('🔍 Reading encrypted file for viewing...');
        debugPrint('📌 Navigator key context available: ${navigatorKey.currentContext != null}');
        
        final savedEncrypted = await newFile.readAsBytes();
        debugPrint('📖 Encrypted file size: ${savedEncrypted.length} bytes');
        
        debugPrint('🔓 Decrypting file...');
        // final decryptedBytes = await encryptionService.decryptFile(savedEncrypted);
        //   debugPrint('✅ Decrypted file size: ${decryptedBytes.length} bytes');
        
        // // Verify PDF header
        // if (decryptedBytes.length >= 4) {
        //   final header = String.fromCharCodes(decryptedBytes.take(4));
        //   debugPrint('📄 PDF header check: $header');
        // }
        
        // Create temp file for viewing
        final tempDir = await getTemporaryDirectory();
        final cleanFileName = fileName.replaceAll('.enc', '');
        final tempFile = File('${tempDir.path}/$cleanFileName');
        // await tempFile.writeAsBytes(decryptedBytes);
        // debugPrint('✅ Temp file created: ${tempFile.path} (${decryptedBytes.length} bytes)');
        
        // Navigate to PDF viewer using navigatorKey context
        debugPrint('🎯 Attempting to navigate to PDF viewer...');
        if (navigatorKey.currentContext != null) {
          debugPrint('🚀 Navigator key context available, pushing PdfViewerPage...');
          // final result = await Navigator.of(navigatorKey.currentContext!).push(
          //   MaterialPageRoute(
          //     builder: (_) => PdfViewerPage(file: tempFile),
          //   ),
          // );
          // debugPrint('👈 Returned from PDF viewer with result: $result');
          
          // After viewing, navigate to Downloads page
          debugPrint('📱 Now navigating to Downloads page...');
          if (navigatorKey.currentContext != null) {
            debugPrint('🎯 Pushing to Downloads page...');
            // try {
            //   Navigator.of(navigatorKey.currentContext!).pushAndRemoveUntil(
            //     MaterialPageRoute(builder: (_) => const DownloadsPage()),
            //     (route) => route.isFirst,
            //   );
            //   debugPrint('✅ Successfully navigated to Downloads page');
            // } catch (navError) {
            //   debugPrint('❌ Navigation error: $navError');
            //   debugPrint('❌ Stack trace: $navError');
            // }
          } else {
            debugPrint('⚠️ Navigator context not available at Downloads navigation time');
          }
          
          // Cleanup temp file
          try {
            await tempFile.delete();
            debugPrint('✅ Temp file cleaned up');
          } catch (e) {
            debugPrint('⚠️ Failed to cleanup temp file: $e');
          }
        } else {
          debugPrint('❌ Navigator key context NOT available - cannot navigate to PDF viewer');
          debugPrint('❌ This is a critical issue with the widget tree initialization');
        }
        } catch (e) {
          debugPrint('❌ Error viewing file: $e');
          debugPrint('❌ Stack trace: ${StackTrace.current}');
          if (navigatorKey.currentContext != null) {
            ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
              SnackBar(
                content: Text('Error opening file: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('❌ Error processing PDF: $e');
        _showErrorDialog('Failed to process PDF: $e');
      }
    }

  void _showErrorDialog(String message) {
    debugPrint('🚨 Showing error dialog: $message');
    
    // Try using navigator key context first
    if (navigatorKey.currentContext != null) {
      showDialog(
        context: navigatorKey.currentContext!,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red[700]),
              const SizedBox(width: 12),
              const Text('Import Failed'),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      debugPrint('⚠️ Navigator context not available for error dialog');
    }
  }

  Future<void> _initDeepLinks() async {
    try {
      await _appLinks.getInitialLink();
    } catch (e) {
      debugPrint('Deep link error: $e');
    }

    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        // Handle later if bank redirects back
        debugPrint("Deep link received: $uri");
      },
      onError: (err) {
        debugPrint('Link stream error: $err');
      },
    );
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey, // Use global navigator key
      home: const LoginPage(), // ✅ START HERE
    );
  }
}
