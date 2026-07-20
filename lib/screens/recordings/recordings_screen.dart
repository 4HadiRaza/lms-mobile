import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:premier_lms/config/theme.dart';
import 'package:premier_lms/providers/auth_provider.dart';
import 'package:premier_lms/providers/recordings_provider.dart';
import 'package:premier_lms/widgets/recording_tile.dart';
import 'package:premier_lms/widgets/empty_state.dart';
import 'package:premier_lms/screens/recordings/recording_player_screen.dart';

/// Recordings screen — recordings grouped by course with expandable lists.
class RecordingsScreen extends StatefulWidget {
  const RecordingsScreen({super.key});

  @override
  State<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends State<RecordingsScreen> {
  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    if (auth.isLoggedIn) {
      context.read<RecordingsProvider>().loadRecordings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.isLoggedIn) {
      return Scaffold(
        backgroundColor: AppColors.bgLight,
        appBar: AppBar(title: const Text('Recordings')),
        body: EmptyState(
          icon: Icons.lock_outlined,
          title: 'Sign in to access recordings',
          subtitle: 'Recorded lectures are available for enrolled students',
          actionText: 'Sign In',
          onAction: () => Navigator.pushNamed(context, '/login'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(title: const Text('Recordings')),
      body: Consumer<RecordingsProvider>(
        builder: (_, provider, __) {
          if (provider.isLoading) {
            return const Center(
              child:
                  CircularProgressIndicator(color: AppColors.primaryGreen),
            );
          }

          final grouped = provider.recordingsByCourse;
          if (grouped.isEmpty) {
            return EmptyState(
              icon: Icons.video_library_outlined,
              title: 'No recordings available',
              subtitle:
                  'Recorded lectures will appear here after your classes are held.',
            );
          }

          return RefreshIndicator(
            color: AppColors.primaryGreen,
            onRefresh: provider.loadRecordings,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: grouped.length,
              itemBuilder: (_, index) {
                final courseName = grouped.keys.toList()[index];
                final recordings = grouped[courseName]!;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    initiallyExpanded: index == 0,
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color:
                            AppColors.primaryGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${recordings.length}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      courseName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      '${recordings.length} lectures',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Column(
                          children: recordings.map((rec) {
                            return RecordingTile(
                              recording: rec,
                              isPlaying: provider.playingId == rec.id,
                              onPlay: () async {
                                final token =
                                    await provider.getRecordingToken(rec.id);
                                if (token != null && context.mounted) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => RecordingPlayerScreen(token: token),
                                    ),
                                  );
                                } else if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Failed to get recording access.')),
                                  );
                                }
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
