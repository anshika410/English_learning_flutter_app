import 'package:flutter_test/flutter_test.dart';
import 'package:ella_app/services/piper_tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PiperTtsService', () {
    late PiperTtsService service;

    setUp(() {
      service = PiperTtsService();
    });

    tearDown(() {
      service.dispose();
    });

    test('isSpeaking is false initially', () {
      expect(service.isSpeaking, isFalse);
    });

    test('stop() can be called when not speaking without error', () async {
      await expectLater(service.stop(), completes);
      expect(service.isSpeaking, isFalse);
    });

    test('progressStream and doneStream emit clean events on stop', () async {
      bool progressEmitted = false;
      bool doneEmitted = false;

      service.progressStream.listen((event) {
        if (event.start == 0 && event.end == 0) {
          progressEmitted = true;
        }
      });

      service.doneStream.listen((_) {
        doneEmitted = true;
      });

      await service.stop();

      expect(progressEmitted, isTrue);
      expect(doneEmitted, isTrue);
    });
  });
}
