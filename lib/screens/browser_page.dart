import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:genuport/services/file_metadata.dart';
import 'package:genuport/services/pdf_unlocker.dart';
import 'package:genuport/services/encryption_service.dart';
import 'package:genuport/themes/gp_colors.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'downloads_page.dart';
// ─────────────────────────────────────────────
//  JavaScript: overlay trending searches
// ─────────────────────────────────────────────

class BrowserPage extends StatefulWidget {
  final String? initialUrl;
  const BrowserPage({this.initialUrl, super.key});

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage>
    with TickerProviderStateMixin {
  InAppWebViewController? _controller;
  late TextEditingController _urlController;
  final _encryptionService = EncryptionService();
  final FocusNode _urlFocusNode = FocusNode();

  String _status = "";
  bool _encryptionInitialized = false;
  bool _isLoading = false;
  double _loadingProgress = 0.0;
  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _isEditingUrl = false;
  String _displayDomain = "www.google.com";
  String _currentUrl = "https://www.google.com/";
  late TextEditingController _overlaySearchController;

  late AnimationController _bannerAnimController;
  late Animation<double> _bannerAnim;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(
      text: widget.initialUrl ?? "https://www.google.com",
    );
    _overlaySearchController = TextEditingController();
    _displayDomain = _extractDomain(
      widget.initialUrl ?? "https://www.google.com",
    );

    _bannerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _bannerAnim = CurvedAnimation(
      parent: _bannerAnimController,
      curve: Curves.easeOut,
    );

    _urlFocusNode.addListener(() {
      setState(() => _isEditingUrl = _urlFocusNode.hasFocus);
      if (_urlFocusNode.hasFocus) {
        _urlController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _urlController.text.length,
        );
      }
    });

