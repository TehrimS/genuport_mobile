import 'package:flutter/material.dart';
import 'package:genuport/themes/gp_colors.dart';
import 'info_page.dart';

class ConsentPage extends StatefulWidget {
  const ConsentPage({super.key});

  @override
  State<ConsentPage> createState() => _ConsentPageState();
}

class _ConsentPageState extends State<ConsentPage>
    with SingleTickerProviderStateMixin {
  bool isChecked = false;
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
  }

  @override
  void dispose() {
    _animController?.dispose();
    super.dispose();
  }

  void _proceed() {
    if (!isChecked) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const InfoPage(phone: '', loanId: '')),
    );
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
                      'Privacy & Consent',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: GPColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Please review and accept before continuing',
                      style: TextStyle(fontSize: 13, color: GPColors.textMuted),
                    ),

                    const SizedBox(height: 24),

                    // Consent card
                    Container(
                      decoration: BoxDecoration(
                        color: GPColors.surfaceTint,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: GPColors.border),
                      ),
                      child: Column(
                        children: [
                          _buildConsentPoint(
                            Icons.account_balance_rounded,
                            'Bank Statement Access',
                            'GenuPort will access your bank statements solely for loan verification purposes.',
                          ),
                          Divider(height: 1, color: GPColors.border),
                          _buildConsentPoint(
                            Icons.lock_rounded,
                            'Data Encryption',
                            'All documents are encrypted with AES-256 and stored securely on your device.',
                          ),
                          Divider(height: 1, color: GPColors.border),
                          _buildConsentPoint(
                            Icons.visibility_off_rounded,
                            'No Third-Party Sharing',
                            'Your data will never be sold or shared with third parties without your explicit consent.',
                          ),
                          Divider(height: 1, color: GPColors.border),
                          _buildConsentPoint(
                            Icons.delete_rounded,
                            'Right to Delete',
                            'You can request deletion of your data at any time by contacting support.',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Agree checkbox
                    GestureDetector(
                      onTap: () => setState(() => isChecked = !isChecked),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isChecked
                              ? GPColors.primaryLight.withOpacity(0.08)
                              : GPColors.surfaceTint,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isChecked ? GPColors.primaryLight : GPColors.border,
                            width: isChecked ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: isChecked ? GPColors.primaryLight : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isChecked ? GPColors.primaryLight : GPColors.border,
                                  width: 1.5,
                                ),
                              ),
                              child: isChecked
                                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'I agree to the Terms of Service and Privacy Policy',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: GPColors.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isChecked ? _proceed : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GPColors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: GPColors.border,
                          disabledForegroundColor: GPColors.textMuted,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Continue',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded, size: 18),
                          ],
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

  Widget _buildConsentPoint(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: GPColors.primaryLight.withOpacity(0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: GPColors.primaryLight, size: 17),
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
                    fontWeight: FontWeight.w700,
                    color: GPColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 12,
                    color: GPColors.textMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
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
                'Privacy & Consent',
                style: TextStyle(color: Colors.white60, fontSize: 10, letterSpacing: 0.4),
              ),
            ],
          ),
        ],
      ),
    );
  }
}