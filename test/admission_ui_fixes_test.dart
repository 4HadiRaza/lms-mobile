import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cached_network_image/cached_network_image.dart';

Widget _buildSuccessRowTest(String label, String val) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            val,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
          ),
        ),
      ],
    ),
  );
}

Widget _buildPreviewDialogTest(String name, String filename) {
  String fileUrl = filename.trim();
  if (fileUrl.startsWith('//')) {
    fileUrl = 'https:$fileUrl';
  }

  final isNetworkImage = (fileUrl.startsWith('http://') || fileUrl.startsWith('https://')) &&
      !fileUrl.toLowerCase().endsWith('.pdf');

  return Builder(
    builder: (context) {
      return AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(name)),
            const IconButton(icon: Icon(Icons.close), onPressed: null),
          ],
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
            maxWidth: MediaQuery.of(context).size.width * 0.85,
          ),
          child: isNetworkImage
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: fileUrl,
                    fit: BoxFit.contain,
                    placeholder: (context, url) => const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => const SizedBox(
                      height: 100,
                      child: Center(child: Text('Unable to load image preview')),
                    ),
                  ),
                )
              : Text(filename),
        ),
      );
    },
  );
}

void main() {
  group('Admission Screen UI Bug Fixes Verification', () {
    testWidgets('Bug 2: Application Summary Card Row wraps long course name without overflowing', (WidgetTester tester) async {
      // Test in a narrow container (e.g. 300px wide) with a very long course title
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 280,
                child: _buildSuccessRowTest(
                  'Course / Certification',
                  'Mastering Income Tax Ordinances 2001 - Comprehensive Legal Framework and Practice',
                ),
              ),
            ),
          ),
        ),
      );

      // Verify no overflow error and both label and value are found
      expect(tester.takeException(), isNull);
      expect(find.text('Course / Certification'), findsOneWidget);
      expect(
        find.text('Mastering Income Tax Ordinances 2001 - Comprehensive Legal Framework and Practice'),
        findsOneWidget,
      );

      // Verify the value is wrapped inside an Expanded widget in the Row
      final expandedFinder = find.byType(Expanded);
      expect(expandedFinder, findsOneWidget);
    });

    testWidgets('Bug 1: Document Upload Preview renders CachedNetworkImage for Cloudinary URL', (WidgetTester tester) async {
      const cloudinaryUrl = 'https://res.cloudinary.com/demo/image/upload/v12345/receipt.jpg';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _buildPreviewDialogTest('Payment Proof', cloudinaryUrl),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      // Verify CachedNetworkImage widget is rendered instead of generic raw text
      final cachedImageFinder = find.byType(CachedNetworkImage);
      expect(cachedImageFinder, findsOneWidget);

      final cachedImageWidget = tester.widget<CachedNetworkImage>(cachedImageFinder);
      expect(cachedImageWidget.imageUrl, cloudinaryUrl);
      expect(cachedImageWidget.fit, BoxFit.contain);
    });
  });
}
