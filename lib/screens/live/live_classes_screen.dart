import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:premier_lms/config/theme.dart';
import 'package:premier_lms/providers/auth_provider.dart';
import 'package:premier_lms/providers/classes_provider.dart';
import 'package:premier_lms/models/live_class.dart';
import 'package:premier_lms/widgets/empty_state.dart';
import 'package:premier_lms/screens/live/embedded_zoom_screen.dart';
import 'package:premier_lms/services/api_service.dart';

/// Live classes screen with upcoming and past sections.
class LiveClassesScreen extends StatefulWidget {
  const LiveClassesScreen({super.key});

  @override
  State<LiveClassesScreen> createState() => _LiveClassesScreenState();
}

class _LiveClassesScreenState extends State<LiveClassesScreen> {
  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    if (auth.isLoggedIn) {
      context.read<ClassesProvider>().loadStudentClasses();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.isLoggedIn) {
      return Scaffold(
        backgroundColor: AppColors.bgLight,
        appBar: AppBar(title: const Text('Live Classes')),
        body: EmptyState(
          icon: Icons.lock_outlined,
          title: 'Sign in to access your classes',
          subtitle: 'Live classes are available for enrolled students',
          actionText: 'Sign In',
          onAction: () => Navigator.pushNamed(context, '/login'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(title: const Text('Live Classes')),
      body: Consumer<ClassesProvider>(
        builder: (_, provider, __) {
          if (provider.isLoading) {
            return const Center(
              child:
                  CircularProgressIndicator(color: AppColors.primaryGreen),
            );
          }

          if (provider.myUpcoming.isEmpty && provider.myPast.isEmpty) {
            return EmptyState(
              icon: Icons.videocam_off_outlined,
              title: 'No classes scheduled',
              subtitle:
                  'Your upcoming and past classes will appear here once your enrollment is active.',
              actionText: 'Refresh',
              onAction: provider.loadStudentClasses,
            );
          }

          return RefreshIndicator(
            color: AppColors.primaryGreen,
            onRefresh: provider.loadStudentClasses,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (provider.myUpcoming.isNotEmpty) ...[
                  _buildSectionLabel('Upcoming'),
                  const SizedBox(height: 10),
                  ...provider.myUpcoming.map(
                    (c) => _buildClassTile(c, isUpcoming: true),
                  ),
                  const SizedBox(height: 24),
                ],
                if (provider.myPast.isNotEmpty) ...[
                  _buildSectionLabel('Past Classes'),
                  const SizedBox(height: 10),
                  ...provider.myPast.map(
                    (c) => _buildClassTile(c, isUpcoming: false),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildClassTile(LiveClass liveClass, {required bool isUpcoming}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          // Date circle
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isUpcoming
                  ? AppColors.primaryGreen.withValues(alpha: 0.1)
                  : AppColors.bgLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Icon(
                isUpcoming
                    ? Icons.videocam_outlined
                    : Icons.check_circle_outline,
                color: isUpcoming
                    ? AppColors.primaryGreen
                    : AppColors.textSecondary,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  liveClass.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  liveClass.formattedDateTime,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (liveClass.courseName != null)
                  Text(
                    liveClass.courseName!,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          if (isUpcoming)
            TextButton(
              onPressed: () async {
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);

                final token = await ApiService().getToken();
                if (token == null) {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(content: Text('Not authenticated.')),
                  );
                  return;
                }
                
                navigator.push(
                  MaterialPageRoute(
                    builder: (_) => EmbeddedZoomScreen(
                      classId: liveClass.id,
                      token: token,
                      title: liveClass.courseName ?? 'Virtual Classroom',
                    ),
                  ),
                  );
              },
              style: TextButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Join',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}
