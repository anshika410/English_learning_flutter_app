import 'package:ella_app/services/stt_tts_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sanitizeTtsText', () {
    test('keeps fill-in-the-blank underscore placeholders', () {
      expect(
        sanitizeTtsText('Can you say He is ___?'),
        'Can you say He is ___?',
      );
      expect(
        sanitizeTtsText('Can you say He is __?'),
        'Can you say He is __?',
      );
    });

    test('unwraps markdown formatting without rendering capture literals', () {
      expect(
        sanitizeTtsText('I **understand!** Let\'s focus.'),
        'I understand! Let\'s focus.',
      );
      expect(
        sanitizeTtsText('Try _happy_ or `calm`.'),
        'Try happy or calm.',
      );
    });
  });
}
