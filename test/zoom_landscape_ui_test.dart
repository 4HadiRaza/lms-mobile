import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:premier_lms/screens/live/embedded_zoom_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EmbeddedZoomScreen Landscape & Portrait UI Tests', () {
    testWidgets('Portrait mode displays standard AppBar, title, and intact layout', (WidgetTester tester) async {
      // Set portrait screen size (e.g. 400x800)
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: EmbeddedZoomScreen(
            classId: 'test-class-123',
            token: 'test-token',
            title: 'Taxation Masterclass 2026',
          ),
        ),
      );
      await tester.pump();

      // Verify AppBar is present in portrait
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Taxation Masterclass 2026'), findsOneWidget);

      // Verify OrientationBuilder is used
      expect(find.byType(OrientationBuilder), findsOneWidget);
    });

    testWidgets('Landscape mode displays Fullscreen Hero, floating PIP, and overlays without Share or AI buttons', (WidgetTester tester) async {
      // Set landscape screen size (e.g. 800x400)
      tester.view.physicalSize = const Size(800, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: EmbeddedZoomScreen(
            classId: 'test-class-123',
            token: 'test-token',
            title: 'Taxation Masterclass 2026',
          ),
        ),
      );
      await tester.pump();

      // 1. In landscape, standard AppBar is not used (replaced by floating overlay)
      expect(find.byType(AppBar), findsNothing);

      // 2. Header overlay has title, active class indicator, and red Leave button
      expect(find.text('Taxation Masterclass 2026'), findsOneWidget);
      expect(find.text('Live Classroom · Active'), findsOneWidget);
      expect(find.text('Leave'), findsOneWidget);

      // 3. STRICT REQUIREMENT: NO DUMMY BOX
      // Verify no dummy Flutter self-view PIP box is rendered (native Zoom PIP handles this)
      expect(find.text('Self View'), findsNothing);
      expect(find.text('Camera Off'), findsNothing);
      expect(find.byKey(const Key('self_view_pip')), findsNothing);

      // 4. Custom toolbar buttons matching reference video are rendered (inverted as explicitly requested by user)
      expect(find.text('Unmute'), findsOneWidget);
      expect(find.text('Start video'), findsOneWidget);
      expect(find.text('Participants'), findsOneWidget);
      expect(find.text('Chat'), findsOneWidget);
      expect(find.text('More'), findsOneWidget);

      // 5. STRICT FEATURE EXCLUSIONS:
      // Verify NO "Share Screen" button and NO "Zoom AI Companion" button exist
      expect(find.text('Share Screen'), findsNothing);
      expect(find.text('Share'), findsNothing);
      expect(find.text('AI Companion'), findsNothing);
      expect(find.text('AI'), findsNothing);
      expect(find.byIcon(Icons.screen_share), findsNothing);
      expect(find.byIcon(Icons.auto_awesome), findsNothing);

      // 7. Test auto-hide timer (4 seconds of inactivity)
      // Controls should be visible initially (opacity 1.0)
      final animatedOpacityFinder = find.byType(AnimatedOpacity);
      expect(animatedOpacityFinder, findsWidgets);

      // Advance time by 4.5 seconds to trigger auto-hide
      await tester.pump(const Duration(milliseconds: 4500));

      // After 4s of inactivity, AnimatedOpacity opacity target is 0.0
      final animatedOpacity = tester.widget<AnimatedOpacity>(animatedOpacityFinder.first);
      expect(animatedOpacity.opacity, 0.0);

      // 8. Test Crucial Tap Detection: Full-screen transparent tap detector restores controls
      final tapDetectorFinder = find.byKey(const Key('video_gesture_detector'));
      expect(tapDetectorFinder, findsOneWidget);

      await tester.tap(tapDetectorFinder);
      await tester.pump(const Duration(milliseconds: 350));

      final restoredOpacity = tester.widget<AnimatedOpacity>(animatedOpacityFinder.first);
      expect(restoredOpacity.opacity, 1.0);
    });
  });
}
