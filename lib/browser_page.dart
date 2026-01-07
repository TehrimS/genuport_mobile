import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'downloads_page.dart';

class BrowserPage extends StatefulWidget {
  final String? initialUrl;
  const BrowserPage({this.initialUrl, super.key});

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {
  InAppWebViewController? _controller;
  late TextEditingController _urlController;

  String status = "Ready";

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(
      text: widget.initialUrl ?? "https://www.google.com",
    );
    // Request permission as soon as the widget is built
    Future.delayed(Duration.zero, () {
      _requestStoragePermission();
    });
  }

  Future<bool> _requestStoragePermission() async {
    if (!Platform.isAndroid) return true;

    print('🔍 Requesting storage permission...');

    // Try MANAGE_EXTERNAL_STORAGE first (for Android 11+)
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

    // Try regular storage permission (for Android 10 and below)
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

    // If denied, show dialog
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
              },
              onLoadStart: (controller, url) {
                setState(() {
                  _urlController.text = url.toString();
                });
              },
              onDownloadStartRequest: (controller, request) async {
                try {
                  final fileName = request.suggestedFilename ?? 'downloaded_file';
                  setState(() => status = "Downloading $fileName...");

                  File file;
                  
                  // Check if it's a blob URL
                  if (request.url.toString().startsWith('blob:')) {
                    print('📦 Detected blob URL, using JavaScript to fetch...');
                    file = await _downloadBlobUrl(request, controller);
                  } else {
                    // Regular HTTP/HTTPS download
                    file = await _saveToDownloads(request);
                  }
                  
                  setState(() => status = "✓ Saved to MyBrowserDownloads");
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('✅ Saved to MyBrowserDownloads folder'),
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

  Future<File> _downloadBlobUrl(DownloadStartRequest request, InAppWebViewController controller) async {
    // Request permission before downloading
    bool hasPermission = await _requestStoragePermission();
    if (!hasPermission) {
      throw Exception('Storage permission denied. Please grant permission in Settings.');
    }

    // Use JavaScript to convert blob URL to base64
    final blobUrl = request.url.toString();
    final fileName = request.suggestedFilename ?? "downloaded_file";
    
    print('Converting blob URL to base64...');
    
    final result = await controller.evaluateJavascript(source: """
      (async function() {
        try {
          const response = await fetch('$blobUrl');
          const blob = await response.blob();
          
          return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onloadend = () => {
              const base64 = reader.result.split(',')[1];
              resolve(base64);
            };
            reader.onerror = reject;
            reader.readAsDataURL(blob);
          });
        } catch (error) {
          return 'ERROR: ' + error.message;
        }
      })();
    """);

    if (result == null || result.toString().startsWith('ERROR:')) {
      throw Exception('Failed to fetch blob data: $result');
    }

    print('Got base64 data, converting to bytes...');
    
    // Decode base64 to bytes
    final bytes = base64Decode(result.toString());
    
    // Save to storage
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

    String finalFileName = fileName;
    String filePath = "${directory.path}/$finalFileName";
    
    // Handle duplicate filenames
    int counter = 1;
    while (File(filePath).existsSync()) {
      final nameParts = fileName.split('.');
      if (nameParts.length > 1) {
        final extension = nameParts.last;
        final nameWithoutExt = nameParts.sublist(0, nameParts.length - 1).join('.');
        finalFileName = "${nameWithoutExt}_$counter.$extension";
      } else {
        finalFileName = "${fileName}_$counter";
      }
      filePath = "${directory.path}/$finalFileName";
      counter++;
    }

    final file = File(filePath);
    await file.writeAsBytes(bytes);
    
    print('✅ Blob file saved to PUBLIC storage: ${file.path}');
    return file;
  }

  Future<File> _saveToDownloads(DownloadStartRequest request) async {
    // Request permission before downloading
    bool hasPermission = await _requestStoragePermission();
    if (!hasPermission) {
      throw Exception('Storage permission denied. Please grant permission in Settings.');
    }

    Directory? directory;
    
    if (Platform.isAndroid) {
      // Save to PUBLIC Downloads folder
      directory = Directory('/storage/emulated/0/Download/MyBrowserDownloads');
      
      // Create the directory
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
    String filePath = "${directory.path}/$fileName";
    
    // Handle duplicate filenames
    int counter = 1;
    while (File(filePath).existsSync()) {
      final nameParts = fileName.split('.');
      if (nameParts.length > 1) {
        final extension = nameParts.last;
        final nameWithoutExt = nameParts.sublist(0, nameParts.length - 1).join('.');
        fileName = "${nameWithoutExt}_$counter.$extension";
      } else {
        fileName = "${fileName}_$counter";
      }
      filePath = "${directory.path}/$fileName";
      counter++;
    }

    // Download file
    final client = HttpClient();
    final req = await client.getUrl(Uri.parse(request.url.toString()));
    final res = await req.close();
    final bytes = await consolidateHttpClientResponseBytes(res);

    // Save to Downloads folder
    final file = File(filePath);
    await file.writeAsBytes(bytes);
    
    print('✅ File saved to PUBLIC storage: ${file.path}');
    return file;
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }
}