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
    
    // Initialize encryption and request permissions
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
          // Encryption status indicator
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
          // Show encryption status banner
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
                // Re-inject blob interceptor on every page load
                await _injectBlobInterceptor(controller);
              },
              onDownloadStartRequest: (controller, request) async {
                try {
                  if (!_encryptionInitialized) {
                    throw Exception('Encryption not initialized. Please restart the app.');
                  }

                  final fileName = request.suggestedFilename ?? 'downloaded_file';
                  setState(() => status = "Downloading & encrypting $fileName...");

                  File? file;
                  
                  if (request.url.toString().startsWith('blob:')) {
                    print('📦 Detected blob URL, using JavaScript to fetch...');
                    
                    // Try blob download with retry
                    int retries = 2;
                    Exception? lastError;
                    
                    for (int attempt = 1; attempt <= retries; attempt++) {
                      try {
                        print('🔄 Download attempt $attempt of $retries');
                        file = await _downloadBlobUrl(request, controller);
                        break; // Success!
                      } catch (e) {
                        lastError = e as Exception;
                        print('❌ Attempt $attempt failed: $e');
                        
                        if (attempt < retries) {
                          // Wait before retry
                          await Future.delayed(Duration(milliseconds: 300));
                        } else {
                          // Show user-friendly error with manual download option
                          if (mounted) {
                            setState(() => status = "Ready");
                            
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Row(
                                  children: [
                                    Icon(Icons.warning, color: Colors.orange),
                                    SizedBox(width: 8),
                                    Text('Download Failed'),
                                  ],
                                ),
                                content: const Text(
                                  'The download link expired too quickly.\n\n'
                                  'Please try:\n'
                                  '1. Click download button again immediately\n'
                                  '2. Or use the manual download option below\n'
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('OK'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _showManualDownloadInstructions();
                                    },
                                    child: const Text('Manual Download'),
                                  ),
                                ],
                              ),
                            );
                          }
                          throw Exception('Failed after $retries attempts: ${lastError.toString()}');
                        }
                      }
                    }
                  } else {
                    file = await _saveToDownloads(request);
                  }
                  
                  if (file == null) {
                    throw Exception('Download failed: file is null');
                  }
                  
                  setState(() => status = "✓ Saved & encrypted in MyBrowserDownloads");
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.lock, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text('✅ Saved & encrypted in MyBrowserDownloads'),
                            ),
                          ],
                        ),
                        duration: const Duration(seconds: 4),
                        action: SnackBarAction(
                          label: 'View Files',
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
                  setState(() => status = "❌ Download failed: $e");
                  
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

  /// Inject JavaScript to intercept and cache blob URLs
  Future<void> _injectBlobInterceptor(InAppWebViewController controller) async {
    await controller.evaluateJavascript(source: """
      (function() {
        console.log('🔧 Injecting blob interceptor...');
        
        // Store blob data in memory
        window.blobCache = window.blobCache || {};
        
        // Override createObjectURL to cache blob data
        const originalCreateObjectURL = URL.createObjectURL;
        URL.createObjectURL = function(blob) {
          const url = originalCreateObjectURL.call(this, blob);
          console.log('📦 Blob created:', url);
          
          // Cache the blob data immediately
          if (blob instanceof Blob) {
            const reader = new FileReader();
            reader.onloadend = function() {
              const base64 = reader.result.split(',')[1];
              window.blobCache[url] = base64;
              console.log('✅ Cached blob:', url, 'Size:', base64.length);
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

  Future<File> _downloadBlobUrl(DownloadStartRequest request, InAppWebViewController controller) async {
    bool hasPermission = await _requestStoragePermission();
    if (!hasPermission) {
      throw Exception('Storage permission denied. Please grant permission in Settings.');
    }

    final blobUrl = request.url.toString();
    final fileName = request.suggestedFilename ?? "downloaded_file";
    
    print('📥 Attempting to download blob...');
    print('Blob URL: $blobUrl');
    
    // First, try to get from cache (our interceptor)
    var result = await controller.evaluateJavascript(source: """
      (function() {
        if (window.blobCache && window.blobCache['$blobUrl']) {
          console.log('✅ Found in cache!');
          return window.blobCache['$blobUrl'];
        }
        return null;
      })();
    """);
    
    if (result != null && result.toString() != 'null' && result.toString().isNotEmpty) {
      print('✅ Retrieved from cache!');
    } else {
      print('❌ Not in cache, trying direct fetch...');
      
      // Try direct fetch as fallback
      result = await controller.evaluateJavascript(source: """
        (async function() {
          try {
            console.log('Fetching blob URL: $blobUrl');
            const response = await fetch('$blobUrl');
            
            if (!response.ok) {
              return 'ERROR: HTTP ' + response.status;
            }
            
            const blob = await response.blob();
            console.log('Blob size: ' + blob.size + ' bytes');
            
            if (blob.size === 0) {
              return 'ERROR: Blob is empty';
            }
            
            return new Promise((resolve, reject) => {
              const reader = new FileReader();
              reader.onloadend = () => {
                try {
                  const result = reader.result;
                  if (!result || typeof result !== 'string') {
                    reject('Invalid result from FileReader');
                    return;
                  }
                  const base64 = result.split(',')[1];
                  if (!base64) {
                    reject('Failed to extract base64 data');
                    return;
                  }
                  console.log('Base64 length: ' + base64.length);
                  resolve(base64);
                } catch (e) {
                  reject('Error processing result: ' + e.message);
                }
              };
              reader.onerror = () => reject('FileReader error: ' + reader.error);
              reader.readAsDataURL(blob);
            });
          } catch (error) {
            console.error('Blob fetch error:', error);
            return 'ERROR: ' + error.message;
          }
        })();
      """);
    }

    print('JavaScript result: $result');

    // Handle null or empty results
    if (result == null) {
      throw Exception('JavaScript returned null. The blob URL may have expired.');
    }

    final resultStr = result.toString().trim();
    
    // Check for empty result
    if (resultStr.isEmpty || resultStr == '{}' || resultStr == 'null') {
      throw Exception('JavaScript returned empty result. The blob URL may have expired. Try downloading again.');
    }

    // Check for errors
    if (resultStr.startsWith('ERROR:')) {
      throw Exception('Failed to fetch blob: ${resultStr.substring(7)}');
    }

    // Validate base64
    if (!_isValidBase64(resultStr)) {
      throw Exception('Invalid base64 data received. Result: ${resultStr.substring(0, 50)}...');
    }

    print('✓ Got valid base64 data, converting to bytes...');
    
    final bytes = base64Decode(resultStr);
    
    // 🔒 ENCRYPT THE FILE BEFORE SAVING
    print('🔒 Encrypting file...');
    final encryptedBytes = await _encryptionService.encryptFile(Uint8List.fromList(bytes));
    
    // Save encrypted file
    Directory? directory;
    
    if (Platform.isAndroid) {
      directory = Directory('/storage/emulated/0/Download/MyBrowserDownloads');
      
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
    } else if (Platform.isIOS) {
      directory = await getApplicationDocumentsDirectory();
      final customPath = '${directory.path}/MyBrowserDownloads';
      directory = Directory(customPath);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
    }

    if (directory == null) {
      throw Exception('Could not find downloads directory');
    }

    // Add .enc extension to indicate encrypted file
    String finalFileName = _ensureEncExtension(fileName);
    String filePath = "${directory.path}/$finalFileName";
    
    // Handle duplicate filenames
    int counter = 1;
    while (File(filePath).existsSync()) {
      finalFileName = _getIncrementedFileName(fileName, counter);
      filePath = "${directory.path}/$finalFileName";
      counter++;
    }

    final file = File(filePath);
    await file.writeAsBytes(encryptedBytes);
    
    print('✅ Encrypted blob file saved: ${file.path}');
    return file;
  }

  Future<File> _saveToDownloads(DownloadStartRequest request) async {
    bool hasPermission = await _requestStoragePermission();
    if (!hasPermission) {
      throw Exception('Storage permission denied. Please grant permission in Settings.');
    }

    Directory? directory;
    
    if (Platform.isAndroid) {
      directory = Directory('/storage/emulated/0/Download/MyBrowserDownloads');
      
      try {
        if (!await directory.exists()) {
          await directory.create(recursive: true);
          print('✅ Created directory: ${directory.path}');
        }
      } catch (e) {
        print('❌ Failed to create directory: $e');
        throw Exception('Cannot create downloads folder. Check permissions.');
      }
    } else if (Platform.isIOS) {
      directory = await getApplicationDocumentsDirectory();
      final customPath = '${directory.path}/MyBrowserDownloads';
      directory = Directory(customPath);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
    }

    if (directory == null) {
      throw Exception('Could not find downloads directory');
    }

    String fileName = request.suggestedFilename ?? "downloaded_file";
    
    // Download file
    final client = HttpClient();
    final req = await client.getUrl(Uri.parse(request.url.toString()));
    final res = await req.close();
    final bytes = await consolidateHttpClientResponseBytes(res);

    // 🔒 ENCRYPT THE FILE BEFORE SAVING
    print('🔒 Encrypting file...');
    final encryptedBytes = await _encryptionService.encryptFile(Uint8List.fromList(bytes));

    // Add .enc extension
    String finalFileName = _ensureEncExtension(fileName);
    String filePath = "${directory.path}/$finalFileName";
    
    // Handle duplicate filenames
    int counter = 1;
    while (File(filePath).existsSync()) {
      finalFileName = _getIncrementedFileName(fileName, counter);
      filePath = "${directory.path}/$finalFileName";
      counter++;
    }

    final file = File(filePath);
    await file.writeAsBytes(encryptedBytes);
    
    print('✅ Encrypted file saved: ${file.path}');
    return file;
  }

  String _ensureEncExtension(String fileName) {
    if (fileName.endsWith('.enc')) return fileName;
    return '$fileName.enc';
  }

  String _getIncrementedFileName(String fileName, int counter) {
    // Remove .enc if present for manipulation
    String nameWithoutEnc = fileName.endsWith('.enc') 
        ? fileName.substring(0, fileName.length - 4) 
        : fileName;
    
    final nameParts = nameWithoutEnc.split('.');
    if (nameParts.length > 1) {
      final extension = nameParts.last;
      final nameWithoutExt = nameParts.sublist(0, nameParts.length - 1).join('.');
      return "${nameWithoutExt}_$counter.$extension.enc";
    } else {
      return "${nameWithoutEnc}_$counter.enc";
    }
  }

  /// Validate if a string is valid base64
  bool _isValidBase64(String str) {
    if (str.isEmpty) return false;
    
    // Check if it contains only valid base64 characters
    final base64Pattern = RegExp(r'^[A-Za-z0-9+/]*={0,2}$');
    return base64Pattern.hasMatch(str);
  }

  void _showManualDownloadInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manual Download Instructions'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kotak Bank\'s download links expire very quickly. Here\'s how to download manually:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text('Option 1: Use Chrome Browser'),
              SizedBox(height: 8),
              Text('1. Open Chrome browser'),
              Text('2. Go to your Kotak NetBanking'),
              Text('3. Download the statement'),
              Text('4. Open with this app'),
              SizedBox(height: 16),
              Text('Option 2: Quick Click Method'),
              SizedBox(height: 8),
              Text('1. Stay on this page'),
              Text('2. Click download in the bank website'),
              Text('3. IMMEDIATELY click download again when popup appears'),
              Text('4. Sometimes the second click works!'),
              SizedBox(height: 16),
              Text(
                'This issue is due to Kotak Bank\'s security settings that make download links expire in milliseconds.',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }
}