    Future.delayed(Duration.zero, () async {
      await _initializeEncryption();
      await _requestStoragePermission();
    });
  }

  String _extractDomain(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.isEmpty ? url : uri.host;
    } catch (_) {
      return url;
    }
  }

  bool _checkIsGoogleHomepage(String url) {
    return url == 'https://www.google.com/' ||
        url == 'https://www.google.com' ||
        url == 'http://www.google.com/' ||
        url == 'http://www.google.com';
  }

  Future<void> _initializeEncryption() async {
    try {
      await _encryptionService.initialize();
      setState(() => _encryptionInitialized = true);
      _bannerAnimController.forward();
    } catch (e) {
      _showSnackBar('Encryption init failed: $e', isError: true);
    }
  }

  Future<bool> _requestStoragePermission() async {
    if (!Platform.isAndroid) return true;
    PermissionStatus s = await Permission.manageExternalStorage.status;
    if (!s.isGranted) s = await Permission.manageExternalStorage.request();
    if (s.isGranted) return true;
    PermissionStatus s2 = await Permission.storage.status;
    if (!s2.isGranted) s2 = await Permission.storage.request();
    if (s2.isGranted) return true;
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _buildPermissionDialog(),
      );
    }
    return false;
  }

  @override
  void didUpdateWidget(BrowserPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialUrl != null &&
        widget.initialUrl != oldWidget.initialUrl) {
      _urlController.text = widget.initialUrl!;
      _controller?.loadUrl(
        urlRequest: URLRequest(url: WebUri(widget.initialUrl!)),
      );
    }
  }

  void _showSnackBar(
    String msg, {
    bool isError = false,
    VoidCallback? action,
    String? actionLabel,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: isError ? const Color(0xFFC62828) : GPColors.primary,
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
        action: action != null
            ? SnackBarAction(
                label: actionLabel ?? 'View',
                textColor: GPColors.accent,
                onPressed: action,
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GPColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            // ── Branded App Bar ──
            _buildAppBar(),
            // ── Nav + URL row ──
            _buildNavRow(),
            // ── Loading indicator ──
            if (_isLoading)
              SizedBox(
                height: 2,
                child: LinearProgressIndicator(
                  value: _loadingProgress > 0 ? _loadingProgress : null,
                  backgroundColor: GPColors.primaryMid.withOpacity(0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            // ── WebView + Trending Overlay ──
            Expanded(
              child: Stack(
                children: [
                  _buildWebView(),
                  if (_checkIsGoogleHomepage(_currentUrl))
                    _buildGoogleOverlay(),
                ],
              ),
            ),
            // ── Status bar ──
            if (_status.isNotEmpty) _buildStatusBar(),
            // ── Security banner at bottom ──
            if (_encryptionInitialized)
              FadeTransition(
                opacity: _bannerAnim,
                child: _buildSecurityBanner(),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Branded App Bar ───────────────────────
  Widget _buildAppBar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Shield icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: Colors.white.withOpacity(0.25)),
            ),
            child: const Icon(
              Icons.shield_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          // Title
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'GenuPort Browser',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              Text(
                'Secure · Encrypted',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 10,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Downloads button
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DownloadsPage()),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.folder_rounded,
                    color: Colors.white,
                    size: 15,
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'Downloads',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Nav Row (back/fwd/refresh + URL pill) ──
  Widget _buildNavRow() {
    return Container(
      color: GPColors.primary,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
      child: Row(
        children: [
          _buildNavBtn(
            icon: Icons.arrow_back_ios_rounded,
            enabled: _canGoBack,
            onTap: () => _controller?.goBack(),
          ),
          _buildNavBtn(
            icon: Icons.arrow_forward_ios_rounded,
            enabled: _canGoForward,
            onTap: () => _controller?.goForward(),
          ),
          _buildNavBtn(
            icon: _isLoading ? Icons.close_rounded : Icons.refresh_rounded,
            enabled: true,
            onTap: () =>
                _isLoading ? _controller?.stopLoading() : _controller?.reload(),
          ),
          const SizedBox(width: 6),
          // ── Pill URL bar ──
          Expanded(
            child: GestureDetector(
              onTap: () => _urlFocusNode.requestFocus(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 36,
                decoration: BoxDecoration(
                  color: _isEditingUrl
                      ? Colors.white
                      : Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isEditingUrl
                        ? GPColors.primaryLight
                        : Colors.white.withOpacity(0.3),
                    width: _isEditingUrl ? 1.5 : 1,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(
                      _urlController.text.startsWith('https')
                          ? Icons.lock_rounded
                          : Icons.lock_open_rounded,
                      size: 12,
                      color: _isEditingUrl
                          ? GPColors.primaryLight
                          : Colors.white70,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _isEditingUrl
                          ? TextField(
                              controller: _urlController,
                              focusNode: _urlFocusNode,
                              keyboardType: TextInputType.url,
                              textInputAction: TextInputAction.go,
                              style: const TextStyle(
                                fontSize: 13,
                                color: GPColors.textPrimary,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                                hintText: 'Search or enter URL…',
                                hintStyle: TextStyle(
                                  color: GPColors.textMuted,
                                  fontSize: 13,
                                ),
                              ),
                              onSubmitted: (val) {
                                _urlFocusNode.unfocus();
                                _controller?.loadUrl(
                                  urlRequest: URLRequest(
                                    url: WebUri(_smartUrl(val)),
                                  ),
                                );
                              },
                            )
                          : Text(
                              _displayDomain,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                    ),
                    if (_isEditingUrl && _urlController.text.isNotEmpty)
                      GestureDetector(
                        onTap: () => _urlController.clear(),
                        child: const Icon(
                          Icons.cancel_rounded,
                          size: 15,
                          color: GPColors.textMuted,
                        ),
                      ),
                    if (!_isEditingUrl && _isLoading)
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: Colors.white70,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavBtn({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 32,
        height: 32,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          color: enabled ? Colors.white.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 15,
          color: enabled ? Colors.white : Colors.white30,
        ),
      ),
    );
  }

  Widget _buildWebView() {
    final isGoogleHome = _checkIsGoogleHomepage(_currentUrl);

    return Stack(
      children: [
        InAppWebView(
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
            final urlStr = url?.toString() ?? "";
            setState(() {
              _urlController.text = urlStr;
              _currentUrl = urlStr;
              _displayDomain = _extractDomain(urlStr);
              _isLoading = true;
              _loadingProgress = 0;
            });
            _updateNavButtons();
          },
          onProgressChanged: (controller, progress) {
            setState(() => _loadingProgress = progress / 100.0);
          },
          onLoadStop: (controller, url) async {
            final urlStr = url?.toString() ?? "";
            await _injectBlobInterceptor(controller);
            setState(() {
              _urlController.text = urlStr;
              _currentUrl = urlStr;
              _displayDomain = _extractDomain(urlStr);
              _isLoading = false;
            });
            _updateNavButtons();
          },
          onDownloadStartRequest: (controller, request) async {
            await _handleDownload(request, controller);
          },
        ),

        // ── Flutter overlay: covers trending on Google homepage only ──
        if (isGoogleHome)
          Positioned(
            left: 0,
            right: 0,
            top: 290,
            bottom: 0,
            child: _buildGoogleOverlay(),
          ),
      ],
    );
  }

  Widget _buildGoogleOverlay() {
    return Container(
      color: Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        physics: const ClampingScrollPhysics(),
        children: [
          Container(
            height: 12,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.white],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [GPColors.primaryMid, GPColors.primary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Icon(
                        Icons.shield_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Quick Access',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: GPColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Search bar on top ──
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        color: GPColors.primaryMid,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _overlaySearchController,
                          keyboardType: TextInputType.url,
                          textInputAction: TextInputAction.go,
                          style: const TextStyle(
                            fontSize: 13,
                            color: GPColors.textPrimary,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            hintText: 'Type a URL or search anything…',
                            hintStyle: TextStyle(
                              color: GPColors.textMuted,
                              fontSize: 13,
                            ),
                          ),
                          onSubmitted: (val) {
                            if (val.trim().isEmpty) return;
                            _overlaySearchController.clear();
                            _controller?.loadUrl(
                              urlRequest: URLRequest(
                                url: WebUri(_smartUrl(val)),
                              ),
                            );
                          },
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          final val = _overlaySearchController.text.trim();
                          if (val.isEmpty) return;
                          _overlaySearchController.clear();
                          _controller?.loadUrl(
                            urlRequest: URLRequest(url: WebUri(_smartUrl(val))),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: GPColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Go',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── Banking ──
                _sectionLabel('Banking'),
                _quickTile(
                  Icons.account_balance_rounded,
                  'HDFC Bank',
                  'netbanking.hdfcbank.com',
                  'https://netbanking.hdfcbank.com',
                ),
                _quickTile(
                  Icons.account_balance_rounded,
                  'SBI Net Banking',
                  'onlinesbi.sbi.in',
                  'https://www.onlinesbi.sbi.in',
                ),
                _quickTile(
                  Icons.account_balance_rounded,
                  'ICICI Bank',
                  'icicibank.com',
                  'https://www.icicibank.com/online/accounts',
                ),
                _quickTile(
                  Icons.account_balance_rounded,
                  'Axis Bank',
                  'axisbank.com',
                  'https://www.axisbank.com/online-banking',
                ),
                _quickTile(
                  Icons.account_balance_rounded,
                  'Kotak Bank',
                  'kotak.com',
                  'https://netbanking.kotak.com',
                ),
                _quickTile(
                  Icons.credit_card_rounded,
                  'Credit Card Stmt',
                  'Download statements',
                  'https://www.google.com/search?q=credit+card+statement+download',
                ),

                // ── Government ──
                _sectionLabel('Government & Identity'),
                _quickTile(
                  Icons.badge_rounded,
                  'DigiLocker',
                  'digilocker.gov.in',
                  'https://digilocker.gov.in',
                ),
                _quickTile(
                  Icons.fingerprint_rounded,
                  'Aadhaar / UIDAI',
                  'myaadhaar.uidai.gov.in',
                  'https://myaadhaar.uidai.gov.in',
                ),
                _quickTile(
                  Icons.receipt_long_rounded,
                  'Income Tax',
                  'incometax.gov.in',
                  'https://www.incometax.gov.in',
                ),
                _quickTile(
                  Icons.credit_score_rounded,
                  'PAN Services',
                  'tin.tin.nsdl.com',
                  'https://www.tin.nsdl.com',
                ),
                _quickTile(
                  Icons.directions_car_rounded,
                  'Parivahan',
                  'DL & RC documents',
                  'https://parivahan.gov.in',
                ),
                _quickTile(
                  Icons.home_work_rounded,
                  'GST Portal',
                  'gst.gov.in',
                  'https://www.gst.gov.in',
                ),
                _quickTile(
                  Icons.business_rounded,
                  'MCA21',
                  'Company filings',
                  'https://www.mca.gov.in',
                ),

                // ── Finance & Credit ──
                _sectionLabel('Finance & Credit'),
                _quickTile(
                  Icons.credit_score_rounded,
                  'CIBIL Score',
                  'cibil.com',
                  'https://www.cibil.com',
                ),
                _quickTile(
                  Icons.trending_up_rounded,
                  'NSDL / CDSL',
                  'Demat & holdings',
                  'https://www.nsdl.co.in',
                ),
                _quickTile(
                  Icons.savings_rounded,
                  'EPFO / PF',
                  'passbook.epfindia.gov.in',
                  'https://passbook.epfindia.gov.in',
                ),
                _quickTile(
                  Icons.account_balance_wallet_rounded,
                  'NSE / BSE',
                  'Stock exchange portals',
                  'https://www.nseindia.com',
                ),

                // ── Insurance ──
                _sectionLabel('Insurance'),
                _quickTile(
                  Icons.health_and_safety_rounded,
                  'LIC',
                  'licindia.in',
                  'https://licindia.in',
                ),
                _quickTile(
                  Icons.security_rounded,
                  'IRDAI',
                  'Insurance regulator',
                  'https://www.irdai.gov.in',
                ),
                _quickTile(
                  Icons.local_hospital_rounded,
                  'Health Insurance',
                  'Download policy docs',
                  'https://www.google.com/search?q=health+insurance+policy+download',
                ),

                // ── Loans ──
                _sectionLabel('Loans'),
                _quickTile(
                  Icons.home_rounded,
                  'Home Loan Stmt',
                  'Download statement',
                  'https://www.google.com/search?q=home+loan+statement+download',
                ),
                _quickTile(
                  Icons.directions_car_rounded,
                  'Car Loan Stmt',
                  'Download statement',
                  'https://www.google.com/search?q=car+loan+statement+download',
                ),
                _quickTile(
                  Icons.school_rounded,
                  'Education Loan',
                  'Download statement',
                  'https://www.google.com/search?q=education+loan+statement+download',
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: GPColors.textMuted,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _quickTile(IconData icon, String title, String subtitle, String url) {
    return GestureDetector(
      onTap: () =>
          _controller?.loadUrl(urlRequest: URLRequest(url: WebUri(url))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
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
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: GPColors.surfaceTint,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: GPColors.border),
              ),
              child: Icon(icon, color: GPColors.primaryMid, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: GPColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: GPColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 12,
              color: GPColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    final isError = _status.startsWith('❌');
    final isDone = _status.startsWith('✓');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      color: isDone
          ? GPColors.surfaceTint
          : isError
          ? const Color(0xFFFFF3F3)
          : GPColors.surfaceTint,
      child: Row(
        children: [
          if (isDone)
            const Icon(
              Icons.check_circle_rounded,
              size: 13,
              color: GPColors.primaryLight,
            )
          else if (isError)
            const Icon(Icons.error_rounded, size: 13, color: Color(0xFFE53935))
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
          Expanded(
            child: Text(
              _status,
              style: TextStyle(
                fontSize: 11,
                color: isError ? const Color(0xFFE53935) : GPColors.textMuted,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: GPColors.surfaceTint,
        border: Border(top: BorderSide(color: GPColors.border, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.verified_user_rounded,
            size: 12,
            color: GPColors.primaryLight,
          ),
          const SizedBox(width: 6),
          Text(
            'AES-256 encrypted downloads · GenuPort Secure Browser',
            style: TextStyle(
              fontSize: 11,
              color: GPColors.primaryMid,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  void _updateNavButtons() async {
    final back = await _controller?.canGoBack() ?? false;
    final fwd = await _controller?.canGoForward() ?? false;
    if (mounted) {
      setState(() {
        _canGoBack = back;
        _canGoForward = fwd;
      });
    }
  }

  String _smartUrl(String input) {
    input = input.trim();
    if (input.contains(' ') ||
        (!input.contains('.') && !input.startsWith('localhost'))) {
      return 'https://www.google.com/search?q=${Uri.encodeComponent(input)}';
    }
    if (!input.startsWith('http://') && !input.startsWith('https://')) {
      return 'https://$input';
    }
    return input;
  }

  Future<void> _injectBlobInterceptor(InAppWebViewController controller) async {
    await controller.evaluateJavascript(
      source: """
      (function() {
        window.blobCache = window.blobCache || {};
        const orig = URL.createObjectURL;
        URL.createObjectURL = function(blob) {
          const url = orig.call(this, blob);
          if (blob instanceof Blob) {
            const r = new FileReader();
            r.onloadend = () => { window.blobCache[url] = r.result.split(',')[1]; };
            r.readAsDataURL(blob);
          }
          return url;
        };
      })();
    """,
    );
  }

  Widget _buildPermissionDialog() {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.folder_special_rounded, color: GPColors.primary),
                  SizedBox(width: 8),
                  Text(
                    'Storage Access Required',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: GPColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'GenuPort needs storage permission to securely save downloads.\n\nPlease enable "All files access" in Settings.',
                style: TextStyle(
                  fontSize: 13.5,
                  color: GPColors.textMuted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    openAppSettings();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GPColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: const Text(
                    'Open Settings',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleDownload(
    DownloadStartRequest request,
    InAppWebViewController controller,
  ) async {
    try {
      if (!_encryptionInitialized) {
        throw Exception('Encryption not initialized');
      }
      final fileName = request.suggestedFilename ?? 'downloaded_file';
      setState(() => _status = "Downloading $fileName…");

      File? file;
      if (request.url.toString().startsWith('blob:')) {
        file = await _downloadBlobUrl(request, controller);
      } else {
        file = await _saveToDownloads(request);
      }
      setState(() => _status = "✓ Encrypted & saved");
      _showSnackBar(
        '🔒 $fileName downloaded & encrypted',
        action: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DownloadsPage()),
        ),
        actionLabel: 'View',
      );
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _status = "");
      });
    } catch (e) {
      setState(() => _status = "❌ Download failed");
      _showSnackBar('Download failed: $e', isError: true);
    }
  }

  Future<File> _downloadBlobUrl(
    DownloadStartRequest request,
    InAppWebViewController controller,
  ) async {
    if (!await _requestStoragePermission()) {
      throw Exception('Storage permission denied');
    }
    final blobUrl = request.url.toString();
    final fileName = request.suggestedFilename ?? "downloaded_file";

    var result = await controller.evaluateJavascript(
      source:
          """
      (function() {
        if (window.blobCache && window.blobCache['$blobUrl']) return window.blobCache['$blobUrl'];
        return null;
      })();
    """,
    );

    if (result == null || result.toString() == 'null') {
      result = await controller.evaluateJavascript(
        source:
            """
        (async function() {
          try {
            const resp = await fetch('$blobUrl');
            if (!resp.ok) return 'ERROR: HTTP ' + resp.status;
            const blob = await resp.blob();
            if (blob.size === 0) return 'ERROR: Empty blob';
            return new Promise((res, rej) => {
              const r = new FileReader();
              r.onloadend = () => res(r.result.split(',')[1]);
              r.onerror = () => rej('FileReader error');
              r.readAsDataURL(blob);
            });
          } catch (e) { return 'ERROR: ' + e.message; }
        })();
      """,
      );
    }

    if (result == null ||
        result.toString().isEmpty ||
        result.toString() == '{}') {
      throw Exception('Blob download failed');
    }
    if (result.toString().startsWith('ERROR:')) {
      throw Exception(result.toString());
    }

    var bytes = base64Decode(result.toString());
    var finalBytes = Uint8List.fromList(bytes);
    if (fileName.toLowerCase().endsWith('.pdf')) {
      finalBytes = await _checkPdf(finalBytes);
    }

    final encryptedBytes = await _encryptionService.encryptFile(finalBytes);
    return _saveEncryptedFile(finalBytes, fileName);
  }

  Future<File> _saveToDownloads(DownloadStartRequest request) async {
    if (!await _requestStoragePermission()) {
      throw Exception('Storage permission denied');
    }
    final fileName = request.suggestedFilename ?? "downloaded_file";
    final client = HttpClient();
    final req = await client.getUrl(Uri.parse(request.url.toString()));
    final res = await req.close();
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    final bytes = await consolidateHttpClientResponseBytes(res);
    var finalBytes = Uint8List.fromList(bytes);
    if (fileName.toLowerCase().endsWith('.pdf') &&
        PdfUnlocker.isPasswordProtected(finalBytes)) {
      _showSnackBar('ℹ️ Password-protected PDF. Enter password when viewing.');
    }
    final encryptedBytes = await _encryptionService.encryptFile(finalBytes);
    return _saveEncryptedFile(finalBytes, fileName);
  }

  Future<Uint8List> _checkPdf(Uint8List pdfBytes) async {
    setState(() => _status = "Processing PDF…");
    try {
      if (PdfUnlocker.isPasswordProtected(pdfBytes)) {
        _showSnackBar(
          'ℹ️ Password-protected PDF. Enter password when viewing.',
        );
      }
    } catch (_) {}
    return pdfBytes;
  }

 // Update this function to save encrypted files in a dedicated "GenuPortDownloads" folder on both Android and iOS, with proper permission handling and user feedback.
  Future<File> _saveEncryptedFile(
  Uint8List originalBytes,  // now takes ORIGINAL bytes, not pre-encrypted
  String fileName, {
  String sourceUrl = '',
  String fetchedUrl = '',
}) async {
  // Build and embed metadata
  final meta = FileMetadata.create(
    fileName:      fileName,
    sourceUrl:     sourceUrl.isNotEmpty ? sourceUrl : fetchedUrl,
    fetchedUrl:    fetchedUrl,
    originalBytes: originalBytes,
  );
  final encryptedBytes = await _encryptionService.encryptFile(
    originalBytes,
    metadata: meta.toJson(),
  );

  Directory directory;
  if (Platform.isAndroid) {
    directory = Directory('/storage/emulated/0/Download/GenuPortDownloads');
    if (!await directory.exists()) await directory.create(recursive: true);
  } else if (Platform.isIOS) {
    final docDir = await getApplicationDocumentsDirectory();
    directory = Directory('${docDir.path}/GenuPortDownloads');
    if (!await directory.exists()) await directory.create(recursive: true);
  } else {
    throw Exception('Unsupported platform');
  }

  // Always .pdf extension
  String baseName = fileName.endsWith('.pdf') ? fileName : '$fileName.pdf';
  String filePath = '${directory.path}/$baseName';
  int counter = 1;
  while (File(filePath).existsSync()) {
    final parts = baseName.split('.');
    final base  = parts.sublist(0, parts.length - 1).join('.');
    final ext   = parts.last;
    filePath = '${directory.path}/${base}_$counter.$ext';
    counter++;
  }
  final file = File(filePath);
  await file.writeAsBytes(encryptedBytes);
  return file;
}


  @override
  void dispose() {
    _urlController.dispose();
    _overlaySearchController.dispose();
    _urlFocusNode.dispose();
    _bannerAnimController.dispose();
    super.dispose();
  }
}
