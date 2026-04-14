import 'package:flutter/material.dart';
import 'package:genuport/themes/gp_colors.dart';
import 'profile_page.dart';
import 'success_page.dart';

class InfoPage extends StatefulWidget {
  final String phone;
  final String loanId;
  const InfoPage({required this.phone, required this.loanId, super.key});

  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> with SingleTickerProviderStateMixin {
  final _firstName = TextEditingController();
  final _lastName  = TextEditingController();
  final _dob       = TextEditingController();
  final _pan       = TextEditingController();
  final _aadhaar   = TextEditingController();

  String? _error;
  bool _loading = false;
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
    _firstName.dispose(); _lastName.dispose();
    _dob.dispose(); _pan.dispose(); _aadhaar.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if ([_firstName, _lastName, _dob, _pan, _aadhaar].any((c) => c.text.trim().isEmpty)) {
      setState(() => _error = 'Please fill in all fields');
      return;
    }
    setState(() { _loading = true; _error = null; });
    await Future.delayed(const Duration(milliseconds: 500));

    UserProfileStore.save(
      firstName: _firstName.text.trim(),
      lastName:  _lastName.text.trim(),
      phone:     widget.phone,
      loanId:    widget.loanId,
      dob:       _dob.text.trim(),
      pan:       _pan.text.trim().toUpperCase(),
      aadhaar:   _aadhaar.text.trim(),
    );

    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SuccessPage()));
  }

  Future<void> _pickDob() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime(1995),
      firstDate: DateTime(1940),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      builder: (ctx, child) => Theme(
        data: ThemeData(colorScheme: const ColorScheme.light(primary: GPColors.primary, onPrimary: Colors.white, surface: Colors.white)),
        child: child!,
      ),
    );
    if (d != null) _dob.text = '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GPColors.surfacePage,
      body: Column(children: [
        _header(),
        Expanded(
          child: FadeTransition(
            opacity: _fade,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Your Information',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: GPColors.textPrimary, letterSpacing: -0.4)),
                const SizedBox(height: 4),
                const Text('Used for loan verification only',
                  style: TextStyle(fontSize: 13.5, color: GPColors.textSecondary)),
                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: GPColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: GPColors.border)),
                  child: Column(children: [
                    Row(children: [
                      Expanded(child: _field('First Name', _firstName, 'Rahul', Icons.person_outline_rounded)),
                      const SizedBox(width: 12),
                      Expanded(child: _field('Last Name', _lastName, 'Sharma', Icons.person_outline_rounded)),
                    ]),
                    const SizedBox(height: 16),
                    _field('Date of Birth', _dob, 'DD/MM/YYYY', Icons.cake_outlined, readOnly: true, onTap: _pickDob),
                    const SizedBox(height: 16),
                    _field('PAN Number', _pan, 'ABCDE1234F', Icons.credit_card_rounded, caps: TextCapitalization.characters),
                    const SizedBox(height: 16),
                    _field('Aadhaar Number', _aadhaar, 'XXXX XXXX XXXX', Icons.fingerprint_rounded, keyboardType: TextInputType.number),
                  ]),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: GPColors.errorSurface, borderRadius: BorderRadius.circular(10), border: Border.all(color: GPColors.errorBorder)),
                    child: Row(children: [
                      const Icon(Icons.error_outline_rounded, color: GPColors.error, size: 15),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: const TextStyle(fontSize: 12.5, color: GPColors.error))),
                    ]),
                  ),
                ],

                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: GPColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: GPColors.border)),
                  child: const Row(children: [
                    Icon(Icons.info_outline_rounded, size: 14, color: GPColors.primaryLight),
                    SizedBox(width: 8),
                    Expanded(child: Text('Used strictly for identity verification. Encrypted at rest.', style: TextStyle(fontSize: 11.5, color: GPColors.textSecondary, height: 1.4))),
                  ]),
                ),

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GPColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: GPColors.primaryLight.withOpacity(0.4),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _loading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text('Submit', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                            SizedBox(width: 8),
                            Icon(Icons.check_rounded, size: 17),
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

  Widget _header() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 12, left: 8, right: 20, bottom: 20),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        ),
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white.withOpacity(0.2))),
          child: const Icon(Icons.shield_rounded, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 10),
        const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('GenuPort', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          Text('Applicant Information', style: TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 0.3)),
        ]),
      ]),
    );
  }

  Widget _field(String label, TextEditingController ctrl, String hint, IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization caps = TextCapitalization.words,
    bool readOnly = false, VoidCallback? onTap,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: GPColors.textSecondary, letterSpacing: 0.2)),
      const SizedBox(height: 7),
      TextField(
        controller: ctrl, keyboardType: keyboardType,
        textCapitalization: caps, readOnly: readOnly, onTap: onTap,
        style: const TextStyle(fontSize: 14, color: GPColors.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: GPColors.textMuted, fontSize: 14),
          prefixIcon: Icon(icon, color: GPColors.textMuted, size: 18),
          suffixIcon: readOnly ? const Icon(Icons.arrow_drop_down_rounded, color: GPColors.textMuted) : null,
          filled: true, fillColor: GPColors.surfacePage,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: GPColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: GPColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: GPColors.primaryLight, width: 1.5)),
        ),
      ),
    ]);
  }
}