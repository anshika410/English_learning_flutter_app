import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  static FirebaseAnalytics? get _analytics {
    try {
      return FirebaseAnalytics.instance;
    } catch (e) {
      return null;
    }
  }

  // Track app open
  static Future<void> logAppOpen() async {
    await _analytics?.logAppOpen();
  }

  // Track login methods
  static Future<void> logLogin(String method) async {
    await _analytics?.logLogin(loginMethod: method);
  }

  // Track onboarding flow completing name/age capture
  static Future<void> logOnboardingComplete(String name, int age) async {
    await _analytics?.logEvent(
      name: 'onboarding_complete',
      parameters: {
        'student_name': name,
        'student_age': age,
      },
    );
  }

  // Track placement/screening completion with assigned CEFR level
  static Future<void> logPlacementComplete(String level, int durationSeconds) async {
    await _analytics?.logEvent(
      name: 'placement_complete',
      parameters: {
        'assigned_level': level,
        'duration_seconds': durationSeconds,
      },
    );
  }

  // Track standard conversation session completion
  static Future<void> logConversationComplete({
    required String topic,
    required int messageCount,
    required int durationSeconds,
    required String level,
    required String progressionModel,
  }) async {
    await _analytics?.logEvent(
      name: 'conversation_complete',
      parameters: {
        'topic': topic,
        'message_count': messageCount,
        'duration_seconds': durationSeconds,
        'level': level,
        'progression_model': progressionModel,
      },
    );
  }

  // Track skill promotion (emerging / owned)
  static Future<void> logSkillGained({
    required String skillId,
    required String strand,
    required String toState,
  }) async {
    await _analytics?.logEvent(
      name: 'skill_gained',
      parameters: {
        'skill_id': skillId,
        'strand': strand,
        'state': toState,
      },
    );
  }

  // Set user properties for user segment analysis
  static Future<void> setUserProfile({
    required String userId,
    String? name,
    int? age,
    String? level,
  }) async {
    await _analytics?.setUserId(id: userId);
    if (name != null) await _analytics?.setUserProperty(name: 'user_name', value: name);
    if (age != null) await _analytics?.setUserProperty(name: 'user_age', value: age.toString());
    if (level != null) await _analytics?.setUserProperty(name: 'user_level', value: level);
  }

  // Track screen views
  static Future<void> logScreenView(String screenName) async {
    await _analytics?.logScreenView(screenName: screenName);
  }

  // Track placement turn progress (funnel analysis)
  static Future<void> logPlacementTurn(int turnNumber) async {
    await _analytics?.logEvent(
      name: 'placement_turn_reached',
      parameters: {
        'turn_number': turnNumber,
      },
    );
  }

  // Track speech recognition errors
  static Future<void> logSttError(String errorCode, String errorMessage) async {
    await _analytics?.logEvent(
      name: 'stt_error',
      parameters: {
        'error_code': errorCode,
        'error_message': errorMessage,
      },
    );
  }

  // Track keyboard toggle events
  static Future<void> logKeyboardToggled(bool isKeyboardEnabled) async {
    await _analytics?.logEvent(
      name: 'keyboard_toggled',
      parameters: {
        'keyboard_enabled': isKeyboardEnabled ? 1 : 0,
      },
    );
  }

  // Track when a user taps the speak-again button
  static Future<void> logReplayClicked(String lineText) async {
    await _analytics?.logEvent(
      name: 'replay_clicked',
      parameters: {
        'line_length': lineText.length,
      },
    );
  }

  // Track bottom-sheet confirmation options selected by the child
  static Future<void> logExitSheetInteraction(String action) async {
    await _analytics?.logEvent(
      name: 'exit_sheet_interaction',
      parameters: {
        'action_chosen': action,
      },
    );
  }

  // === Layer 1: User Journey ===
  static Future<void> logLoginStarted() async {
    await _analytics?.logEvent(name: 'login_started');
  }

  static Future<void> logOnboardingStarted() async {
    await _analytics?.logEvent(name: 'onboarding_started');
  }

  static Future<void> logPlacementStarted() async {
    await _analytics?.logEvent(name: 'placement_started');
  }

  static Future<void> logPlacementAbandoned(int turnsCount) async {
    await _analytics?.logEvent(
      name: 'placement_abandoned',
      parameters: {'turns_count': turnsCount},
    );
  }

  static Future<void> logTopicSelected(String topicName) async {
    await _analytics?.logEvent(
      name: 'topic_selected',
      parameters: {'topic_name': topicName},
    );
  }

  static Future<void> logConversationStarted(String topicName) async {
    await _analytics?.logEvent(
      name: 'conversation_started',
      parameters: {'topic_name': topicName},
    );
  }

  static Future<void> logConversationAbandoned({
    required String topic,
    required int turnCount,
  }) async {
    await _analytics?.logEvent(
      name: 'conversation_abandoned',
      parameters: {
        'topic': topic,
        'turn_count': turnCount,
      },
    );
  }

  static Future<void> logDailyRecapOpened() async {
    await _analytics?.logEvent(name: 'daily_recap_opened');
  }

  // === Layer 2: Learning Analytics ===
  static Future<void> logTopicStarted(String topic) async {
    await _analytics?.logEvent(
      name: 'topic_started',
      parameters: {'topic': topic},
    );
  }

  static Future<void> logTopicCompleted(String topic) async {
    await _analytics?.logEvent(
      name: 'topic_completed',
      parameters: {'topic': topic},
    );
  }

  static Future<void> logSkillAttempted(String skillId) async {
    await _analytics?.logEvent(
      name: 'skill_attempted',
      parameters: {'skill_id': skillId},
    );
  }

  static Future<void> logCefrLevelAssigned(String level) async {
    await _analytics?.logEvent(
      name: 'cefr_level_assigned',
      parameters: {'level': level},
    );
  }

  static Future<void> logStreakUpdated(int streak) async {
    await _analytics?.logEvent(
      name: 'streak_updated',
      parameters: {'streak': streak},
    );
  }

  static Future<void> logGardenCompleted(String level) async {
    await _analytics?.logEvent(
      name: 'garden_completed',
      parameters: {'level': level},
    );
  }

  // === Layer 3: Voice Analytics ===
  static Future<void> logSttStarted() async {
    await _analytics?.logEvent(name: 'stt_started');
  }

  static Future<void> logSttSuccess() async {
    await _analytics?.logEvent(name: 'stt_success');
  }

  static Future<void> logTtsStarted() async {
    await _analytics?.logEvent(name: 'tts_started');
  }

  static Future<void> logTtsCompleted() async {
    await _analytics?.logEvent(name: 'tts_completed');
  }

  static Future<void> logTtsFailed(String error) async {
    await _analytics?.logEvent(
      name: 'tts_failed',
      parameters: {'error': error},
    );
  }

  static Future<void> logMicPermissionDenied() async {
    await _analytics?.logEvent(name: 'mic_permission_denied');
  }

  // === Layer 4: Quality Analytics ===
  static Future<void> logApiFailed(String endpoint, String error) async {
    await _analytics?.logEvent(
      name: 'api_failed',
      parameters: {
        'endpoint': endpoint,
        'error': error,
      },
    );
  }

  static Future<void> logApiRetry(String endpoint, int attempt) async {
    await _analytics?.logEvent(
      name: 'api_retry',
      parameters: {
        'endpoint': endpoint,
        'attempt': attempt,
      },
    );
  }

  // Set user properties for user segment analysis when STT/TTS engine settings change
  static Future<void> setUserVoiceSettings({
    String? sttEngine,
    String? ttsEngine,
  }) async {
    if (sttEngine != null) await _analytics?.setUserProperty(name: 'stt_engine', value: sttEngine);
    if (ttsEngine != null) await _analytics?.setUserProperty(name: 'tts_engine', value: ttsEngine);
  }

  static Future<void> logNetworkOffline() async {
    await _analytics?.logEvent(name: 'network_offline');
  }

  static Future<void> logNetworkRestored() async {
    await _analytics?.logEvent(name: 'network_restored');
  }

  static Future<void> logSessionTimeout() async {
    await _analytics?.logEvent(name: 'session_timeout');
  }

  static Future<void> logConversationCrashed(String error) async {
    await _analytics?.logEvent(
      name: 'conversation_crashed',
      parameters: {'error': error},
    );
  }

  static Future<void> logPlacementFailed(String error) async {
    await _analytics?.logEvent(
      name: 'placement_failed',
      parameters: {'error': error},
    );
  }

  // === Layer 5: Engagement Analytics ===
  static Future<void> logNotificationOpened() async {
    await _analytics?.logEvent(name: 'notification_opened');
  }

  static Future<void> logTodayRecapOpened() async {
    await _analytics?.logEvent(name: 'today_recap_opened');
  }

  static Future<void> logSettingsOpened() async {
    await _analytics?.logEvent(name: 'settings_opened');
  }

  static Future<void> logProfileUpdated() async {
    await _analytics?.logEvent(name: 'profile_updated');
  }

  static Future<void> logFeedbackSubmitted() async {
    await _analytics?.logEvent(name: 'feedback_submitted');
  }
}
