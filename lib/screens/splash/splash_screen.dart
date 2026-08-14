import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:premier_lms/config/theme.dart';
import 'package:premier_lms/providers/auth_provider.dart';
import 'package:premier_lms/providers/courses_provider.dart';
import 'package:premier_lms/providers/classes_provider.dart';
import 'package:premier_lms/providers/batches_provider.dart';
import 'package:premier_lms/providers/recordings_provider.dart';
import 'package:premier_lms/widgets/main_layout.dart';
import 'package:premier_lms/screens/auth/login_screen.dart';
import 'package:premier_lms/screens/auth/under_review_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _scaleAnimation = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutBack,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeIn),
      ),
    );

    _animController.forward();

    // Start loading backend data in parallel with splash animation
    _initializeAppData();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _initializeAppData() async {
    final startTime = DateTime.now();

    // Minimum display time for splash screen to provide smooth UX
    const minSplashDuration = Duration(milliseconds: 2000);

    try {
      final auth = context.read<AuthProvider>();
      final courses = context.read<CoursesProvider>();
      final classes = context.read<ClassesProvider>();
      final batches = context.read<BatchesProvider>();
      final recordings = context.read<RecordingsProvider>();

      // Load core public data in the background
      final prefetchTasks = <Future>[
        courses.loadCourses().catchError((e) {
          debugPrint('Splash prefetch courses error: $e');
        }),
        batches.loadBatches().catchError((e) {
          debugPrint('Splash prefetch batches error: $e');
        }),
        classes.loadPublicUpcoming().catchError((e) {
          debugPrint('Splash prefetch public upcoming error: $e');
        }),
      ];

      // If user session is already authenticated, prefetch their private data
      if (auth.isLoggedIn) {
        prefetchTasks.add(
          classes.loadStudentClasses().catchError((e) {
            debugPrint('Splash prefetch student classes error: $e');
          }),
        );
        prefetchTasks.add(
          recordings.loadRecordings().catchError((e) {
            debugPrint('Splash prefetch recordings error: $e');
          }),
        );
      }

      await Future.wait(prefetchTasks);
    } catch (e) {
      debugPrint('Background init error: $e');
    }

    // Wait until minimum duration has passed
    final elapsed = DateTime.now().difference(startTime);
    if (elapsed < minSplashDuration) {
      await Future.delayed(minSplashDuration - elapsed);
    }

    if (!mounted) return;

    _navigateToNextScreen();
  }

  void _navigateToNextScreen() {
    final auth = context.read<AuthProvider>();

    Widget targetScreen;
    if (auth.isLoggedIn) {
      if (auth.user != null && !auth.user!.isActive) {
        targetScreen = const UnderReviewScreen();
      } else {
        targetScreen = const MainLayout();
      }
    } else {
      targetScreen = const LoginScreen();
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => targetScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryGreenDark,
      body: Stack(
        children: [
          // Background ambient gradient
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.0, -0.2),
                radius: 1.2,
                colors: [
                  Color(0xFF1F5442),
                  Color(0xFF0D251D),
                  Color(0xFF071410),
                ],
              ),
            ),
          ),

          // Central Logo and Branding
          Center(
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // App Logo with glowing container
                        Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.08),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accentGold.withValues(alpha: 0.25),
                                blurRadius: 36,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Image.asset(
                              'assets/logo-new.png',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Image.asset(
                                  'assets/app_icon.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    // Fallback icon if asset is loading or missing
                                    return Container(
                                      decoration: const BoxDecoration(
                                        color: AppColors.primaryGreen,
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        'P',
                                        style: GoogleFonts.inter(
                                          color: AppColors.accentGold,
                                          fontSize: 54,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Title
                        Text(
                          'PREMIER LMS',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 3,
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Subtitle
                        Text(
                          'Premier Academy of Professional Learning',
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Bottom Loading Indicator
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.accentGold.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Loading workspace...',
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
