import 'dart:async';
import 'package:flutter/material.dart';
import 'package:genuport/services/auth_service.dart';
import 'consent_page.dart';

class OtpVerificationPage extends StatefulWidget {
  final String phone;
  final String loanId;
  final String devOtp; // mock OTP

  const OtpVerificationPage({
    super.key,
    required this.phone,
    required this.loanId,
    required this.devOtp,
  });

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  final List<TextEditingController> otpControllers =
      List.generate(6, (_) => TextEditingController());
  final AuthService _authService = AuthService();

  int secondsRemaining = 55;
  Timer? timer;
  bool isVerifying = false;
  bool isResending = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    startTimer();
  }

  void startTimer() {
    timer?.cancel();
    secondsRemaining = 55;

    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (secondsRemaining == 0) {
        t.cancel();
      } else {
        setState(() {
          secondsRemaining--;
        });
      }
    });
  }

  Future<void> verifyOtp() async {
    final enteredOtp = otpControllers.map((c) => c.text).join();

    if (enteredOtp.length != 6) {
      setState(() {
        errorMessage = "Please enter complete OTP";
      });
      return;
    }

    setState(() {
      isVerifying = true;
      errorMessage = null;
    });

    try {
      final verified = await _authService.verifyOtp(
        phone: widget.phone,
        otp: enteredOtp,
      );

      if (verified) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const ConsentPage(),
          ),
        );
      } else {
        setState(() {
          errorMessage = "Invalid OTP";
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          isVerifying = false;
        });
      }
    }
  }

  Future<void> _resendOtp() async {
    if (secondsRemaining > 0 || isResending) return;

    setState(() {
      isResending = true;
      errorMessage = null;
    });

    try {
      await _authService.sendOtp(
        phone: widget.phone,
        loanId: widget.loanId,
      );
      startTimer();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP resent successfully')),
        );
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          isResending = false;
        });
      }
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    for (var c in otpControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            children: [
              const SizedBox(height: 40),

              Image.asset(
                'assets/genuport_logo.png',
                height: 80,
              ),

              const SizedBox(height: 40),

              Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.green),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text(
                      "Enter OTP",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(6, (index) {
                        return SizedBox(
                          width: 40,
                          child: TextField(
                            controller: otpControllers[index],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            maxLength: 1,
                            decoration: const InputDecoration(
                              counterText: "",
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              if (value.isNotEmpty && index < 5) {
                                FocusScope.of(context).nextFocus();
                              }
                            },
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 16),

                    if (errorMessage != null)
                      Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),

                    const SizedBox(height: 10),

                    SizedBox(
                      width: double.infinity,
                      height: 45,
                      child: ElevatedButton(
                        onPressed: isVerifying ? null : verifyOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        child: isVerifying
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text("Verify OTP"),
                      ),
                    ),

                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      height: 45,
                      child: TextButton(
                        onPressed: secondsRemaining == 0 && !isResending
                            ? _resendOtp
                            : null,
                        child: isResending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.green,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                secondsRemaining > 0
                                    ? "Resend OTP in ${secondsRemaining}s"
                                    : "Resend OTP",
                                style: const TextStyle(fontSize: 14),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
