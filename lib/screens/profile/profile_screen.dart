import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:premier_lms/config/theme.dart';
import 'package:premier_lms/providers/auth_provider.dart';
import 'package:premier_lms/widgets/empty_state.dart';

/// Profile screen — user info, change password, about, logout.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _showChangePassword = false;
  final _currentPwController = TextEditingController();
  final _newPwController = TextEditingController();
  bool _changingPassword = false;

  @override
  void dispose() {
    _currentPwController.dispose();
    _newPwController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.isLoggedIn) {
      return Scaffold(
        backgroundColor: AppColors.bgLight,
        appBar: AppBar(title: const Text('Profile')),
        body: EmptyState(
          icon: Icons.person_outlined,
          title: 'Sign in to view your profile',
          actionText: 'Sign In',
          onAction: () => Navigator.pushNamed(context, '/login'),
        ),
      );
    }

    final user = auth.user!;

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor:
                      AppColors.primaryGreen.withValues(alpha: 0.1),
                  child: Text(
                    user.initials,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        user.role.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryGreen,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    if (user.primaryBatchName != null &&
                        user.primaryBatchName!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.layers_outlined,
                                size: 12, color: Color(0xFF92400E)),
                            const SizedBox(width: 4),
                            Text(
                              'Batch: ${user.primaryBatchName}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF92400E),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Enrolled courses with Batch Name
          if (user.enrolledCourses.isNotEmpty) ...[
            _buildSectionTitle('My Enrolled Courses'),
            const SizedBox(height: 8),
            ...user.enrolledCourses.map((course) {
              final batch = user.getBatchNameForCourse(course);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.school_outlined,
                          size: 20, color: AppColors.primaryGreen),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            course,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (batch != null && batch.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(Icons.layers_outlined,
                                    size: 12, color: Color(0xFF64748B)),
                                const SizedBox(width: 4),
                                Text(
                                  'Batch: $batch',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Active',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
          ],

          // Settings section
          _buildSectionTitle('Settings'),
          const SizedBox(height: 8),

          // Change password
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.lock_outlined, size: 20),
                  title: const Text('Change Password',
                      style: TextStyle(fontSize: 14)),
                  trailing: Icon(
                    _showChangePassword
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 20,
                  ),
                  onTap: () => setState(
                      () => _showChangePassword = !_showChangePassword),
                ),
                if (_showChangePassword)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      children: [
                        TextField(
                          controller: _currentPwController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Current Password',
                            filled: true,
                            fillColor: AppColors.bgLight,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _newPwController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'New Password',
                            filled: true,
                            fillColor: AppColors.bgLight,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed:
                                _changingPassword ? null : _changePassword,
                            child: _changingPassword
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Text('Update Password'),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // About
          _buildSectionTitle('About'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outlined, size: 20),
                  title: const Text('About Premier Academy',
                      style: TextStyle(fontSize: 14)),
                  trailing:
                      const Icon(Icons.chevron_right, size: 20),
                  onTap: () => _launchUrl('https://www.premiertaxschool.com/about#meet-founder'),
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined, size: 20),
                  title: const Text('Privacy Policy',
                      style: TextStyle(fontSize: 14)),
                  trailing:
                      const Icon(Icons.chevron_right, size: 20),
                  onTap: () => _launchUrl('https://www.premiertaxschool.com/privacy'),
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.description_outlined, size: 20),
                  title: const Text('Terms of Service',
                      style: TextStyle(fontSize: 14)),
                  trailing:
                      const Icon(Icons.chevron_right, size: 20),
                  onTap: () => _launchUrl('https://www.premiertaxschool.com/terms'),
                ),
                const Divider(height: 0),
                ListTile(
                  leading: const Icon(Icons.support_agent_outlined, size: 20),
                  title: const Text('Contact Support',
                      style: TextStyle(fontSize: 14)),
                  trailing:
                      const Icon(Icons.chevron_right, size: 20),
                  onTap: () => _launchUrl('https://www.premiertaxschool.com/about#meet-founder'),
                ),
                const Divider(height: 0),
                const ListTile(
                  leading: Icon(Icons.code, size: 20),
                  title: Text('Version', style: TextStyle(fontSize: 14)),
                  trailing: Text('1.0.0',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Logout
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await auth.logout();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                      context, '/', (_) => false);
                }
              },
              icon: const Icon(Icons.logout, size: 18, color: Colors.red),
              label: const Text('Sign Out',
                  style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')),
        );
      }
    }
  }

  Future<void> _changePassword() async {
    if (_currentPwController.text.isEmpty || _newPwController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in both fields')),
      );
      return;
    }

    setState(() => _changingPassword = true);

    final auth = context.read<AuthProvider>();
    final success = await auth.changePassword(
      _currentPwController.text,
      _newPwController.text,
    );

    if (!mounted) return;
    setState(() => _changingPassword = false);

    if (success) {
      _currentPwController.clear();
      _newPwController.clear();
      setState(() => _showChangePassword = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password changed successfully'),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? 'Failed to change password'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }
}
