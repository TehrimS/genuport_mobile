import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:genuport/services/encryption_service.dart';
import 'package:genuport/services/file_metadata.dart';
import 'package:genuport/services/pdf_unlocker.dart';
import 'package:genuport/services/trusted_sites.dart';
import 'package:genuport/themes/gp_colors.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'downloads_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  InAppWebViewController? _webController;
  final _searchController = TextEditingController();
  final _encryptionService = EncryptionService();
  final _urlFocusNode = FocusNode();

  bool _webViewVisible = false;
  bool _isLoading = false;
  double _loadProgress = 0;
  bool _encReady = false;
  String _status = '';
  String _currentUrl = '';
  String _entryUrl = ''; // ✅ NEW: Track the original site user navigated to
  String _selectedCountry = 'India';
  bool _showDashboardLoading = false; // ✅ NEW: Track if loading from dashboard

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _encryptionService.initialize();
    if (mounted) setState(() => _encReady = true);
    if (Platform.isAndroid) await _requestStoragePermission();
  }

  Future<bool> _requestStoragePermission() async {
    if (!Platform.isAndroid) return true;
    var s = await Permission.manageExternalStorage.status;
    if (!s.isGranted) s = await Permission.manageExternalStorage.request();
    if (s.isGranted) return true;
    var s2 = await Permission.storage.status;
    if (!s2.isGranted) s2 = await Permission.storage.request();
    return s2.isGranted;
  }

  // ✅ UPDATED: Show loading overlay before navigating
  void _loadUrl(String url) {
    final uri = _smartUrl(url);
    print('🌐 [NAV] User navigating to: $uri');
    setState(() {
      _showDashboardLoading = true; // Show loading overlay
      _entryUrl = uri; // ✅ Save original URL user navigated to
      print('✅ [NAV] Set _entryUrl = $uri');
    });
    
    // Delay to show loading overlay, then navigate
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _webViewVisible = true;
          _currentUrl = uri;
        });
        _webController?.loadUrl(urlRequest: URLRequest(url: WebUri(uri)));
        _searchController.text = uri;
        _urlFocusNode.unfocus();
      }
    });
  }

  void _goHome() {
    setState(() {
      _webViewVisible = false;
      _currentUrl = '';
      _entryUrl = ''; // ✅ Also clear entry URL
      _searchController.clear();
      _showDashboardLoading = false;
    });
    _webController?.loadUrl(
      urlRequest: URLRequest(url: WebUri('https://www.google.com')),
    );
  }

  String _smartUrl(String input) {
    input = input.trim();
    if (input.contains(' ') || (!input.contains('.') && !input.startsWith('localhost'))) {
      return 'https://www.google.com/search?q=${Uri.encodeComponent(input)}';
    }
    if (!input.startsWith('http://') && !input.startsWith('https://')) return 'https://$input';
    return input;
  }

  String _domain(String url) {
    try {
      return Uri.parse(url).host.replaceFirst('www.', '');
    } catch (_) {
      return url;
    }
  }

  Future<void> _injectBlobInterceptor(InAppWebViewController c) async {
    await c.evaluateJavascript(source: """
      (function(){
        window.blobCache=window.blobCache||{};
        const orig=URL.createObjectURL;
        URL.createObjectURL=function(blob){
          const url=orig.call(this,blob);
          if(blob instanceof Blob){
            const r=new FileReader();
            r.onloadend=()=>{window.blobCache[url]=r.result.split(',')[1];};
            r.readAsDataURL(blob);
          }
          return url;
        };
      })();
    """);
  }

  Future<void> _handleDownload(DownloadStartRequest req, InAppWebViewController ctrl) async {
    try {
      if (!_encReady) throw Exception('Encryption not ready');
      final name = req.suggestedFilename ?? 'downloaded_file';
      setState(() => _status = 'Downloading $name…');
      final urlString = req.url.toString();
      if (urlString.startsWith('blob:')) {
        await _downloadBlob(req, ctrl);
      } else if (urlString.startsWith('data:')) {
        await _downloadDataUrl(req);
      } else {
        await _downloadHttp(req);
      }
      setState(() => _status = '✓ Saved & encrypted');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: GPColors.primary,
          content: Row(children: [
            const Icon(Icons.lock_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text('$name encrypted & saved', style: const TextStyle(color: Colors.white))),
          ]),
          action: SnackBarAction(
            label: 'View',
            textColor: GPColors.accent,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DownloadsPage()),
            ),
          ),
        ));
      }
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _status = '');
      });
    } catch (e) {
      setState(() => _status = '❌ Failed');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: GPColors.error,
          content: Text('Download failed: $e', style: const TextStyle(color: Colors.white)),
        ));
      }
    }
  }

  String _getSourceUrl() {
    // If entryUrl is set, use it. Otherwise extract domain from currentUrl
    if (_entryUrl.startsWith('http')) return _entryUrl;
    if (_currentUrl.startsWith('http')) {
      // Extract just the domain from current URL for context
      try {
        final uri = Uri.parse(_currentUrl);
        return '${uri.scheme}://${uri.host}';
      } catch (e) {
        return _currentUrl;
      }
    }
    return 'Unknown Portal';
  }

  Future<dynamic> _downloadBlob(DownloadStartRequest req, InAppWebViewController ctrl) async {
    final blobUrl = req.url.toString();
    var fileName = req.suggestedFilename?.trim() ?? '';
    if (fileName.isEmpty) {
      fileName = 'blob_${DateTime.now().millisecondsSinceEpoch}.pdf';
    }
    
    var result = await ctrl.evaluateJavascript(source: """
      (function(){
        if(window.blobCache&&window.blobCache['$blobUrl'])return window.blobCache['$blobUrl'];
        return null;
      })();
    """);
    if (result == null || result.toString() == 'null') {
      result = await ctrl.evaluateJavascript(source: """
        (async function(){
          try{
            const r=await fetch('$blobUrl');
            if(!r.ok)return 'ERROR:'+r.status;
            const b=await r.blob();
            if(b.size===0)return 'ERROR:empty';
            return new Promise((res,rej)=>{
              const fr=new FileReader();
              fr.onloadend=()=>res(fr.result.split(',')[1]);
              fr.onerror=()=>rej('err');
              fr.readAsDataURL(b);
            });
          }catch(e){return 'ERROR:'+e.message;}
        })();
      """);
    }
    if (result == null || result.toString().isEmpty || result.toString() == '{}') {
      throw Exception('Blob expired');
    }
    if (result.toString().startsWith('ERROR:')) throw Exception(result.toString());
    final bytes = Uint8List.fromList(base64Decode(result.toString()));
    
    // Use entry URL as sourceUrl (original site user navigated to), abbreviated blob reference as fetchedUrl
    final pageUrl = _entryUrl.startsWith('http') ? _entryUrl : 'Unknown Portal';
    final blobRef = 'blob:${Uri.parse(blobUrl).host}';
    
    // STEP 1: Create metadata with sourceHash (hash of original blob data)
    final meta = FileMetadata.create(
      fileName: fileName,
      sourceUrl: pageUrl,
      fetchedUrl: blobRef,
      originalBytes: bytes,
    );
    
    print('📥 [DOWNLOAD] Blob file: $fileName (${bytes.length} bytes)');
    print('   • sourceUrl (page): $pageUrl');
    print('   • fetchedUrl (blob): $blobRef');
    print('   • sourceHash: ${meta.sourceHash.substring(0, 16)}...');
    
    final encrypted = await _encryptionService.encryptFile(bytes, metadata: meta.toJson());
    return _saveFile(encrypted, fileName);
  }

  Future<dynamic> _downloadDataUrl(DownloadStartRequest req) async {
    var fileName = req.suggestedFilename?.trim() ?? '';
    if (fileName.isEmpty) {
      fileName = 'data_${DateTime.now().millisecondsSinceEpoch}.pdf';
    }
    
    final urlString = req.url.toString();
    final commaIndex = urlString.indexOf(',');
    if (commaIndex < 0) throw Exception('Invalid data URL');

    final header = urlString.substring(0, commaIndex);
    final payload = urlString.substring(commaIndex + 1);
    final bytes = header.contains(';base64')
        ? base64Decode(payload)
        : Uint8List.fromList(utf8.encode(Uri.decodeFull(payload)));

    // Use entry URL as sourceUrl (original site user navigated to), abbreviated data: reference as fetchedUrl
    final pageUrl = _entryUrl.startsWith('http') ? _entryUrl : 'Unknown Portal';
    final dataUrlRef = header.replaceAll(';base64', ''); // header already starts with 'data:'
    
    // STEP 1: Create metadata with sourceHash (hash of original data URL content)
    final meta = FileMetadata.create(
      fileName: fileName,
      sourceUrl: pageUrl,
      fetchedUrl: dataUrlRef,
      originalBytes: bytes,
    );
    
    print('📥 [DOWNLOAD] Data URL file: $fileName (${bytes.length} bytes)');
    print('   • sourceUrl (page): $pageUrl');
    print('   • fetchedUrl (data): $dataUrlRef');
    print('   • sourceHash: ${meta.sourceHash.substring(0, 16)}...');
    print('   • entryUrl was: $_entryUrl');
    
    final encrypted = await _encryptionService.encryptFile(bytes, metadata: meta.toJson());
    return _saveFile(encrypted, fileName);
  }

  Future<dynamic> _downloadHttp(DownloadStartRequest req) async {
    var fileName = req.suggestedFilename?.trim() ?? '';
    
    // If no filename from request, try to get from URL or headers
    if (fileName.isEmpty) {
      // First, try to get from URL path
      final urlPath = req.url.toString().split('?').first.split('/').last;
      fileName = urlPath.isNotEmpty && urlPath.contains('.') ? urlPath : '';
      
      // If still empty, try to get from HTTP headers
      if (fileName.isEmpty) {
        try {
          final client = HttpClient();
          final r = await client.headUrl(Uri.parse(req.url.toString()));
          final res = await r.close();
          final contentDisposition = res.headers.value('content-disposition');
          if (contentDisposition != null) {
            final filenamePattern = RegExp(r'filename\*?=(?:"([^"]+)"|([^;\s]+))');
            final match = filenamePattern.firstMatch(contentDisposition);
            if (match != null) {
              fileName = (match.group(1) ?? match.group(2) ?? '').trim();
            }
          }
        } catch (e) {
          debugPrint('⚠️ Could not get filename from headers: $e');
        }
      }
      
      // Last resort fallback
      if (fileName.isEmpty) {
        fileName = 'download_${DateTime.now().millisecondsSinceEpoch}.pdf';
      }
    }
    
    final client = HttpClient();
    final r = await client.getUrl(Uri.parse(req.url.toString()));
    final res = await r.close();
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    final bytes = await consolidateHttpClientResponseBytes(res);
    var finalBytes = Uint8List.fromList(bytes);
    
    // Use page URL (not download URL) as sourceUrl for context
    final pageUrl = _entryUrl.startsWith('http') ? _entryUrl : 'Unknown Portal';
    
    // STEP 1: Create metadata with sourceHash (hash of original file as received)
    var meta = FileMetadata.create(
      fileName: fileName,
      sourceUrl: pageUrl,
      fetchedUrl: req.url.toString(),
      originalBytes: finalBytes,
    );

    print('📥 [DOWNLOAD] HTTP file: $fileName (${finalBytes.length} bytes)');
    print('   • sourceUrl (page): $pageUrl');
    print('   • fetchedUrl (actual): ${req.url.toString()}');
    print('   • sourceHash: ${meta.sourceHash.substring(0, 16)}...');
    print('   • timestamp: ${meta.formattedTimestamp}');
    print('   • fileSize: ${meta.formattedSize}');
    print('   • entryUrl was: $_entryUrl');

    // Check if password-protected PDF
    if (fileName.toLowerCase().endsWith('.pdf') && PdfUnlocker.isPasswordProtected(finalBytes)) {
      print('🔒 [DOWNLOAD] PDF is password-protected - will prompt on open');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Password-protected PDF — enter password when viewing.'),
        ));
      }
      // STEP 2 & 3: Will be handled when user opens the file and enters password
    }
    
    final encrypted = await _encryptionService.encryptFile(finalBytes, metadata: meta.toJson());
    return _saveFile(encrypted, fileName);
  }

  Future<dynamic> _saveFile(Uint8List encrypted, String fileName) async {
    late Directory dir;
    if (Platform.isAndroid) {
      dir = Directory('/storage/emulated/0/Download/GenuPortDownloads');
      if (!await dir.exists()) await dir.create(recursive: true);
    } else {
      final d = await getApplicationDocumentsDirectory();
      dir = Directory('${d.path}/GenuPortDownloads');
      if (!await dir.exists()) await dir.create(recursive: true);
    }
    final baseName = fileName.endsWith('.pdf') ? fileName : '$fileName.pdf';
    var path = '${dir.path}/$baseName';
    int i = 1;
    while (File(path).existsSync()) {
      final parts = baseName.split('.');
      path = parts.length > 1
          ? '${dir.path}/${parts.sublist(0, parts.length - 1).join('.')}_$i.${parts.last}'
          : '${dir.path}/${baseName}_$i';
      i++;
    }
    final file = File(path);
    await file.writeAsBytes(encrypted);
    return file;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _urlFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_webViewVisible) {
          final canGoBack = await _webController?.canGoBack() ?? false;
          if (canGoBack) {
            _webController?.goBack();
          } else {
            _goHome();
          }
        }
      },
      child: Scaffold(
        backgroundColor: GPColors.surfacePage,
        body: Column(children: [
          _buildAppBar(),
          if (_isLoading)
            SizedBox(
              height: 2,
              child: LinearProgressIndicator(
                value: _loadProgress > 0 ? _loadProgress : null,
                backgroundColor: GPColors.border,
                valueColor: const AlwaysStoppedAnimation(GPColors.primaryLight),
              ),
            ),
          if (_status.isNotEmpty) _buildStatusBar(),
          Expanded(
            child: Stack(children: [
              // ── WebView ──
              Offstage(
                offstage: !_webViewVisible,
                child: InAppWebView(
                  initialUrlRequest: URLRequest(url: WebUri('https://www.google.com')),
                  initialSettings: InAppWebViewSettings(
                    useOnDownloadStart: true,
                    javaScriptEnabled: true,
                    allowFileAccess: true,
                    allowContentAccess: true,
                  ),
                  onWebViewCreated: (c) {
                    _webController = c;
                    _injectBlobInterceptor(c);
                  },
                  onLoadStart: (c, url) {
                    final u = url?.toString() ?? '';
                    setState(() {
                      _isLoading = true;
                      _loadProgress = 0;
                      _currentUrl = u;
                      _showDashboardLoading = false; // Hide loading overlay
                    });
                  },
                  onProgressChanged: (c, p) => setState(() => _loadProgress = p / 100),
                  onLoadStop: (c, url) async {
                    await _injectBlobInterceptor(c);
                    final u = url?.toString() ?? '';
                    setState(() {
                      _isLoading = false;
                      _currentUrl = u;
                    });
                  },
                  onDownloadStartRequest: (c, req) => _handleDownload(req, c),
                ),
              ),
              // ── Dashboard ──
              if (!_webViewVisible) _buildDashboard(),
              
              // ✅ NEW: Loading overlay when launching from dashboard
              if (_showDashboardLoading)
                Container(
                  color: Colors.black.withOpacity(0.5),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                color: GPColors.primary,
                                strokeWidth: 3,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Loading',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: GPColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        left: 12,
        right: 12,
        bottom: 12,
      ),
      child: Column(children: [
        Row(children: [
          if (_webViewVisible)
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 18),
              onPressed: () async {
                final canGoBack = await _webController?.canGoBack() ?? false;
                if (canGoBack) {
                  await _webController?.goBack();
                } else {
                  _goHome();
                }
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            )
          else
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: const Icon(Icons.shield_rounded, color: Colors.white, size: 17),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: _webViewVisible
                ? Row(
                    children: [
                      Expanded(
                        child: Text(
                          _domain(_currentUrl),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: _goHome,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.2)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.home_rounded, color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'Home',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GenuPort',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Secure Document Portal',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
          ),
          if (_webViewVisible) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
              onPressed: () => _webController?.reload(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ] else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Row(children: [
                const Icon(Icons.lock_rounded, color: Colors.white70, size: 11),
                const SizedBox(width: 4),
                Text(
                  _encReady ? 'Encrypted' : 'Initializing…',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ]),
            ),
        ]),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => _urlFocusNode.requestFocus(),
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(children: [
              const SizedBox(width: 14),
              const Icon(Icons.search_rounded, color: GPColors.textMuted, size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _urlFocusNode,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.go,
                  style: const TextStyle(fontSize: 14, color: GPColors.textPrimary),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'Search or enter URL…',
                    hintStyle: TextStyle(color: GPColors.textMuted, fontSize: 14),
                  ),
                  onSubmitted: (val) {
                    if (val.trim().isNotEmpty) _loadUrl(val);
                  },
                ),
              ),
              if (_searchController.text.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    _urlFocusNode.unfocus();
                  },
                  child: const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Icon(Icons.cancel_rounded, color: GPColors.textMuted, size: 17),
                  ),
                )
              else
                const SizedBox(width: 12),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildStatusBar() {
    final isErr = _status.startsWith('❌');
    final isDone = _status.startsWith('✓');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      color: isDone
          ? GPColors.surfaceTint
          : isErr
          ? const Color(0xFFFFF3F3)
          : GPColors.surfaceTint,
      child: Row(children: [
        if (isDone)
          const Icon(Icons.check_circle_rounded, size: 13, color: GPColors.primaryLight)
        else if (isErr)
          const Icon(Icons.error_rounded, size: 13, color: GPColors.error)
        else
          const SizedBox(
            width: 13,
            height: 13,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: GPColors.primaryMid,
            ),
          ),
        const SizedBox(width: 8),
        Text(
          _status,
          style: TextStyle(
            fontSize: 11,
            color: isErr ? GPColors.error : GPColors.textSecondary,
          ),
        ),
      ]),
    );
  }

  Widget _buildDashboard() {
    final countries = TrustedSitesData.getAllCountries();
    final countryData = TrustedSitesData.getAllCountriesTrustedSites()[_selectedCountry] ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Security badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: GPColors.surfaceTint,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: GPColors.borderGreen),
            ),
            child: Row(children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: GPColors.primaryLight.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  color: GPColors.primaryLight,
                  size: 17,
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AES-256 Encrypted',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: GPColors.primary,
                    ),
                  ),
                  Text(
                    'All downloads secured on your device',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: GPColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ]),
          ),
          const SizedBox(height: 24),

          // ✅ UPDATED: Better styled country dropdown
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Country'.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: GPColors.textMuted,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: GPColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: GPColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: GPColors.primary.withOpacity(0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCountry,
                    isExpanded: true,
                    menuMaxHeight: 350,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    items: countries.map((country) {
                      return DropdownMenuItem<String>(
                        value: country,
                        child: Row(
                          children: [
                            Icon(
                              Icons.public_rounded,
                              size: 16,
                              color: GPColors.primaryMid,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              country,
                              style: const TextStyle(
                                fontSize: 14,
                                color: GPColors.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedCountry = value);
                      }
                    },
                    icon: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(
                        Icons.arrow_drop_down_rounded,
                        color: GPColors.primaryMid,
                        size: 24,
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                      color: GPColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Dynamic sections
          ...countryData.entries.map((entry) {
            final categoryName = entry.key;
            final sites = entry.value;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label(categoryName),
                const SizedBox(height: 10),
                _buildTileGroup(sites),
                const SizedBox(height: 22),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTileGroup(List<TrustedSite> tiles) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.05,
      ),
      itemCount: tiles.length,
      itemBuilder: (_, i) {
        final t = tiles[i];
        return GestureDetector(
          onTap: () => _loadUrl(t.url),
          child: Container(
            decoration: BoxDecoration(
              color: GPColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: GPColors.border),
              boxShadow: [
                BoxShadow(
                  color: GPColors.primary.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(t.icon, color: GPColors.primaryMid, size: 22),
                const SizedBox(height: 7),
                Text(
                  t.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: GPColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: GPColors.textMuted,
      letterSpacing: 0.4,
    ),
  );
}