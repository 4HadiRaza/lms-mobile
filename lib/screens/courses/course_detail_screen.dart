import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:premier_lms/config/theme.dart';
import 'package:premier_lms/models/course.dart';
import 'package:premier_lms/providers/auth_provider.dart';
import 'package:premier_lms/providers/iap_provider.dart';

/// Course detail screen with SliverAppBar, tabs (Overview, Curriculum),
/// and sticky bottom CTA.
class CourseDetailScreen extends StatefulWidget {
  final Course course;

  const CourseDetailScreen({super.key, required this.course});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  Course get course => widget.course;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!kIsWeb && Platform.isIOS) {
        context.read<IapProvider>().loadProducts([widget.course]);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final iap = context.watch<IapProvider>();
    final isEnrolled =
        auth.isLoggedIn &&
        auth.user != null &&
        auth.user!.isCourseEnrolled(course.title);
    final userBatch = auth.user?.getBatchNameForCourse(course.title);
    final displayBatch = userBatch ?? course.batchName;

    // Show success snackbar if IAP purchase just completed
    if (iap.successMessage != null) {
      final msg = iap.successMessage!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppColors.primaryGreen,
            duration: const Duration(seconds: 4),
          ),
        );
        context.read<IapProvider>().clearSuccessMessage();
      });
    }

    return Scaffold(
      body: DefaultTabController(
        length: 2,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxScrolled) => [
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              actions: [
                if (kIsWeb || !Platform.isIOS)
                  IconButton(
                    icon: const Icon(Icons.share_outlined),
                    onPressed: () {
                      // ignore: deprecated_member_use
                      Share.share(
                        'Check out ${course.title} on Premier Academy:\nhttps://www.premiertaxschool.com/courses/${course.slug}',
                      );
                    },
                  ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: course.thumbnail,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: AppColors.primaryGreenDark),
                      errorWidget: (_, __, ___) =>
                          Container(color: AppColors.primaryGreenDark),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.7),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _buildCourseHeader(isEnrolled, displayBatch),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverTabBarDelegate(
                TabBar(
                  labelColor: AppColors.primaryGreen,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primaryGreen,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: const [
                    Tab(text: 'Overview'),
                    Tab(text: 'Curriculum'),
                  ],
                ),
              ),
            ),
          ],
          body: TabBarView(
            children: [_buildOverviewTab(), _buildCurriculumTab()],
          ),
        ),
      ),

      // Sticky bottom CTA
      bottomNavigationBar: _buildBottomBar(isEnrolled, displayBatch),
    );
  }

  Widget _buildBottomBar(bool isEnrolled, String? displayBatch) {
    final bool isIOS = !kIsWeb && Platform.isIOS;

    if (isEnrolled) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: AppColors.borderLight)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Center(
            heightFactor: 1.0,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 18,
                                color: AppColors.primaryGreen,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Already Enrolled',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryGreen,
                                ),
                              ),
                            ],
                          ),
                          if (displayBatch != null && displayBatch.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 24),
                              child: Text(
                                'Batch: $displayBatch',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(
                            context,
                          ).popUntil((route) => route.isFirst);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.school_outlined, size: 18),
                        label: const Text(
                          'Go to Dashboard',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (!isIOS) {
      // Android / Web / Non-iOS UI unchanged
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: AppColors.borderLight)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Center(
            heightFactor: 1.0,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.bgLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: AppColors.primaryGreen,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Enrollment is managed by Premier Tax School administration.',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // iOS StoreKit In-App Purchase Footer
    final iap = context.watch<IapProvider>();
    final localizedPrice = iap.getPriceForCourse(course);
    final fallbackPrice = course.price != null
        ? 'Rs ${course.price!.toStringAsFixed(0)}'
        : 'Rs 19,900';
    final displayPrice = localizedPrice ?? fallbackPrice;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: AppColors.borderLight)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Center(
          heightFactor: 1.0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: iap.isPurchasing
                          ? null
                          : () async {
                              final started = await context
                                  .read<IapProvider>()
                                  .buyCourse(course);
                              if (!mounted) return;
                              if (!started && iap.errorMessage != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(iap.errorMessage!),
                                    backgroundColor: Colors.red.shade600,
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentGold,
                        foregroundColor: AppColors.forest,
                        disabledBackgroundColor: AppColors.accentGold
                            .withValues(alpha: 0.6),
                        disabledForegroundColor: AppColors.forest,
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: iap.isPurchasing
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.forest,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Processing Purchase...',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              'Enroll Now • $displayPrice',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: iap.isPurchasing
                        ? null
                        : () async {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Checking App Store for previous purchases...',
                                ),
                                duration: Duration(seconds: 3),
                              ),
                            );
                            await context
                                .read<IapProvider>()
                                .restorePurchases();
                          },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: AppColors.textSecondary,
                    ),
                    child: const Text(
                      'Restore Previous Purchases',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCourseHeader(bool isEnrolled, String? displayBatch) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Category badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  course.category,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),

              // Batch badge
              if (displayBatch != null && displayBatch.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isEnrolled
                        ? const Color(0xFFECFDF5)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isEnrolled
                          ? const Color(0xFFA7F3D0)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.layers_outlined,
                        size: 11,
                        color: isEnrolled
                            ? AppColors.primaryGreen
                            : const Color(0xFF475569),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Batch: $displayBatch',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isEnrolled
                              ? const Color(0xFF065F46)
                              : const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(
            course.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            course.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),

          // Instructor Banner
          _buildInstructorBanner(),

          const SizedBox(height: 12),

          // Metadata row
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildMetaItem(
                Icons.book_outlined,
                '${course.lessonCount} Lessons',
              ),
              _buildMetaItem(Icons.access_time, '${course.duration}h Total'),
              _buildMetaItem(Icons.bar_chart, course.level),
              _buildMetaItem(Icons.language_outlined, course.language),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInstructorBanner() {
    final instructorName = course.instructor.isNotEmpty
        ? course.instructor
        : 'Premier Academy Faculty';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_outline_rounded,
              size: 18,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'INSTRUCTOR',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppColors.primaryGreenDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  instructorName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildOverviewTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (course.whatYouWillLearn.isNotEmpty) ...[
          const Text(
            'What You\'ll Learn',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...course.whatYouWillLearn.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle,
                    size: 16,
                    color: AppColors.primaryGreen,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (course.requirements.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text(
            'Requirements',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...course.requirements.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.circle,
                    size: 6,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCurriculumTab() {
    if (course.modules.isEmpty) {
      return const Center(
        child: Text(
          'Curriculum details coming soon',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: course.modules.length,
      itemBuilder: (context, index) {
        final module = course.modules[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            title: Text(
              module.title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            subtitle: Text(
              '${module.lessonCount} lessons',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
            children: module.lessons
                .map(
                  (lesson) => ListTile(
                    leading: Icon(
                      lesson.type == 'video'
                          ? Icons.play_circle_outline
                          : lesson.type == 'quiz'
                          ? Icons.quiz_outlined
                          : Icons.article_outlined,
                      size: 20,
                      color: AppColors.primaryGreen,
                    ),
                    title: Text(
                      lesson.title,
                      style: const TextStyle(fontSize: 13),
                    ),
                    trailing: Text(
                      '${lesson.duration} min',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    dense: true,
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}

/// Delegate for pinning the TabBar in NestedScrollView.
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: Colors.white, child: tabBar);
  }

  @override
  bool shouldRebuild(covariant _SliverTabBarDelegate oldDelegate) => false;
}
