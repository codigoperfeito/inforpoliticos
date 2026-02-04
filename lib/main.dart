import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/landing_page.dart';

void main() {
  runApp(const InfoPoliticosApp());
}

class InfoPoliticosApp extends StatelessWidget {
  const InfoPoliticosApp({super.key});

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF0E1217);
    const slate = Color(0xFF2A3340);
    const bg = Color(0xFFF3F5F7);
    const surface = Color(0xFFFAFBFC);
    const border = Color(0xFFD1D6DE);
    const accent = Color(0xFF4B6B88);
    const metallic = Color(0xFF7B8A9A);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: accent,
      surface: surface,
      onSurface: ink,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'InfoPoliticos',
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        textTheme: GoogleFonts.sourceSans3TextTheme().copyWith(
          titleLarge: GoogleFonts.ibmPlexSans(
            fontWeight: FontWeight.w700,
          ),
          headlineSmall: GoogleFonts.ibmPlexSans(
            fontWeight: FontWeight.w700,
          ),
        ),
        scaffoldBackgroundColor: bg,
        appBarTheme: AppBarTheme(
          backgroundColor: surface,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: ink,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
          iconTheme: const IconThemeData(color: ink),
        ),
        cardTheme: CardThemeData(
          color: surface,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: border),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        dividerColor: border,
        hintColor: metallic,
        iconTheme: const IconThemeData(color: slate),
      ),
      home: const LandingPage(),
    );
  }
}
