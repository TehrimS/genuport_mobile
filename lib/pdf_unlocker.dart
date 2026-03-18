import 'dart:typed_data';
import 'package:flutter/rendering.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PdfUnlocker {
  /// Check if PDF is password protected
  static bool isPasswordProtected(Uint8List pdfBytes) {
    try {
      // Try to load PDF without password
      final document = PdfDocument(inputBytes: pdfBytes);
      
      // Try to access pages - this will throw if password protected
      try {
        final pageCount = document.pages.count;
        debugPrint('✅ PDF loaded successfully with $pageCount pages, not password protected');
        document.dispose();
        return false;
      } catch (e) {
        // Error accessing pages means it's likely password protected
        document.dispose();
        final errorStr = e.toString().toLowerCase();
        final isProtected = errorStr.contains('password') || 
                           errorStr.contains('encrypted') ||
                           errorStr.contains('invalid password') ||
                           errorStr.contains('cannot be opened') ||
                           errorStr.contains('require') ||
                           errorStr.contains('security');
        
        if (isProtected) {
          debugPrint('🔒 PDF is password protected (error accessing pages)');
        } else {
          debugPrint('⚠️ PDF error (might be corrupted): $e');
        }
        
        return isProtected;
      }
    } catch (e) {
      // If error during document creation, check if it's password-related
      final errorStr = e.toString().toLowerCase();
      final isProtected = errorStr.contains('password') || 
                         errorStr.contains('encrypted') ||
                         errorStr.contains('invalid password') ||
                         errorStr.contains('cannot be opened') ||
                         errorStr.contains('security') ||
                         errorStr.contains('require');
      
      if (isProtected) {
        debugPrint('🔒 PDF is password protected');
      } else {
        debugPrint('⚠️ PDF error (not password related): $e');
      }
      
      // If we can't determine, assume it might be protected
      return isProtected;
    }
  }

  /// Unlock PDF with password and return COMPLETELY UNLOCKED bytes
  static Future<Uint8List?> unlockPdf(Uint8List pdfBytes, String password) async {
    try {
      debugPrint('🔓 Attempting to unlock PDF with password: ${_maskPassword(password)}');
      
      // Load encrypted PDF with password
      final document = PdfDocument(
        inputBytes: pdfBytes,
        password: password,
      );

      // Check if successfully loaded
      try {
        final pageCount = document.pages.count;
        
        if (pageCount == 0) {
          debugPrint('❌ PDF has no pages');
          document.dispose();
          return null;
        }

        debugPrint('✅ PDF loaded successfully with $pageCount pages');

        // REMOVE PASSWORD PROTECTION
        document.security.userPassword = '';
        document.security.ownerPassword = '';
        
        // Save as unlocked PDF - AWAIT the Future!
        final List<int> unlockedBytes = await document.save();
        document.dispose();
        
        debugPrint('✅ PDF COMPLETELY UNLOCKED! Password removed.');
        return Uint8List.fromList(unlockedBytes);
      } catch (e) {
        debugPrint('❌ Error accessing PDF pages: $e');
        document.dispose();
        return null;
      }
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      
      if (errorStr.contains('invalid password') || 
          errorStr.contains('incorrect password') ||
          errorStr.contains('wrong password')) {
        debugPrint('❌ Wrong password provided');
      } else {
        debugPrint('❌ Failed to unlock PDF: $e');
      }
      
      return null;
    }
  }

  /// Try multiple common passwords automatically
  static Future<Uint8List?> tryUnlockWithCommonPasswords(
    Uint8List pdfBytes,
    {String? dob, String? pan}
  ) async {
    final passwords = <String>[
      // User-provided credentials first
      if (dob != null) dob,
      if (dob != null) ..._generateDateVariations(dob),
      if (pan != null) pan,
      if (pan != null) pan.toUpperCase(),
      if (pan != null) pan.toLowerCase(),
      
      // Common bank passwords
      'password',
      'Password',
      'PASSWORD',
      '123456',
      '1234',
      'statement',
      'Statement',
      'STATEMENT',
      'default',
      'Default',
    ];

    for (final password in passwords) {
      if (password.isEmpty) continue;
      
      debugPrint('🔑 Trying: ${_maskPassword(password)}');
      final result = await unlockPdf(pdfBytes, password);
      
      if (result != null) {
        debugPrint('✅ SUCCESS! Unlocked with: ${_maskPassword(password)}');
        return result;
      }
    }

    debugPrint('❌ All password attempts failed');
    return null;
  }

  /// Generate date variations (DDMMYYYY, DDMMYY, etc.)
  static List<String> _generateDateVariations(String dob) {
    if (dob.length < 6) return [dob];
    
    final variations = <String>[
      dob, // Original
      dob.replaceAll('/', ''),
      dob.replaceAll('-', ''),
      dob.replaceAll('.', ''),
      dob.replaceAll(' ', ''),
    ];
    
    // Try DDMMYY format
    if (dob.length >= 8) {
      final cleaned = dob.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleaned.length >= 8) {
        variations.add(cleaned.substring(0, 6)); // DDMMYY
        variations.add(cleaned.substring(0, 8)); // DDMMYYYY
      }
    }
    
    return variations.toSet().toList(); // Remove duplicates
  }

  /// Mask password for logging (security)
  static String _maskPassword(String password) {
    if (password.isEmpty) return '';
    if (password.length <= 2) return '**';
    return '${password[0]}${'*' * (password.length - 2)}${password[password.length - 1]}';
  }

  /// Verify if PDF is successfully unlocked
  static bool isUnlocked(Uint8List pdfBytes) {
    try {
      final document = PdfDocument(inputBytes: pdfBytes);
      try {
        final unlocked = document.pages.count > 0;
        document.dispose();
        return unlocked;
      } catch (e) {
        document.dispose();
        return false;
      }
    } catch (e) {
      return false;
    }
  }
}