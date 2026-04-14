import 'package:flutter/material.dart';
import 'package:genuport/themes/gp_colors.dart';

// ── Data model ──────────────────────────────────────────────────────────────

class UserProfile {
  final String firstName;
  final String lastName;
  final String phone;
  final String loanId;
  final String dob;
  final String pan;
  final String aadhaar;

  const UserProfile({
    required this.firstName, required this.lastName,
    required this.phone, required this.loanId,
    required this.dob, required this.pan, required this.aadhaar,
  });

  String get fullName => '$firstName $lastName';
  String get initials => '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'.toUpperCase();
}

/// Simple static store — swap for SharedPreferences/Provider in production.
class UserProfileStore {
  static UserProfile? current;

  static void save({
    required String firstName, required String lastName,
    required String phone, required String loanId,
    required String dob, required String pan, required String aadhaar,
  }) {
    current = UserProfile(
      firstName: firstName, lastName: lastName,
      phone: phone, loanId: loanId,
      dob: dob, pan: pan, aadhaar: aadhaar,
    );
  }
}

// ── Profile Page ─────────────────────────────────────────────────────────────

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = UserProfileStore.current;

    return Scaffold(
      backgroundColor: GPColors.surfacePage,
      body: CustomScrollView(slivers: [
        _appBar(p),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
          sliver: SliverList(delegate: SliverChildListDelegate([
            _card('Loan Information', [
              _row(Icons.badge_outlined,        'Loan ID', p?.loanId ?? '—'),
              _row(Icons.phone_android_rounded, 'Mobile',  p != null ? '+91 ${p.phone}' : '—'),
            ]),
            const SizedBox(height: 14),
            _card('Personal Details', [
              _row(Icons.person_outline_rounded, 'Full Name',    p?.fullName ?? '—'),
              _row(Icons.cake_outlined,           'Date of Birth', p?.dob ?? '—'),
              _row(Icons.credit_card_rounded,     'PAN',          _maskPan(p?.pan)),
              _row(Icons.fingerprint_rounded,     'Aadhaar',      _maskAadhaar(p?.aadhaar)),
            ]),
            const SizedBox(height: 14),
            _card('Security Status', [
              _statusRow(Icons.verified_user_rounded, 'AES-256 Encryption', 'Active'),
              _statusRow(Icons.lock_rounded,           'Document Protection', 'Enabled'),
              _statusRow(Icons.how_to_reg_rounded,    'Consent Verified',    'Complete'),
            ]),
            const SizedBox(height: 20),
            _signOutButton(context),
          ])),
        ),
      ]),
    );
  }

  SliverAppBar _appBar(UserProfile? p) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 190,
      backgroundColor: GPColors.primary,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      title: const Text('Profile', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 58, height: 58,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        p?.initials ?? '?',
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(p?.fullName ?? 'Your Name',
                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(p != null ? '+91 ${p.phone}' : '—',
                    style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12.5)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(String title, List<Widget> rows) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      decoration: BoxDecoration(
        color: GPColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: GPColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: GPColors.textMuted, letterSpacing: 0.4)),
        const SizedBox(height: 10),
        ...rows,
      ]),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(children: [
          Icon(icon, size: 15, color: GPColors.textMuted),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontSize: 13, color: GPColors.textSecondary)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: GPColors.textPrimary)),
        ]),
      ),
      Divider(height: 1, color: GPColors.border.withOpacity(0.6)),
    ]);
  }

  Widget _statusRow(IconData icon, String label, String status) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(children: [
          Icon(icon, size: 15, color: GPColors.primaryLight),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontSize: 13, color: GPColors.textSecondary)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: GPColors.surfaceTint,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: GPColors.borderGreen),
            ),
            child: Text(status,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: GPColors.primaryMid)),
          ),
        ]),
      ),
      Divider(height: 1, color: GPColors.border.withOpacity(0.6)),
    ]);
  }

  Widget _signOutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity, height: 48,
      child: OutlinedButton.icon(
        onPressed: () => showDialog(context: context, builder: (_) => _SignOutDialog()),
        style: OutlinedButton.styleFrom(
          foregroundColor: GPColors.error,
          side: const BorderSide(color: GPColors.errorBorder),
          backgroundColor: GPColors.errorSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: const Icon(Icons.logout_rounded, size: 16),
        label: const Text('Sign Out', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ),
    );
  }

  // ── Helpers ──

  String _maskPan(String? pan) {
    if (pan == null || pan.length < 4) return pan ?? '—';
    return '${pan.substring(0, 2)}${'•' * (pan.length - 4)}${pan.substring(pan.length - 2)}';
  }

  String _maskAadhaar(String? a) {
    if (a == null || a.length < 4) return a ?? '—';
    return '${'•' * (a.length - 4)}${a.substring(a.length - 4)}';
  }
}

class _SignOutDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Material(
        color: GPColors.surface,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: GPColors.errorSurface, shape: BoxShape.circle,
                border: Border.all(color: GPColors.errorBorder),
              ),
              child: const Icon(Icons.logout_rounded, color: GPColors.error, size: 22),
            ),
            const SizedBox(height: 16),
            const Text('Sign out?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: GPColors.textPrimary)),
            const SizedBox(height: 6),
            const Text(
              'You will need to log in again to access your documents.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: GPColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: GPColors.textSecondary,
                    side: const BorderSide(color: GPColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: const Text('Cancel', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    UserProfileStore.current = null;
                    Navigator.pop(context);
                    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GPColors.error,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: const Text('Sign Out', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}