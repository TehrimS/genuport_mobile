import 'package:flutter/material.dart';
import 'consent_success_page.dart';

class ApplicantInfoPage extends StatefulWidget {

  const ApplicantInfoPage({super.key});


  @override
  State<ApplicantInfoPage> createState() => _ApplicantInfoPageState();
}

class _ApplicantInfoPageState extends State<ApplicantInfoPage> {
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final dobController = TextEditingController();
  final panController = TextEditingController();
  final aadhaarController = TextEditingController();

  String? errorMessage;
  bool isSubmitting = false;

  void submit() async {
    if (firstNameController.text.isEmpty ||
        lastNameController.text.isEmpty ||
        dobController.text.isEmpty ||
        panController.text.isEmpty ||
        aadhaarController.text.isEmpty) {
      setState(() {
        errorMessage = "Please fill all fields";
      });
      return;
    }

    setState(() {
      isSubmitting = true;
      errorMessage = null;
    });

    // 🔥 MOCK SUBMIT
    await Future.delayed(const Duration(seconds: 1));

    Navigator.pushReplacement(
  context,
  MaterialPageRoute(
    builder: (_) => const ConsentSuccessPage(),
  ),
);


    setState(() {
      isSubmitting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Image.asset(
                'assets/genuport_logo.png',
                height: 70,
              ),

              const SizedBox(height: 20),

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
                        "Applicant Information",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    buildField("First Name", firstNameController),
                    buildField("Last Name", lastNameController),
                    buildField("Date of Birth", dobController),
                    buildField("PAN Number", panController),
                    buildField("Aadhaar Number", aadhaarController),

                    if (errorMessage != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 45,
                      child: ElevatedButton(
                        onPressed: isSubmitting ? null : submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        child: isSubmitting
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text("Submit"),
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

  Widget buildField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    dobController.dispose();
    panController.dispose();
    aadhaarController.dispose();
    super.dispose();
  }
}
