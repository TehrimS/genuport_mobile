import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:genuport/services/encryption_service.dart';
import 'package:genuport/services/pdf_unlocker.dart';
import 'package:genuport/services/file_metadata.dart';
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

  bool _webViewVisible = false;   // false = show home dashboard, true = show webview
  bool _isLoading = false;
  double _loadProgress = 0;
  bool _canGoBack = false;
  bool _encReady = false;
  String _status = '';
  String _currentUrl = '';

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

  void _loadUrl(String url) {
    final uri = _smartUrl(url);
    setState(() { _webViewVisible = true; _currentUrl = uri; });
    _webController?.loadUrl(urlRequest: URLRequest(url: WebUri(uri)));
    _searchController.text = uri;
    _urlFocusNode.unfocus();
  }

  void _goHome() {
    setState(() {
      _webViewVisible = false;
      _canGoBack = false;
      _currentUrl = '';
      _searchController.clear();
    });
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
    try { return Uri.parse(url).host.replaceFirst('www.', ''); } catch (_) { return url; }
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
      final file = req.url.toString().startsWith('blob:')
          ? await _downloadBlob(req, ctrl)
          : await _downloadHttp(req);
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
            onPressed: () {},
          ),
        ));
      }
      Future.delayed(const Duration(seconds: 3), () { if (mounted) setState(() => _status = ''); });
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

  Future<dynamic> _downloadBlob(DownloadStartRequest req, InAppWebViewController ctrl) async {
    final blobUrl = req.url.toString();
    final fileName = req.suggestedFilename ?? 'file';
    final sourceUrl = _currentUrl; // page the user was on when download started
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
    final encrypted = await _encryptionService.encryptFile(bytes);
    return _saveFile(encrypted, fileName, originalBytes: bytes, sourceUrl: sourceUrl, fetchedUrl: blobUrl);
  }

  Future<dynamic> _downloadHttp(DownloadStartRequest req) async {
    final fileName = req.suggestedFilename ?? 'file';
    final sourceUrl = _currentUrl;
    final fetchedUrl = req.url.toString();
    final client = HttpClient();
    final r = await client.getUrl(Uri.parse(fetchedUrl));
    final res = await r.close();
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    final bytes = await consolidateHttpClientResponseBytes(res);
    var finalBytes = Uint8List.fromList(bytes);
    if (fileName.toLowerCase().endsWith('.pdf') && PdfUnlocker.isPasswordProtected(finalBytes)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Password-protected PDF — enter password when viewing.'),
        ));
      }
    }
    final encrypted = await _encryptionService.encryptFile(finalBytes);
    return _saveFile(encrypted, fileName, originalBytes: finalBytes, sourceUrl: sourceUrl, fetchedUrl: fetchedUrl);
  }

  Future<dynamic> _saveFile(
    Uint8List encrypted,
    String fileName, {
    required Uint8List originalBytes,
    required String sourceUrl,
    required String fetchedUrl,
  }) async {
    late Directory dir;
    if (Platform.isAndroid) {
      dir = Directory('/storage/emulated/0/Download/GenuPortDownloads');
      if (!await dir.exists()) await dir.create(recursive: true);
    } else {
      final d = await getApplicationDocumentsDirectory();
      dir = Directory('${d.path}/GenuPortDownloads');
      if (!await dir.exists()) await dir.create(recursive: true);
    }
    final finalName = fileName.endsWith('.enc') ? fileName : '$fileName.enc';
    var path = '${dir.path}/$finalName';
    int i = 1;
    while (File(path).existsSync()) {
      final parts = fileName.split('.');
      path = parts.length > 1
          ? '${dir.path}/${parts.sublist(0, parts.length - 1).join('.')}_$i.${parts.last}.enc'
          : '${dir.path}/${fileName}_$i.enc';
      i++;
    }
    final file = File(path);
    await file.writeAsBytes(encrypted);

    // Save metadata sidecar
    final meta = FileMetadataStore.create(
      fileName: fileName,
      sourceUrl: sourceUrl.isNotEmpty ? sourceUrl : fetchedUrl,
      fetchedUrl: fetchedUrl,
      originalBytes: originalBytes,
    );
    await FileMetadataStore.save(file.path, meta);

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
    return Scaffold(
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
            // ── WebView — always in tree, hidden when not active ──
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
                  setState(() { _isLoading = true; _loadProgress = 0; _currentUrl = u; });
                  _updateNav();
                },
                onProgressChanged: (c, p) => setState(() => _loadProgress = p / 100),
                onLoadStop: (c, url) async {
                  await _injectBlobInterceptor(c);
                  final u = url?.toString() ?? '';
                  setState(() { _isLoading = false; _currentUrl = u; });
                  if (!_webViewVisible && u != 'https://www.google.com/') {
                    setState(() => _webViewVisible = true);
                  }
                  _updateNav();
                },
                onDownloadStartRequest: (c, req) => _handleDownload(req, c),
              ),
            ),
            // ── Dashboard — shown when no URL loaded ──
            if (!_webViewVisible) _buildDashboard(),
          ]),
        ),
      ]),
    );
  }

  Widget _buildAppBar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        left: 12,
        right: 12,
        bottom: 12,
      ),
      child: Column(children: [
        // Brand row
        Row(children: [
          if (_webViewVisible)
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 18),
              onPressed: () async {
                if (_canGoBack) {
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
              width: 34, height: 34,
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
                ? Text(
                    _domain(_currentUrl),
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  )
                : const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('GenuPort', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                      Text('Secure Document Portal', style: TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 0.3)),
                    ],
                  ),
          ),
          if (_webViewVisible) ...[
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
              onPressed: () => _webController?.reload(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            IconButton(
              icon: const Icon(Icons.folder_outlined, color: Colors.white, size: 20),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DownloadsPage())),
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
                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ]),
            ),
        ]),

        const SizedBox(height: 12),

        // ── Google-style search bar ──
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
      color: isDone ? GPColors.surfaceTint : isErr ? const Color(0xFFFFF3F3) : GPColors.surfaceTint,
      child: Row(children: [
        if (isDone) const Icon(Icons.check_circle_rounded, size: 13, color: GPColors.primaryLight)
        else if (isErr) const Icon(Icons.error_rounded, size: 13, color: GPColors.error)
        else const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 1.5, color: GPColors.primaryMid)),
        const SizedBox(width: 8),
        Text(_status, style: TextStyle(fontSize: 11, color: isErr ? GPColors.error : GPColors.textSecondary)),
      ]),
    );
  }

  Widget _buildDashboard() {
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
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: GPColors.primaryLight.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.verified_user_rounded, color: GPColors.primaryLight, size: 17),
              ),
              const SizedBox(width: 12),
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('AES-256 Encrypted', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: GPColors.primary)),
                Text('All downloads secured on your device', style: TextStyle(fontSize: 11.5, color: GPColors.textSecondary)),
              ]),
            ]),
          ),

          const SizedBox(height: 24),
          _label('Banking'),
          const SizedBox(height: 10),
          _buildTileGroup([
            _TileData('HDFC Bank',   Icons.account_balance_rounded, 'https://netbanking.hdfcbank.com'),
            _TileData('SBI',         Icons.account_balance_rounded, 'https://www.onlinesbi.sbi.in'),
            _TileData('ICICI Bank',  Icons.account_balance_rounded, 'https://www.icicibank.com/online/accounts'),
            _TileData('Axis Bank',   Icons.account_balance_rounded, 'https://www.axisbank.com/online-banking'),
            _TileData('Kotak Bank',  Icons.account_balance_rounded, 'https://netbanking.kotak.com'),
            _TileData('Credit Card', Icons.credit_card_rounded,     'https://www.google.com/search?q=credit+card+statement+download'),
          ]),

          const SizedBox(height: 22),
          _label('Government & Identity'),
          const SizedBox(height: 10),
          _buildTileGroup([
            _TileData('DigiLocker',   Icons.badge_rounded,           'https://digilocker.gov.in'),
            _TileData('Aadhaar',      Icons.fingerprint_rounded,     'https://myaadhaar.uidai.gov.in'),
            _TileData('Income Tax',   Icons.receipt_long_rounded,    'https://www.incometax.gov.in'),
            _TileData('PAN Services', Icons.credit_score_rounded,    'https://www.tin.nsdl.com'),
            _TileData('Parivahan',    Icons.directions_car_rounded,  'https://parivahan.gov.in'),
            _TileData('GST Portal',   Icons.home_work_rounded,       'https://www.gst.gov.in'),
          ]),

          const SizedBox(height: 22),
          _label('Finance & Credit'),
          const SizedBox(height: 10),
          _buildTileGroup([
            _TileData('CIBIL Score', Icons.credit_score_rounded,    'https://www.cibil.com'),
            _TileData('EPFO / PF',   Icons.savings_rounded,         'https://passbook.epfindia.gov.in'),
            _TileData('NSE / BSE',   Icons.trending_up_rounded,     'https://www.nseindia.com'),
            _TileData('LIC',         Icons.health_and_safety_rounded,'https://licindia.in'),
          ]),
        ],
      ),
    );
  }

  Widget _buildTileGroup(List<_TileData> tiles) {
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
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(t.icon, color: GPColors.primaryMid, size: 22),
                const SizedBox(height: 7),
                Text(t.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: GPColors.textPrimary),
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
    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: GPColors.textMuted, letterSpacing: 0.4),
  );

  void _updateNav() async {
    final back = await _webController?.canGoBack() ?? false;
    if (mounted) setState(() => _canGoBack = back);
  }
}

class _TileData {
  final String name;
  final IconData icon;
  final String url;
  const _TileData(this.name, this.icon, this.url);
}