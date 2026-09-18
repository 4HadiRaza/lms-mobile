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

      // 2. LIVE badge is present in top overlay
      expect(find.text('LIVE'), findsOneWidget);
      expect(find.text('Taxation Masterclass 2026'), findsOneWidget);

      // 3. Floating Draggable Self-View PIP box is rendered
      expect(find.text('Self View'), findsOneWidget);
      expect(find.text('You'), findsOneWidget);

      // 4. Custom toolbar buttons are rendered
      expect(find.text('Mute'), findsOneWidget);
      expect(find.text('Stop Video'), findsOneWidget);
      expect(find.text('Leave'), findsOneWidget);

      // 5. STRICT FEATURE EXCLUSIONS:
      // Verify NO "Share Screen" button and NO "Zoom AI Companion" button exist
      expect(find.text('Share Screen'), findsNothing);
      expect(find.text('Share'), findsNothing);
      expect(find.text('AI Companion'), findsNothing);
      expect(find.text('AI'), findsNothing);
      expect(find.byIcon(Icons.screen_share), findsNothing);
      expect(find.byIcon(Icons.auto_awesome), findsNothing);

      // 6. Test dragging floating self-view PIP box
      final selfViewFinder = find.byKey(const Key('self_view_pip'));
      expect(selfViewFinder, findsOneWidget);

      final initialTopLeft = tester.getTopLeft(selfViewFinder);
      // Drag PIP box to the left
      await tester.drag(selfViewFinder, const Offset(-100, -50));
      await tester.pump();

      final newTopLeft = tester.getTopLeft(selfViewFinder);
      expect(newTopLeft.dx, isNot(equals(initialTopLeft.dx)));

      // 7. Test auto-hide timer (4 seconds of inactivity)
      // Controls should be visible initially (opacity 1.0)
      final animatedOpacityFinder = find.byType(AnimatedOpacity);
      expect(animatedOpacityFinder, findsWidgets);

      // Advance time by 4.5 seconds to trigger auto-hide
      await tester.pump(const Duration(milliseconds: 4500));

      // After 4s of inactivity, AnimatedOpacity opacity target is 0.0
      final animatedOpacity = tester.widget<AnimatedOpacity>(animatedOpacityFinder.first);
      expect(animatedOpacity.opacity, 0.0);

      // 8. Tapping the screen brings controls back
      await tester.tap(find.byKey(const Key('video_gesture_detector')));
      await tester.pump(const Duration(milliseconds: 350));

      final restoredOpacity = tester.widget<AnimatedOpacity>(animatedOpacityFinder.first);
      expect(restoredOpacity.opacity, 1.0);
    });
  });
}
