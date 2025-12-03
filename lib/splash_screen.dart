import 'dart:async';
import 'package:flutter/material.dart';
import 'todo_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Inisialisasi controller animasi
    // Durasi 5 detik agar logo dan teks punya waktu tampil sebelum masuk aplikasi utama
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    // Efek membesar (Scale) dengan kurva elastis untuk kesan ceria
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    // Efek muncul perlahan (Fade In)
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    // Memulai animasi segera setelah widget dimuat
    _animationController.forward();

    final splashDelay =
        (_animationController.duration ?? const Duration(milliseconds: 1000)) +
            const Duration(milliseconds: 500);

    _startAppSequence(splashDelay);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Memulai sekuens inisialisasi aplikasi dan memastikan animasi tampil hingga selesai.
  void _startAppSequence(Duration delay) {
    Timer(delay, () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const TodoScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              // Transisi slide dan fade yang elegan saat masuk ke menu utama
              const begin = Offset(0.0, 0.1); // Muncul sedikit dari bawah
              const end = Offset.zero;
              const curve = Curves.easeOutQuart;

              var tween = Tween(
                begin: begin,
                end: end,
              ).chain(CurveTween(curve: curve));
              var offsetAnimation = animation.drive(tween);
              var fadeAnimation = animation.drive(Tween(begin: 0.0, end: 1.0));

              return SlideTransition(
                position: offsetAnimation,
                child: FadeTransition(opacity: fadeAnimation, child: child),
              );
            },
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Mengambil skema warna tema untuk konsistensi visual
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        // Latar belakang gradient untuk kedalaman visual yang lebih baik
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary, // Biru profesional
              colorScheme.primaryContainer, // Biru yang lebih muda
            ],
          ),
        ),
        child: Center(
          // Menggunakan AnimatedBuilder untuk performa rendering yang optimal
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Opacity(
                  opacity: _fadeAnimation.value,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Kontainer Ikon dengan efek bayangan lembut
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 30,
                              spreadRadius: 5,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: SizedBox(
                          width: 96,
                          height: 96,
                          child: Image.asset(
                            'assets/img/todo-list.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Tipografi judul aplikasi yang tegas dan bersih
                      const Text(
                        'Live To-Do List',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          fontFamily: 'Roboto',
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Subtitle kecil untuk konteks tambahan
                      Text(
                        'Manajemen Waktu Cerdas',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
