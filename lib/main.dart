import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'splash_screen.dart';

void main() {
  // Memastikan binding widget telah terinisialisasi sebelum menetapkan orientasi
  WidgetsFlutterBinding.ensureInitialized();

  // Mengunci orientasi ke portrait untuk pengalaman pengguna yang konsisten
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Mengatur gaya status bar agar transparan dan menyatu dengan background
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness:
          Brightness.dark, // Ikon gelap untuk background terang
      statusBarBrightness: Brightness.light, // Untuk iOS
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Live To-Do List',
      debugShowCheckedModeBanner: false,
      // Implementasi tema modern dengan Material 3 yang kohesif
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB), // Professional Blue
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(
          0xFFF8FAFC,
        ), // Slate-50 yang bersih
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
        ),
        fontFamily: 'Roboto',
      ),
      // Mengarahkan ke Splash Screen sebagai gerbang inisialisasi
      home: const SplashScreen(),
    );
  }
}
