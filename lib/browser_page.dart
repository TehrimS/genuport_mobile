import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'downloads_page.dart';
import 'encryption_service.dart';
import 'pdf_unlocker.dart';

class BrowserPage extends StatefulWidget {
  final String? initialUrl;
  const BrowserPage({this.initialUrl, super.key});

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {
  InAppWebViewController? _controller;
  late TextEditingController _urlController;
  final _encryptionService = EncryptionService();

  String status = "Ready";
  bool _encryptionInitialized = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(
      text: widget.initialUrl ?? "https://www.google.com",
    );
    
    Future.delayed(Duration.zero, () async {
      await _initializeEncryption();
      await _requestStoragePermission();
    });
  }

  Future<void> _initializeEncryption() async {
    try {
      await _encryptionService.initialize();
      setState(() {
        _encryptionInitialized = true;
      });
      print('✅ Encryption initialized');
    } catch (e) {
      print('❌ Failed to initialize encryption: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Encryption initialization failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool> _requestStoragePermission() async {
    if (!Platform.isAndroid) return true;

    print('🔍 Requesting storage permission...');

    PermissionStatus manageStatus = await Permission.manageExternalStorage.status;
    print('MANAGE_EXTERNAL_STORAGE status: $manageStatus');
    
    if (!manageStatus.isGranted) {
      print('Requesting MANAGE_EXTERNAL_STORAGE...');
      manageStatus = await Permission.manageExternalStorage.request();
      print('MANAGE_EXTERNAL_STORAGE after request: $manageStatus');
    }

    if (manageStatus.isGranted) {
      print('✅ MANAGE_EXTERNAL_STORAGE granted!');
      return true;
    }

    PermissionStatus storageStatus = await Permission.storage.status;
    print('STORAGE status: $storageStatus');
    
    if (!storageStatus.isGranted) {
      print('Requesting STORAGE...');
      storageStatus = await Permission.storage.request();
      print('STORAGE after request: $storageStatus');
    }

    if (storageStatus.isGranted) {
      print('✅ STORAGE granted!');
      return true;
    }

    print('❌ All permissions denied');
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('⚠️ Permission Required'),
          content: const Text(
            'This app MUST have storage permission to download files.\n\n'
            'Please tap "Open Settings" and enable:\n'
            '• "All files access" (Android 11+)\n'
            'OR\n'
            '• "Storage" permission (older Android)'
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
    }

    return false;
  }

  @override
  void didUpdateWidget(BrowserPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialUrl != null && widget.initialUrl != oldWidget.initialUrl) {
      _urlController.text = widget.initialUrl!;
      _controller?.loadUrl(
        urlRequest: URLRequest(
          url: WebUri(widget.initialUrl!),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _urlController,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: "Enter URL",
          ),
          onSubmitted: (value) {
            _controller?.loadUrl(
              urlRequest: URLRequest(
                url: WebUri(_formatUrl(value)),
              ),
            );
          },
        ),
        actions: [
          if (_encryptionInitialized)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(
                Icons.lock,
                color: Colors.green[700],
                size: 20,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: () {
              _controller?.loadUrl(
                urlRequest: URLRequest(
                  url: WebUri(_formatUrl(_urlController.text)),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.folder),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DownloadsPage()),
              );
            },
          )
        ],
      ),
      body: Column(
        children: [
          if (_encryptionInitialized)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: Colors.green[50],
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_outlined, size: 16, color: Colors.green[700]),
                  const SizedBox(width: 6),
                  Text(
                    'Downloads are encrypted & secured',
                    style: TextStyle(fontSize: 12, color: Colors.green[700]),
                  ),
                ],
              ),
            ),
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(
                url: WebUri(widget.initialUrl ?? "https://www.google.com"),
              ),
              initialSettings: InAppWebViewSettings(
                useOnDownloadStart: true,
                javaScriptEnabled: true,
                allowFileAccess: true,
                allowContentAccess: true,
              ),
              onWebViewCreated: (controller) {
                _controller = controller;
                _injectBlobInterceptor(controller);
              },
              onLoadStart: (controller, url) {
                setState(() {
                  _urlController.text = url.toString();
                });
              },
              onLoadStop: (controller, url) async {
                await _injectBlobInterceptor(controller);
              },
              onDownloadStartRequest: (controller, request) async {
                try {
                  if (!_encryptionInitialized) {
                    throw Exception('Encryption not initialized. Please restart the app.');
                  }

                  final fileName = request.suggestedFilename ?? 'downloaded_file';
                  setState(() => status = "Downloading $fileName...");

                  File? file;
                  
                  if (request.url.toString().startsWith('blob:')) {
                    print('📦 Detected blob URL, using JavaScript to fetch...');
                    file = await _downloadBlobUrl(request, controller);
                  } else {
                    file = await _saveToDownloads(request);
                  }
                  
                  if (file == null) {
                    throw Exception('Download failed: file is null');
                  }
                  
                  setState(() => status = "✓ Saved & encrypted");
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.lock, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text('✅ Downloaded & encrypted successfully'),
                            ),
                          ],
                        ),
                        duration: const Duration(seconds: 3),
                        action: SnackBarAction(
                          label: 'View',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const DownloadsPage()),
                            );
                          },
                        ),
                      ),
                    );
                  }
                  
                  Future.delayed(const Duration(seconds: 2), () {
                    if (mounted) {
                      setState(() => status = "Ready");
                    }
                  });
                } catch (e) {
                  setState(() => status = "❌ Download failed");
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Download failed: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.black12,
            child: Text(status, textAlign: TextAlign.center),
          )
        ],
      ),
    );
  }

  String _formatUrl(String url) {
    if (!url.startsWith("http://") && !url.startsWith("https://")) {
      return "https://$url";
    }
    return url;
  }

  Future<void> _injectBlobInterceptor(InAppWebViewController controller) async {
    await controller.evaluateJavascript(source: """
      (function() {
        console.log('🔧 Injecting blob interceptor...');
        
        window.blobCache = window.blobCache || {};
        
        const originalCreateObjectURL = URL.createObjectURL;
        URL.createObjectURL = function(blob) {
          const url = originalCreateObjectURL.call(this, blob);
          console.log('📦 Blob created:', url);
          
          if (blob instanceof Blob) {
            const reader = new FileReader();
            reader.onloadend = function() {
              const base64 = reader.result.split(',')[1];
              window.blobCache[url] = base64;
              console.log('✅ Cached blob:', url);
            };
            reader.readAsDataURL(blob);
          }
          
          return url;
        };
        
        console.log('✅ Blob interceptor installed');
      })();
    """);
    
    print('✅ Blob interceptor injected');
  }

  Future<String?> _askForPdfPassword() async {
    final TextEditingController passwordController = TextEditingController();
    
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock_open, color: Colors.orange),
            SizedBox(width: 8),
            Text('PDF Password Required'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This PDF is password protected.\nEnter password to unlock permanently:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                hintText: 'e.g., DOB (DDMMYYYY) or PAN',
                prefixIcon: Icon(Icons.key),
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '💡 Common bank passwords:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  SizedBox(height: 4),
                  Text('• Date of Birth: DDMMYYYY (e.g., 15081990)', style: TextStyle(fontSize: 12)),
                  Text('• PAN Card: ABCDE1234F', style: TextStyle(fontSize: 12)),
                  Text('• "password" or "statement"', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Skip'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context, passwordController.text);
            },
            icon: const Icon(Icons.lock_open),
            label: const Text('Unlock'),
          ),
        ],
      ),
    );
  }

  Future<File> _downloadBlobUrl(DownloadStartRequest request, InAppWebViewController controller) async {
    bool hasPermission = await _requestStoragePermission();
    if (!hasPermission) {
      throw Exception('Storage permission denied');
    }

    final blobUrl = request.url.toString();
    final fileName = request.suggestedFilename ?? "downloaded_file";
    
    print('📥 Downloading blob...');
    
    var result = await controller.evaluateJavascript(source: """
      (function() {
        if (window.blobCache && window.blobCache['$blobUrl']) {
          return window.blobCache['$blobUrl'];
        }
        return null;
      })();
    """);
    
    if (result != null && result.toString() != 'null') {
      print('✅ Retrieved from cache');
    } else {
      print('Fetching blob...');
      
      result = await controller.evaluateJavascript(source: """
        (async function() {
          try {
            const response = await fetch('$blobUrl');
            if (!response.ok) return 'ERROR: HTTP ' + response.status;
            
            const blob = await response.blob();
            if (blob.size === 0) return 'ERROR: Empty blob';
            
            return new Promise((resolve, reject) => {
              const reader = new FileReader();
              reader.onloadend = () => {
                const base64 = reader.result.split(',')[1];
                resolve(base64);
              };
              reader.onerror = () => reject('FileReader error');
              reader.readAsDataURL(blob);
            });
          } catch (error) {
            return 'ERROR: ' + error.message;
          }
        })();
      """);
    }

    if (result == null || result.toString().isEmpty || result.toString() == '{}') {
      throw Exception('Blob download failed');
    }

    final resultStr = result.toString();
    if (resultStr.startsWith('ERROR:')) {
      throw Exception(resultStr);
    }

    var bytes = base64Decode(resultStr);
    var finalBytes = Uint8List.fromList(bytes);

    // 🔓 UNLOCK PASSWORD-PROTECTED PDF
    if (fileName.toLowerCase().endsWith('.pdf')) {
      finalBytes = await _unlockPdfIfNeeded(finalBytes);
    }
    
    // 🔒 ENCRYPT
    print('🔒 Encrypting file...');
    final encryptedBytes = await _encryptionService.encryptFile(finalBytes);
    
    // Save
    return await _saveEncryptedFile(encryptedBytes, fileName);
  }

  Future<File> _saveToDownloads(DownloadStartRequest request) async {
    bool hasPermission = await _requestStoragePermission();
    if (!hasPermission) {
      throw Exception('Storage permission denied');
    }

    String fileName = request.suggestedFilename ?? "downloaded_file";
    
    print('📥 Downloading: $fileName');
    print('URL: ${request.url}');
    print('Expected size: ${request.contentLength} bytes');
    
    final client = HttpClient();
    final req = await client.getUrl(Uri.parse(request.url.toString()));
    final res = await req.close();
    
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}: ${res.reasonPhrase}');
    }
    
    final bytes = await consolidateHttpClientResponseBytes(res);
    print('📊 Downloaded: ${bytes.length} bytes');

    if (request.contentLength > 0 && bytes.length != request.contentLength) {
      print('⚠️ Size mismatch! Expected: ${request.contentLength}, Got: ${bytes.length}');
    }

    var finalBytes = Uint8List.fromList(bytes);

    // Check if PDF and password-protected (just for info)
    if (fileName.toLowerCase().endsWith('.pdf')) {
      try {
        bool isProtected = PdfUnlocker.isPasswordProtected(finalBytes);
        if (isProtected) {
          print('ℹ️ PDF is password protected');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('ℹ️ PDF is password protected. Enter password when viewing.'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      } catch (e) {
        print('Could not check PDF protection: $e');
      }
    }

    // 🔒 ENCRYPT
    print('🔒 Encrypting file...');
    final encryptedBytes = await _encryptionService.encryptFile(finalBytes);

    // Save
    return await _saveEncryptedFile(encryptedBytes, fileName);
  }

  Future<Uint8List> _unlockPdfIfNeeded(Uint8List pdfBytes) async {
    // SIMPLIFIED: Don't try to unlock PDFs at all
    // Just save them as-is, encrypted
    // User can view them with password in the app
    
    setState(() => status = "Processing PDF...");
    
    // Check if protected (just for information)
    bool isProtected = false;
    try {
      isProtected = PdfUnlocker.isPasswordProtected(pdfBytes);
    } catch (e) {
      print('⚠️ Could not check PDF protection: $e');
    }
    
    if (isProtected) {
      print('ℹ️ PDF is password protected - will be saved as-is');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ℹ️ PDF is password protected. You\'ll need the password to view it.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
    
    // Return as-is without any unlock attempts
    return pdfBytes;
  }

  Future<File> _saveEncryptedFile(Uint8List encryptedBytes, String fileName) async {
    Directory? directory;
    
    if (Platform.isAndroid) {
      directory = Directory('/storage/emulated/0/Download/MyBrowserDownloads');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
    } else {
      directory = await getApplicationDocumentsDirectory();
      final customPath = '${directory.path}/MyBrowserDownloads';
      directory = Directory(customPath);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
    }

    if (directory == null) {
      throw Exception('Could not find directory');
    }

    String finalFileName = fileName.endsWith('.enc') ? fileName : '$fileName.enc';
    String filePath = "${directory.path}/$finalFileName";
    
    int counter = 1;
    while (File(filePath).existsSync()) {
      String nameWithoutEnc = fileName.endsWith('.enc') 
          ? fileName.substring(0, fileName.length - 4) 
          : fileName;
      
      final nameParts = nameWithoutEnc.split('.');
      if (nameParts.length > 1) {
        final extension = nameParts.last;
        final nameWithoutExt = nameParts.sublist(0, nameParts.length - 1).join('.');
        finalFileName = "${nameWithoutExt}_$counter.$extension.enc";
      } else {
        finalFileName = "${nameWithoutEnc}_$counter.enc";
      }
      filePath = "${directory.path}/$finalFileName";
      counter++;
    }

    final file = File(filePath);
    await file.writeAsBytes(encryptedBytes);
    
    print('✅ Encrypted file saved: ${file.path}');
    return file;
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }
}