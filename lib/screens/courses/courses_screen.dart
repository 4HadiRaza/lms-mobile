import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:premier_lms/config/theme.dart';
import 'package:premier_lms/providers/courses_provider.dart';
import 'package:premier_lms/widgets/course_card.dart';
import 'package:premier_lms/widgets/filter_bottom_sheet.dart';
import 'package:premier_lms/widgets/shimmer_loading.dart';
import 'package:premier_lms/widgets/empty_state.dart';

/// Courses catalog screen with search, sort, and filter bottom sheet.
class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final provider = context.read<CoursesProvider>();
    if (provider.allCourses.isEmpty) {
      provider.loadCourses();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        title: const Text('Courses'),
        actions: [
          Consumer<CoursesProvider>(
            builder: (_, provider, __) => Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.tune, size: 22),
                  onPressed: () => _showFilterSheet(provider),
                ),
                if (provider.hasActiveFilters)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.accentGold,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Consumer<CoursesProvider>(
              builder: (_, provider, __) => TextField(
                controller: _searchController,
                onChanged: provider.setSearch,
                decoration: InputDecoration(
                  hintText: 'Search courses...',
                  prefixIcon:
                      const Icon(Icons.search, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            provider.setSearch('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.bgLight,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),

          // Sort row
          Container(
            color: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Consumer<CoursesProvider>(
              builder: (_, provider, __) => Row(
                children: [
                  Text(
                    '${provider.filteredCourses.length} courses',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: provider.sort,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'popular', child: Text('Popular')),
                        DropdownMenuItem(
                            value: 'newest', child: Text('Newest')),
                        DropdownMenuItem(
                            value: 'price-asc',
                            child: Text('Price: Low → High')),
                        DropdownMenuItem(
                            value: 'price-desc',
                            child: Text('Price: High → Low')),
                      ],
                      onChanged: (v) {
                        if (v != null) provider.setSort(v);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 4),

          // Course grid
          Expanded(
            child: Consumer<CoursesProvider>(
              builder: (_, provider, __) {
                if (provider.isLoading) {
                  return _buildShimmerGrid();
                }

                final courses = provider.filteredCourses;
                if (courses.isEmpty) {
                  return EmptyState(
                    icon: Icons.search_off,
                    title: 'No courses found',
                    subtitle: 'Try adjusting your search or filters',
                    actionText: 'Clear Filters',
                    onAction: provider.clearFilters,
                  );
                }

                return RefreshIndicator(
                  color: AppColors.primaryGreen,
                  onRefresh: provider.loadCourses,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 300,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      mainAxisExtent: 265,
                    ),
                    itemCount: courses.length,
                    itemBuilder: (_, index) {
                      final course = courses[index];
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 300,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 265,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => const ShimmerCourseCard(),
    );
  }

  void _showFilterSheet(CoursesProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: provider,
        child: FilterBottomSheet(provider: provider),
      ),
    );
  }
}
