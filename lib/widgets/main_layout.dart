import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:premier_lms/config/theme.dart';
import 'package:premier_lms/providers/classes_provider.dart';
import 'package:premier_lms/providers/recordings_provider.dart';
import 'package:premier_lms/screens/home/home_screen.dart';
import 'package:premier_lms/screens/courses/courses_screen.dart';
import 'package:premier_lms/screens/live/live_classes_screen.dart';
import 'package:premier_lms/screens/recordings/recordings_screen.dart';
import 'package:premier_lms/screens/profile/profile_screen.dart';

/// Main scaffold with bottom navigation bar.
class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    CoursesScreen(),
    LiveClassesScreen(),
    RecordingsScreen(),
    ProfileScreen(),
  ];

  void _onTabChanged(int index) {
    if (!mounted) return;
    if (index == 2) {
      context.read<ClassesProvider>().loadStudentClasses();
    } else if (index == 3) {
      context.read<RecordingsProvider>().loadRecordings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primaryGreen, // Matches AppBars
      child: SafeArea(
        top: true,
        bottom: false,
        child: Scaffold(
          backgroundColor: AppColors.bgLight,
          body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 600) {
            // Tablet/Desktop layout with NavigationRail
            return Row(
              children: [
                NavigationRail(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (index) {
                    setState(() => _currentIndex = index);
                    _onTabChanged(index);
                  },
                  labelType: NavigationRailLabelType.all,
                  selectedIconTheme: const IconThemeData(color: AppColors.primaryGreen),
                  selectedLabelTextStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryGreen,
                  ),
                  unselectedLabelTextStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                  indicatorColor: AppColors.primaryGreen.withValues(alpha: 0.15),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home),
                      label: Text('Home'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.search_outlined),
                      selectedIcon: Icon(Icons.search),
                      label: Text('Courses'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.videocam_outlined),
                      selectedIcon: Icon(Icons.videocam),
                      label: Text('Live'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.play_circle_outline),
                      selectedIcon: Icon(Icons.play_circle),
                      label: Text('Recordings'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.person_outline),
                      selectedIcon: Icon(Icons.person),
                      label: Text('Profile'),
                    ),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: _screens,
                  ),
                ),
              ],
            );
          }

          // Mobile layout with BottomNavigationBar
          return IndexedStack(
            index: _currentIndex,
            children: _screens,
          );
        },
      ),
      bottomNavigationBar: MediaQuery.of(context).size.width < 600
          ? SafeArea(
              bottom: true,
              child: NavigationBarTheme(
                data: NavigationBarThemeData(
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryGreen,
                    );
                  }
                  return const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  );
                }),
              ),
              child: NavigationBar(
                selectedIndex: _currentIndex,
                onDestinationSelected: (index) {
                  setState(() => _currentIndex = index);
                  _onTabChanged(index);
                },
                backgroundColor: Colors.white,
                indicatorColor: AppColors.primaryGreen.withValues(alpha: 0.15),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home, color: AppColors.primaryGreen),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.search_outlined),
                    selectedIcon:
                        Icon(Icons.search, color: AppColors.primaryGreen),
                    label: 'Courses',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.videocam_outlined),
                    selectedIcon:
                        Icon(Icons.videocam, color: AppColors.primaryGreen),
                    label: 'Live',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.play_circle_outline),
                    selectedIcon:
                        Icon(Icons.play_circle, color: AppColors.primaryGreen),
                    label: 'Recordings',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline),
                    selectedIcon:
                        Icon(Icons.person, color: AppColors.primaryGreen),
                    label: 'Profile',
                  ),
                ],
              ),
            ))
          : null,
        ),
      ),
    );
  }
}
