import 'package:flutter/material.dart';
import 'package:premier_lms/config/theme.dart';
import 'package:premier_lms/providers/courses_provider.dart';

/// Bottom sheet for course filtering — mobile replacement for desktop sidebar.
class FilterBottomSheet extends StatelessWidget {
  final CoursesProvider provider;

  const FilterBottomSheet({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Filters',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        provider.clearFilters();
                        Navigator.pop(context);
                      },
                      child: const Text('Clear All'),
                    ),
                  ],
                ),
              ),

              const Divider(),

              // Scrollable content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Categories
                    _buildSectionTitle('Category'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: CoursesProvider.categories.map((cat) {
                        final isSelected =
                            provider.selectedCategories.contains(cat);
                        return FilterChip(
                          label: Text(cat),
                          selected: isSelected,
                          onSelected: (_) => provider.toggleCategory(cat),
                          selectedColor:
                              AppColors.primaryGreen.withValues(alpha: 0.12),
                          checkmarkColor: AppColors.primaryGreen,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isSelected
                                ? AppColors.primaryGreen
                                : AppColors.textSecondary,
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 24),

                    // Level
                    _buildSectionTitle('Level'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: CoursesProvider.levels.map((level) {
                        final isSelected =
                            provider.selectedLevels.contains(level);
                        return FilterChip(
                          label: Text(level),
                          selected: isSelected,
                          onSelected: (_) => provider.toggleLevel(level),
                          selectedColor:
                              AppColors.primaryGreen.withValues(alpha: 0.12),
                          checkmarkColor: AppColors.primaryGreen,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isSelected
                                ? AppColors.primaryGreen
                                : AppColors.textSecondary,
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 24),

                    // Price
                    _buildSectionTitle('Price'),
                    const SizedBox(height: 8),
                    Row(
                      children: ['all', 'free', 'paid'].map((p) {
                        final isSelected = provider.priceFilter == p;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(
                              p == 'all'
                                  ? 'All'
                                  : p == 'free'
                                      ? 'Free'
                                      : 'Paid',
                            ),
                            selected: isSelected,
                            onSelected: (_) =>
                                provider.setPriceFilter(p),
                            selectedColor: AppColors.primaryGreen,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 32),

                    // Apply button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Apply Filters'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
}
