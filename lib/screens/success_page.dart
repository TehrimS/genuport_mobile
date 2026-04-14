import 'package:flutter/material.dart';
import 'package:genuport/themes/gp_colors.dart';
import '../widgets/bottom_nav.dart';

class SuccessPage extends StatefulWidget {
  const SuccessPage({super.key});

  @override
  State<SuccessPage> createState() => _SuccessPageState();
}

class _SuccessPageState extends State<SuccessPage> with SingleTickerProviderStateMixin {
  AnimationController? _anim;
  Animation<double> _scale = const AlwaysStoppedAnimation(1.0);
  Animation<double> _fade  = const AlwaysStoppedAnimation(1.0);

  @override
  void initState() {
    super.initState();
    _anim  = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _scale = CurvedAnimation(parent: _anim!, curve: Curves.elasticOut);
    _fade  = CurvedAnimation(parent: _anim!, curve: Curves.easeOut);
    _anim!.forward();
  }

  @override
  void dispose() { _anim?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GPColors.surfacePage,
      body: Column(children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 20, left: 20, right: 20, bottom: 28),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(11), border: Border.all(color: Colors.white.withOpacity(0.2))),
              child: const Icon(Icons.shield_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('GenuPort', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700)),
              Text('Secure Document Portal', style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 0.3)),
            ]),
          ]),
        ),

        Expanded(
          child: FadeTransition(
            opacity: _fade,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                ScaleTransition(
                  scale: _scale,
                  child: Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      color: GPColors.primaryLight.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: GPColors.primaryLight.withOpacity(0.3), width: 1.5),
                    ),
                    child: const Icon(Icons.check_rounded, color: GPColors.primaryLight, size: 36),
                  ),
                ),
                const SizedBox(height: 28),
                const Text('All set!',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: GPColors.textPrimary, letterSpacing: -0.4)),
                const SizedBox(height: 8),
                const Text(
                  'Consent submitted. You can now securely\ndownload your documents.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: GPColors.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 32),
                Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
                  _pill(Icons.lock_rounded, 'AES-256'),
                  _pill(Icons.verified_user_rounded, 'Verified'),
                  _pill(Icons.folder_rounded, 'Private'),
                ]),
                const SizedBox(height: 44),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pushAndRemoveUntil(
                      context, MaterialPageRoute(builder: (_) => const BottomNav()), (_) => false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GPColors.primary, foregroundColor: Colors.white,
                      elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.home_rounded, size: 17),
                      SizedBox(width: 8),
                      Text('Go to Portal', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _pill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(color: GPColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: GPColors.border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: GPColors.primaryLight),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: GPColors.textPrimary)),
      ]),
    );
  }
}