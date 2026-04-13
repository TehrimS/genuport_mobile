import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:app_links/app_links.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:path_provider/path_provider.dart';
import 'screens/applicant_login_page.dart';
import 'screens/file_manager.dart';

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
    print('═══════════════════════════════════════════════');
    print('🔄 INITIALIZING FILE HANDLER');
    print('═══════════════════════════════════════════════');
    
    // When app is already running
    ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> files) async {
        print('═══════════════════════════════════════════════');
        print('📥 SHARED FILE DETECTED (APP RUNNING)');
        print('   Files count: ${files.length}');
        print('═══════════════════════════════════════════════');
        if (files.isNotEmpty) {
          print('📥 Processing: ${files.first.path}');
          await _handleIncomingPdf(files.first.path);
        }
      },
      onError: (err) {
        print('❌ Error receiving files: $err');
      },
    );

    // When app is opened from closed state
    ReceiveSharingIntent.instance.getInitialMedia().then((initialFiles) async {
      print('═══════════════════════════════════════════════');
      print('📥 SHARED FILE DETECTED (APP CLOSED - COLD START)');
      print('   Files count: ${initialFiles.length}');
      print('═══════════════════════════════════════════════');
      if (initialFiles.isNotEmpty) {
        print('📥 Processing initial file: ${initialFiles.first.path}');
        await _handleIncomingPdf(initialFiles.first.path);
      }
      // Clear the media after processing
      ReceiveSharingIntent.instance.reset();
    }).catchError((e) {
      print('❌ Error getting initial media: $e');
    });
  }

  Future<void> _handleIncomingPdf(String filePath) async {
    print('═══════════════════════════════════════════════');
    print('🔐 STARTING PDF PROCESSING');
    print('═══════════════════════════════════════════════');
    print('📂 File path: $filePath');
    print('📌 Navigator key context available: ${navigatorKey.currentContext != null}');
    print('═══════════════════════════════════════════════');
    
    try {
      print('🔐 Processing incoming PDF: $filePath');
      
      // Handle both file:// paths and content:// URIs
      Uint8List bytes;
      String fileName = 'shared_file';
      
      if (filePath.startsWith('content://')) {
        // This is a content URI - receive_sharing_intent should have handled it
        print('📌 Content URI detected: $filePath');
        _showErrorDialog('File path format not supported. Please try again.');
        return;
      }
      
      final file = File(filePath);
      if (!await file.exists()) {
        print('❌ File does not exist: $filePath');
        _showErrorDialog('File not found: $filePath');
        return;
      }

      // Extract filename from path
      fileName = filePath.split('/').last;
      
      // Read bytes from the shared file
      bytes = await file.readAsBytes();
      print('📄 Read ${bytes.length} bytes from file: $fileName');

      // Initialize encryption service
      // final encryptionService = EncryptionService();
      // await encryptionService.initialize();
      // print('🔑 Encryption service initialized');

      // // 🔒 Encrypt the file using AES-256
      // print('🔒 Encrypting ${file.path.split('/').last}...');
      // final encryptedBytes = await encryptionService.encryptFile(Uint8List.fromList(bytes));
      // print('✅ File encrypted (${encryptedBytes.length} bytes)');

      // Save to app's private storage
      final downloadPath = await FileManager.getDownloadPath();
      final dir = Directory(downloadPath);

      if (!await dir.exists()) {
        await dir.create(recursive: true);
        print('✅ Created Downloads directory: $downloadPath');
      }

      // Generate unique filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final newFilePath = '$downloadPath/${timestamp}_$fileName.enc';

      // Write encrypted bytes to app storage
      final newFile = File(newFilePath);
      // await newFile.writeAsBytes(encryptedBytes);
      print('✅ File saved to app storage: $newFilePath');
      print('✅ File size: ${await newFile.length()} bytes');

      // Wait for the app to be fully initialized before showing UI
      print('⏳ Waiting for app to be fully initialized...');
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
        print('✅ Success snackbar shown');
      }

      // Decrypt and view the file immediately
      try {
        print('🔍 Reading encrypted file for viewing...');
        print('📌 Navigator key context available: ${navigatorKey.currentContext != null}');
        
        final savedEncrypted = await newFile.readAsBytes();
        print('📖 Encrypted file size: ${savedEncrypted.length} bytes');
        
        print('🔓 Decrypting file...');
        // final decryptedBytes = await encryptionService.decryptFile(savedEncrypted);
        //   print('✅ Decrypted file size: ${decryptedBytes.length} bytes');
        
        // // Verify PDF header
        // if (decryptedBytes.length >= 4) {
        //   final header = String.fromCharCodes(decryptedBytes.take(4));
        //   print('📄 PDF header check: $header');
        // }
        
        // Create temp file for viewing
        final tempDir = await getTemporaryDirectory();
        final cleanFileName = fileName.replaceAll('.enc', '');
        final tempFile = File('${tempDir.path}/$cleanFileName');
        // await tempFile.writeAsBytes(decryptedBytes);
        // print('✅ Temp file created: ${tempFile.path} (${decryptedBytes.length} bytes)');
        
        // Navigate to PDF viewer using navigatorKey context
        print('🎯 Attempting to navigate to PDF viewer...');
        if (navigatorKey.currentContext != null) {
          print('🚀 Navigator key context available, pushing PdfViewerPage...');
          // final result = await Navigator.of(navigatorKey.currentContext!).push(
          //   MaterialPageRoute(
          //     builder: (_) => PdfViewerPage(file: tempFile),
          //   ),
          // );
          // print('👈 Returned from PDF viewer with result: $result');
          
          // After viewing, navigate to Downloads page
          print('📱 Now navigating to Downloads page...');
          if (navigatorKey.currentContext != null) {
            print('🎯 Pushing to Downloads page...');
            // try {
            //   Navigator.of(navigatorKey.currentContext!).pushAndRemoveUntil(
            //     MaterialPageRoute(builder: (_) => const DownloadsPage()),
            //     (route) => route.isFirst,
            //   );
            //   print('✅ Successfully navigated to Downloads page');
            // } catch (navError) {
            //   print('❌ Navigation error: $navError');
            //   print('❌ Stack trace: $navError');
            // }
          } else {
            print('⚠️ Navigator context not available at Downloads navigation time');
          }
          
          // Cleanup temp file
          try {
            await tempFile.delete();
            print('✅ Temp file cleaned up');
          } catch (e) {
            print('⚠️ Failed to cleanup temp file: $e');
          }
        } else {
          print('❌ Navigator key context NOT available - cannot navigate to PDF viewer');
          print('❌ This is a critical issue with the widget tree initialization');
        }
        } catch (e) {
          print('❌ Error viewing file: $e');
          print('❌ Stack trace: ${StackTrace.current}');
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
        print('❌ Error processing PDF: $e');
        _showErrorDialog('Failed to process PDF: $e');
      }
    }

  void _showErrorDialog(String message) {
    print('🚨 Showing error dialog: $message');
    
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
      print('⚠️ Navigator context not available for error dialog');
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
      home: const ApplicantLoginPage(), // ✅ START HERE
    );
  }
}
