import 'package:flutter/material.dart';
import 'package:genuport/services/auth_service.dart';
import 'package:genuport/themes/gp_colors.dart';
import 'otp_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _loanIdController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  String? _error;
  AnimationController? _anim;
  Animation<double> _fade = const AlwaysStoppedAnimation(1.0);

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _fade = CurvedAnimation(parent: _anim!, curve: Curves.easeOut);
    _anim!.forward();
  }

  @override
  void dispose() {
    _anim?.dispose();
    _phoneController.dispose();
    _loanIdController.dispose();
    super.dispose();
  }

  bool _validPhone(String p) => RegExp(r'^[6-9]\d{9}$').hasMatch(p.replaceAll(RegExp(r'[^0-9]'), ''));

  Future<void> _submit() async {
    final phone = _phoneController.text.trim();
    final loanId = _loanIdController.text.trim();
    if (phone.isEmpty || loanId.isEmpty) { setState(() => _error = 'Please fill in all fields'); return; }
    if (!_validPhone(phone)) { setState(() => _error = 'Enter a valid 10-digit mobile number'); return; }

    setState(() { _isLoading = true; _error = null; });
    try {
      await _authService.sendOtp(phone: phone, loanId: loanId);
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => OtpPage(phone: phone, loanId: loanId, devOtp: '123456')));
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GPColors.surfacePage,   // neutral gray, NOT green
      body: Column(
        children: [
          _header(),
          Expanded(
            child: FadeTransition(
              opacity: _fade,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Sign in', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: GPColors.textPrimary, letterSpacing: -0.4)),
                    const SizedBox(height: 4),
                    const Text('Access your secure document portal', style: TextStyle(fontSize: 13.5, color: GPColors.textSecondary)),
                    const SizedBox(height: 24),

                    // White card for form
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: GPColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: GPColors.border),
                      ),
                      child: Column(children: [
                        _field('Mobile Number', _phoneController, 'Enter 10-digit number', Icons.phone_android_rounded, keyboardType: TextInputType.phone, prefix: '+91  '),
                        const SizedBox(height: 16),
                        _field('Loan ID', _loanIdController, 'Your loan reference', Icons.badge_outlined),
                      ]),
                    ),

                    if (_error != null) ...[const SizedBox(height: 14), _errorBanner(_error!)],
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity, height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GPColors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: GPColors.primaryLight.withOpacity(0.4),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Text('Send OTP', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward_rounded, size: 17),
                              ]),
                      ),
                    ),

                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        'By continuing you agree to our Terms & Privacy Policy',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11.5, color: GPColors.textMuted, height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _securityNote(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 20, left: 20, right: 20, bottom: 28),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: const Icon(Icons.shield_rounded, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('GenuPort', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700)),
          Text('Secure Document Portal', style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 0.3)),
        ]),
      ]),
    );
  }

  Widget _field(String label, TextEditingController ctrl, String hint, IconData icon, {TextInputType keyboardType = TextInputType.text, String? prefix}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: GPColors.textSecondary, letterSpacing: 0.2)),
        const SizedBox(height: 7),
        TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 14, color: GPColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: GPColors.textMuted, fontSize: 14),
            prefixIcon: Icon(icon, color: GPColors.textMuted, size: 18),
            prefixText: prefix,
            prefixStyle: const TextStyle(color: GPColors.textMuted, fontSize: 14),
            filled: true,
            fillColor: GPColors.surfacePage,   // neutral gray fill, not green
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: GPColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: GPColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: GPColors.primaryLight, width: 1.5)),
          ),
        ),
      ],
    );
  }

  Widget _errorBanner(String msg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: GPColors.errorSurface, borderRadius: BorderRadius.circular(10), border: Border.all(color: GPColors.errorBorder)),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded, color: GPColors.error, size: 15),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: const TextStyle(fontSize: 12.5, color: GPColors.error))),
      ]),
    );
  }

  Widget _securityNote() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: GPColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GPColors.border),
      ),
      child: Row(children: [
        const Icon(Icons.verified_user_rounded, color: GPColors.primaryLight, size: 16),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Your data is AES-256 encrypted and never shared without consent.',
            style: TextStyle(fontSize: 11.5, color: GPColors.textSecondary, height: 1.4),
          ),
        ),
      ]),
    );
  }
}