import 'package:flutter_test/flutter_test.dart';
import 'package:ella_app/services/analytics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('STT Error Reason Mapping', () {
    test('maps standard speech_to_text error codes correctly', () {
      expect(
        AnalyticsService.mapSttErrorToReason('error_no_match'),
        contains('No speech recognized'),
      );
      expect(
        AnalyticsService.mapSttErrorToReason('error_speech_timeout'),
        contains('Speech input timeout'),
      );
      expect(
        AnalyticsService.mapSttErrorToReason('error_network'),
        contains('Network error'),
      );
      expect(
        AnalyticsService.mapSttErrorToReason('error_audio'),
        contains('Audio recording hardware'),
      );
      expect(
        AnalyticsService.mapSttErrorToReason('error_client'),
        contains('Client-side error'),
      );
      expect(
        AnalyticsService.mapSttErrorToReason('error_permission'),
        contains('permission denied'),
      );
    });

    test('maps custom STT pipeline error codes correctly', () {
      expect(
        AnalyticsService.mapSttErrorToReason('init_failed'),
        contains('initialization returned false'),
      );
      expect(
        AnalyticsService.mapSttErrorToReason('init_exception'),
        contains('Unhandled exception thrown during SpeechToText initialization'),
      );
      expect(
        AnalyticsService.mapSttErrorToReason('listen_exception'),
        contains('Unhandled exception thrown during SpeechToText listen session'),
      );
    });

    test('handles case insensitivity and whitespace', () {
      expect(
        AnalyticsService.mapSttErrorToReason('  ERROR_NO_MATCH  '),
        contains('No speech recognized'),
      );
    });

    test('provides fallback reason for unknown error code', () {
      final reason = AnalyticsService.mapSttErrorToReason('unknown_custom_err');
      expect(reason, equals('STT error occurred (unknown_custom_err)'));
    });
  });

  group('AnalyticsService.logSttError', () {
    test('executes safely without throwing in test environment', () async {
      await expectLater(
        AnalyticsService.logSttError(
          'error_speech_timeout',
          'transient',
          isPermanent: false,
          stage: 'recognizer_error',
          accumulatedTextLength: 12,
        ),
        completes,
      );
    });

    test('handles exceptions and stack traces gracefully', () async {
      await expectLater(
        AnalyticsService.logSttError(
          'listen_exception',
          'Test exception details',
          stage: 'start_recognizer',
          stackTrace: StackTrace.current,
        ),
        completes,
      );
    });
  });
}
