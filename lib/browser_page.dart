import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';
import 'downloads_page.dart';

class BrowserPage extends StatefulWidget {
  const BrowserPage({super.key});

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {
  InAppWebViewController? _controller;
  final TextEditingController _urlController =
      TextEditingController(text: "https://www.google.com");

  String status = "Ready";

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
            icon: const Icon(Icons.download),
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
                url: WebUri("https://www.google.com"),
              ),
              onWebViewCreated: (controller) {
                _controller = controller;
              },

              /// 🔥 THIS IS THE IMPORTANT PART
              onDownloadStartRequest: (controller, request) async {
                try {
                  setState(() => status = "Downloading ${request.suggestedFilename ?? ''}");

                  final file = await _saveDownload(request);

                  setState(() => status = "Saved: ${file.path}");
                } catch (e) {
                  setState(() => status = "Download error: $e");
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

  Future<File> _saveDownload(DownloadStartRequest request) async {
    final dir = await getApplicationDocumentsDirectory();
    final fileName = request.suggestedFilename ?? "downloaded_file";
    final filePath = "${dir.path}/$fileName";

    final client = HttpClient();
    final req = await client.getUrl(Uri.parse(request.url.toString()));
    final res = await req.close();
    final bytes = await consolidateHttpClientResponseBytes(res);

    final file = File(filePath);
    await file.writeAsBytes(bytes);
    return file;
  }
}