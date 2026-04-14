import 'package:flutter/material.dart';

class GPColors {
  // ── Original green palette — unchanged ──
  static const primary      = Color(0xFF1B5E20);
  static const primaryMid   = Color(0xFF2E7D32);
  static const primaryLight = Color(0xFF43A047);
  static const accent       = Color(0xFF66BB6A);

  // ── Surfaces ──
  static const surface      = Color(0xFFFFFFFF);   // white — cards, dialogs, forms
  static const surfacePage  = Color(0xFFF7F8F9);   // neutral cool gray — page bg, input fill
  static const surfaceTint  = Color(0xFFF1F8F1);   // green tint — ONLY security/status chips

  // ── Borders ──
  static const border       = Color(0xFFE5E7EB);   // neutral gray — all default borders
  static const borderGreen  = Color(0xFFDCEDDC);   // green — only inside green-tinted chips

  // ── Text ──
  static const textPrimary   = Color(0xFF111827);
  static const textSecondary = Color(0xFF4B5563);
  static const textMuted     = Color(0xFF9CA3AF);

  // ── Semantic ──
  static const error        = Color(0xFFDC2626);
  static const errorSurface = Color(0xFFFEF2F2);
  static const errorBorder  = Color(0xFFFECACA);
}