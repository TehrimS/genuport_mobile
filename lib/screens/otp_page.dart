import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:genuport/services/auth_service.dart';
import 'package:genuport/themes/gp_colors.dart';
import 'consent_page.dart';

class OtpPage extends StatefulWidget {
  final String phone;
  final String loanId;
  final String devOtp;

  const OtpPage({
    super.key,
    required this.phone,
    required this.loanId,
    required this.devOtp,
  });

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage>
    with SingleTickerProviderStateMixin {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  final AuthService _authService = AuthService();

  int secondsRemaining = 55;
  Timer? _timer;
  bool isVerifying = false;
  bool isResending = false;
  String? errorMessage;
  AnimationController? _animController;
  Animation<double> _fadeAnim = const AlwaysStoppedAnimation(1.0);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController!, curve: Curves.easeOut);
    _animController!.forward();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animController?.dispose();
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => secondsRemaining = 55);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (secondsRemaining == 0) {
        t.cancel();
      } else {
        setState(() => secondsRemaining--);
      }
    });
  }

  Future<void> _verifyOtp() async {
    final otp = _controllers.map((c) => c.text).join();
    if (otp.length != 6) {
      setState(() => errorMessage = 'Please enter the complete 6-digit OTP');
      return;
    }

    setState(() {
      isVerifying = true;
      errorMessage = null;
    });

    try {
      final verified = await _authService.verifyOtp(phone: widget.phone, otp: otp);
      if (!mounted) return;
      if (verified) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ConsentPage()),
        );
      } else {
        setState(() => errorMessage = 'Invalid OTP. Please try again.');
      }
    } catch (e) {
      setState(() => errorMessage = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => isVerifying = false);
    }
  }

  Future<void> _resendOtp() async {
    if (secondsRemaining > 0 || isResending) return;
    setState(() { isResending = true; errorMessage = null; });
    try {
      await _authService.sendOtp(phone: widget.phone, loanId: widget.loanId);
      _startTimer();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: GPColors.primary,
            content: const Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text('OTP resent successfully', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => errorMessage = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => isResending = false);
    }
  }

  String _maskedPhone(String phone) {
    if (phone.length < 4) return phone;
    return '${phone.substring(0, 2)}${'•' * (phone.length - 4)}${phone.substring(phone.length - 2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GPColors.surface,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Verify your number',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: GPColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 13, color: GPColors.textMuted),
                        children: [
                          const TextSpan(text: 'OTP sent to '),
                          TextSpan(
                            text: '+91 ${_maskedPhone(widget.phone)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: GPColors.primaryMid,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 36),

                    // OTP boxes
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(6, (i) => _buildOtpBox(i)),
                    ),

                    if (errorMessage != null) ...[
                      const SizedBox(height: 16),
                      _buildErrorBanner(errorMessage!),
                    ],

                    const SizedBox(height: 28),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isVerifying ? null : _verifyOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GPColors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: GPColors.primary.withOpacity(0.5),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: isVerifying
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Verify OTP',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward_rounded, size: 18),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Center(
                      child: GestureDetector(
                        onTap: secondsRemaining == 0 && !isResending ? _resendOtp : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: GPColors.surfaceTint,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: GPColors.border),
                          ),
                          child: isResending
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: GPColors.primaryLight),
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.refresh_rounded,
                                      size: 14,
                                      color: secondsRemaining > 0
                                          ? GPColors.textMuted
                                          : GPColors.primaryMid,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      secondsRemaining > 0
                                          ? 'Resend in ${secondsRemaining}s'
                                          : 'Resend OTP',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: secondsRemaining > 0
                                            ? GPColors.textMuted
                                            : GPColors.primaryMid,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
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

  Widget _buildOtpBox(int index) {
    return SizedBox(
      width: 46,
      height: 52,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: GPColors.textPrimary,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: GPColors.surfaceTint,
          contentPadding: EdgeInsets.zero,
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
            borderSide: const BorderSide(color: GPColors.primaryLight, width: 2),
          ),
        ),
        onChanged: (val) {
          if (val.isNotEmpty && index < 5) {
            _focusNodes[index + 1].requestFocus();
          } else if (val.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
          // Auto-verify when all filled
          final otp = _controllers.map((c) => c.text).join();
          if (otp.length == 6) _verifyOtp();
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 8,
        right: 20,
        bottom: 20,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.25)),
            ),
            child: const Icon(Icons.shield_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'GenuPort',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'OTP Verification',
                style: TextStyle(color: Colors.white60, fontSize: 10, letterSpacing: 0.4),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3F3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFCDD2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFE53935), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFFE53935)),
            ),
          ),
        ],
      ),
    );
  }
}