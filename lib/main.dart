import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:premier_lms/config/theme.dart';
import 'package:premier_lms/models/course.dart';

// Providers
import 'package:premier_lms/providers/auth_provider.dart';
import 'package:premier_lms/providers/courses_provider.dart';
import 'package:premier_lms/providers/classes_provider.dart';
import 'package:premier_lms/providers/batches_provider.dart';
import 'package:premier_lms/providers/recordings_provider.dart';

// Screens & Layout
import 'package:premier_lms/screens/splash/splash_screen.dart';
import 'package:premier_lms/widgets/main_layout.dart';
import 'package:premier_lms/widgets/security_wrapper.dart';
import 'package:premier_lms/screens/auth/login_screen.dart';
import 'package:premier_lms/screens/auth/signup_screen.dart';
import 'package:premier_lms/screens/auth/under_review_screen.dart';
import 'package:premier_lms/screens/courses/course_detail_screen.dart';
import 'package:premier_lms/screens/admission/admission_screen.dart';
import 'package:premier_lms/screens/auth/forgot_password_screen.dart';
import 'package:premier_lms/screens/auth/reset_password_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PremierLMSApp());
}

class PremierLMSApp extends StatelessWidget {
  const PremierLMSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CoursesProvider()),
        ChangeNotifierProvider(create: (_) => ClassesProvider()),
        ChangeNotifierProvider(create: (_) => BatchesProvider()),
        ChangeNotifierProvider(create: (_) => RecordingsProvider()),
      ],
      child: MaterialApp(
        title: 'Premier',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        builder: (context, child) {
          return SecurityWrapper(child: child!);
        },
        home: const SplashScreen(),
        onGenerateRoute: (settings) {
          // Handle dynamic routes like /course/:slug
          if (settings.name != null &&
              settings.name!.startsWith('/course/')) {
            final course = settings.arguments as Course?;
            if (course != null) {
              return MaterialPageRoute(
                builder: (_) => CourseDetailScreen(course: course),
              );
            }
            // If accessed via deep link without passing the object,
            // we'd parse the slug from the URL and fetch the course here.
          }

          // Static routes
          switch (settings.name) {
            case '/':
              return MaterialPageRoute(builder: (_) => const SplashScreen());
            case '/home':
              return MaterialPageRoute(builder: (_) => const MainLayout());
            case '/login':
              return MaterialPageRoute(builder: (_) => const LoginScreen());
            case '/signup':
              return MaterialPageRoute(
                  builder: (_) => const SignupScreen());
            case '/under-review':
              return MaterialPageRoute(
                  builder: (_) => const UnderReviewScreen());
            case '/admission':
              return MaterialPageRoute(
                  builder: (_) => const AdmissionScreen());
            case '/forgot-password':
              return MaterialPageRoute(
                  builder: (_) => const ForgotPasswordScreen());
            case '/reset-password':
              final token = settings.arguments as String? ?? '';
              return MaterialPageRoute(
                  builder: (_) => ResetPasswordScreen(token: token));
            default:
              return null; // Let home handle '/' or unknown routes fallback
          }
        },
      ),
    );
  }
}
