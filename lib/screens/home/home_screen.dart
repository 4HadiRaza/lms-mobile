import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:premier_lms/config/theme.dart';
import 'package:premier_lms/providers/auth_provider.dart';
import 'package:premier_lms/providers/courses_provider.dart';
import 'package:premier_lms/providers/classes_provider.dart';
import 'package:premier_lms/providers/batches_provider.dart';
import 'package:premier_lms/widgets/course_card.dart';
import 'package:premier_lms/widgets/live_class_card.dart';
import 'package:premier_lms/widgets/batch_card.dart';
import 'package:premier_lms/widgets/section_header.dart';
import 'package:premier_lms/widgets/shimmer_loading.dart';
import 'package:premier_lms/widgets/main_layout.dart';

/// Home screen — compact welcome card, upcoming classes, featured courses, batches.
/// Replaces the large hero banner web layout.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final courses = context.read<CoursesProvider>();
    final classes = context.read<ClassesProvider>();
    final batches = context.read<BatchesProvider>();

    await Future.wait([
      courses.loadCourses(),
      classes.loadPublicUpcoming(),
      batches.loadBatches(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: RefreshIndicator(
        color: AppColors.primaryGreen,
        onRefresh: _loadData,
        child: CustomScrollView(
          slivers: [
            // App Bar
            SliverAppBar(
              expandedHeight: 140,
              floating: false,
              pinned: true,
              backgroundColor: AppColors.primaryGreen,
              flexibleSpace: FlexibleSpaceBar(
                background: _buildWelcomeCard(),
              ),
              title: const Text(
                'Premier Academy',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              actions: [
                Consumer<AuthProvider>(
                  builder: (_, auth, __) => auth.isLoggedIn
                      ? IconButton(
                          icon: CircleAvatar(
                            radius: 14,
                            backgroundColor:
                                AppColors.accentGold.withValues(alpha: 0.2),
                            child: Text(
                              auth.user?.initials ?? 'U',
                              style: const TextStyle(
                                color: AppColors.accentGold,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          onPressed: () {},
                        )
                      : TextButton(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/login'),
                          child: const Text(
                            'Sign In',
                            style: TextStyle(
                              color: AppColors.accentGold,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                ),
              ],
            ),

            // Content
            SliverToBoxAdapter(child: const SizedBox(height: 16)),

            // Upcoming Live Classes (Horizontal scroll)
            _buildLiveClassesSection(),

            // Featured Courses
            _buildCoursesSection(),

            // Batches
            _buildBatchesSection(),

            SliverToBoxAdapter(child: const SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryGreenDark,
            AppColors.primaryGreen,
            AppColors.primaryGreenLight,
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Consumer<AuthProvider>(
                builder: (_, auth, __) {
                  final greeting = auth.isLoggedIn
                      ? 'Welcome back, ${auth.user?.name.split(' ').first}'
                      : 'Welcome to Premier Academy';
                  return Text(
                    greeting,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  );
                },
              ),
              const SizedBox(height: 4),
              Text(
                'Professional Tax & Accounting Education',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveClassesSection() {
    return Consumer<ClassesProvider>(
      builder: (_, provider, __) {
        if (provider.publicUpcoming.isEmpty && !provider.isLoading) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        return SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                title: 'Upcoming Classes',
                actionText: 'View All',
                onAction: () => MainLayout.switchTab(context, 2),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 170,
                child: provider.isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primaryGreen))
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: provider.publicUpcoming.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: 12),
                        itemBuilder: (_, index) {
                          return LiveClassCard(
                            liveClass: provider.publicUpcoming[index],
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCoursesSection() {
    return Consumer<CoursesProvider>(
      builder: (_, provider, __) {
        return SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                title: 'Featured Courses',
                count: provider.allCourses.length,
                actionText: 'View All',
                onAction: () => MainLayout.switchTab(context, 1),
              ),
              const SizedBox(height: 8),
              if (provider.isLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 300,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      mainAxisExtent: 265,
                    ),
                    itemCount: 4,
                    itemBuilder: (_, __) => const ShimmerCourseCard(),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 300,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      mainAxisExtent: 265,
                    ),
                    itemCount: provider.allCourses.length > 4
                        ? 4
                        : provider.allCourses.length,
                    itemBuilder: (_, index) {
                      final course = provider.allCourses[index];
                      return CourseCard(
                        course: course,
                        onTap: () => Navigator.pushNamed(
                          context,
                          '/course/${course.slug}',
                          arguments: course,
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBatchesSection() {
    return Consumer<BatchesProvider>(
      builder: (_, provider, __) {
        if (provider.allBatches.isEmpty && !provider.isLoading) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        return SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'Upcoming Batches'),
              const SizedBox(height: 8),
              if (provider.isLoading)
                const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primaryGreen))
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 300,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      mainAxisExtent: 220,
                    ),
                    itemCount: provider.upcomingBatches.length,
                    itemBuilder: (_, index) {
                      return BatchCard(
                        batch: provider.upcomingBatches[index],
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
