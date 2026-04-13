import 'package:flutter/material.dart';
import 'package:genuport/services/auth_service.dart';
import 'otp_verification_page.dart';

class ApplicantLoginPage extends StatefulWidget {
  const ApplicantLoginPage({super.key});

  @override
  State<ApplicantLoginPage> createState() => _ApplicantLoginPageState();
}

class _ApplicantLoginPageState extends State<ApplicantLoginPage> {
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController loanIdController = TextEditingController();
  final AuthService _authService = AuthService();

  bool isLoading = false;
  String? errorMessage;

  bool _isValidPhone(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return RegExp(r'^[6-9]\d{9}$').hasMatch(cleaned);
  }

  Future<void> sendOtp() async {
    final phone = phoneController.text.trim();
    final loanId = loanIdController.text.trim();

    if (phone.isEmpty || loanId.isEmpty) {
      setState(() {
        errorMessage = "Please enter phone number and loan ID";
      });
      return;
    }

    if (!_isValidPhone(phone)) {
      setState(() {
        errorMessage = "Please enter a valid 10-digit mobile number";
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      await _authService.sendOtp(phone: phone, loanId: loanId);
      if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OtpVerificationPage(
          phone: phone,
          loanId: loanId,
          devOtp: "123456",
        ),
      ),
    );
    } catch (e) {
      setState(() {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),

                  // Logo
                  Image.asset(
                    'assets/genuport_logo.png',
                    height: 80,
                  ),

                  const SizedBox(height: 30),

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.green),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Center(
                          child: Text(
                            "Applicant Login",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        const Text("Phone Number"),
                        const SizedBox(height: 6),
                        TextField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            prefixText: "+91 ",
                            border: OutlineInputBorder(),
                          ),
                        ),

                        const SizedBox(height: 16),

                        const Text("Loan ID"),
                        const SizedBox(height: 6),
                        TextField(
                          controller: loanIdController,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                        ),

                        const SizedBox(height: 20),

                        if (errorMessage != null)
                          Text(
                            errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),

                        const SizedBox(height: 10),

                        SizedBox(
                           height: 45,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : sendOtp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                            child: isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : const Text("Send OTP"),
                          ),
                        ),

                        const SizedBox(height: 10),

                        const Center(
                          child: Text(
                            "By continuing, you agree to our Terms and Privacy Policy",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
