import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'tts_service.dart';

/// Manages Piper voice model files: copies bundled assets to local storage
/// and scans for available voice model pairs (.onnx + .onnx.json).
class VoiceModelManager {
  static const _assetPrefix = 'assets/piper_voices/';
  static const _localDir = 'piper/voices';

  /// Known bundled model file names (without the assets/piper_voices/ prefix).
  static const _bundledModels = [
    'en_US-lessac-medium.onnx',
    'en_US-lessac-medium.onnx.json',
    'en_IN-navgurukul-medium.onnx',
    'en_IN-navgurukul-medium.onnx.json',
  ];

  /// Copy bundled voice model assets to local storage if not already present.
  Future<void> copyBundledModels() async {
    final appDir = await getApplicationSupportDirectory();
    final voicesDir = Directory(p.join(appDir.path, _localDir));

    if (!await voicesDir.exists()) {
      await voicesDir.create(recursive: true);
    }

    for (final fileName in _bundledModels) {
      final destFile = File(p.join(voicesDir.path, fileName));
      if (!await destFile.exists()) {
        try {
          debugPrint('VoiceModelManager: Copying $fileName to local storage');
          final data = await rootBundle.load('$_assetPrefix$fileName');
          await destFile.writeAsBytes(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
            flush: true,
          );
          debugPrint('VoiceModelManager: Copied $fileName (${destFile.lengthSync()} bytes)');
        } catch (e) {
          debugPrint('VoiceModelManager: Failed to copy $fileName: $e');
        }
      }
    }
  }

  /// Scan local storage for .onnx + .onnx.json voice model pairs.
  Future<List<PiperVoice>> scanVoices() async {
    final appDir = await getApplicationSupportDirectory();
    final voicesDir = Directory(p.join(appDir.path, _localDir));

    if (!await voicesDir.exists()) {
      return [];
    }

    final voices = <PiperVoice>[];
    await for (final entity in voicesDir.list()) {
      if (entity is File && entity.path.endsWith('.onnx') && !entity.path.endsWith('.onnx.json')) {
        final configFile = File('${entity.path}.json');
        if (await configFile.exists()) {
          final fileName = p.basenameWithoutExtension(entity.path);
          voices.add(PiperVoice(
            id: fileName,
            label: _labelFromFileName(fileName),
            modelPath: entity.path,
            configPath: configFile.path,
          ));
        } else {
          debugPrint('VoiceModelManager: Skipping ${entity.path} - missing config file');
        }
      }
    }

    debugPrint('VoiceModelManager: Found ${voices.length} voice model(s)');
    return voices;
  }

  String _labelFromFileName(String name) {
    final parts = name.split('-');
    final locale = parts.isNotEmpty ? parts[0] : name;
    final voiceName = parts.length > 1 ? parts[1] : '';
    final quality = parts.length > 2 ? parts[2] : '';
    final localeLabel = _localeToLabel(locale);

    // Special branding for NavGurukul models
    if (voiceName.toLowerCase() == 'navgurukul') {
      final qualitySuffix = quality.isNotEmpty ? ' ($quality)' : '';
      return 'NavGurukul · $localeLabel$qualitySuffix';
    }

    return voiceName.isNotEmpty ? '$localeLabel ($voiceName)' : localeLabel;
  }

  String _localeToLabel(String locale) {
    const map = {
      'en_US': 'American English',
      'en_GB': 'British English',
      'en_AU': 'Australian English',
      'en_IN': 'Indian English',
      'en_ZA': 'South African English',
      'en_NZ': 'New Zealand English',
    };
    return map[locale] ?? locale;
  }
}
