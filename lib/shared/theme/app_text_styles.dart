import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTextStyles {
  AppTextStyles._();

  // DM Sans — corpo, labels, valores monetários
  static TextStyle dmSans({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
  }) =>
      GoogleFonts.dmSans(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      );

  // Spline Sans — títulos e números grandes no dashboard
  static TextStyle splineSans({
    double fontSize = 24,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
  }) =>
      GoogleFonts.splineSans(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      );

  // Atalhos prontos
  static TextStyle label(Color color) =>
      dmSans(fontSize: 12, fontWeight: FontWeight.w500, color: color);

  static TextStyle body(Color color) =>
      dmSans(fontSize: 14, color: color);

  static TextStyle bodyBold(Color color) =>
      dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: color);

  static TextStyle value(Color color) =>
      dmSans(fontSize: 16, fontWeight: FontWeight.w600, color: color);

  static TextStyle sectionTitle(Color color) =>
      splineSans(fontSize: 18, fontWeight: FontWeight.w600, color: color);

  static TextStyle dashboardNumber(Color color) =>
      splineSans(fontSize: 28, fontWeight: FontWeight.w700, color: color);
}