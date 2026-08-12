import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/conversation_feedback.dart';

class AnalyticsService {
  static FirebaseAnalytics? get _analytics {
    try {
      return FirebaseAnalytics.instance;
    } catch (e) {
      return null;
    }
  }

  /// Cached app version string, populated lazily on first use.
  static String? _appVersion;

  /// Returns the app version (e.g. "1.2.3+4"). Caches after first call.
  static Future<String> _getAppVersion() async {
    if (_appVersion != null) return _appVersion!;
    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = '${info.version}+${info.buildNumber}';
    } catch (_) {
      _appVersion = 'unknown';
    }
    return _appVersion!;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // P0 Event Dictionary — MVP Analytics Framework
  // ═══════════════════════════════════════════════════════════════════════════

  // ── 1. placement_started ─────────────────────────────────────────────────

  /// Fires when the placement screening begins (_maybeStart).
  /// Required: user_id, placement_attempt_id, event_time
  static Future<void> logPlacementStartedP0({
    required String userId,
    required String placementAttemptId,
  }) async {
    await _analytics?.logEvent(
      name: 'placement_started',
      parameters: {
        'user_id': userId,
        'placement_attempt_id': placementAttemptId,
        'event_time': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  // ── 2. placement_ended ───────────────────────────────────────────────────

  /// Fires when placement ends for any reason.
  /// end_state: completed, manual_exit, error, timeout
  static Future<void> logPlacementEnded({
    required String userId,
    required String placementAttemptId,
    required String endState,
    required int studentTurns,
    required DateTime startedAt,
    required DateTime endedAt,
  }) async {
    await _analytics?.logEvent(
      name: 'placement_ended',
      parameters: {
        'user_id': userId,
        'placement_attempt_id': placementAttemptId,
        'end_state': endState,
        'student_turns': studentTurns,
        'started_at': startedAt.toUtc().toIso8601String(),
        'ended_at': endedAt.toUtc().toIso8601String(),
      },
    );
  }

  // ── 3. topic_selected ────────────────────────────────────────────────────

  /// Fires when the child picks a topic on the home screen.
  /// selection_source: recommended, alternative, catalogue, free_talk
  static Future<void> logTopicSelectedP0({
    required String userId,
    required String topicId,
    String? recommendedTopicId,
    required String selectionSource,
  }) async {
    await _analytics?.logEvent(
      name: 'topic_selected',
      parameters: {
        'user_id': userId,
        'topic_id': topicId,
        'recommended_topic_id': recommendedTopicId ?? '',
        'selection_source': selectionSource,
      },
    );
  }

  // ── 4. conversation_started ──────────────────────────────────────────────

  /// Fires after POST /session succeeds and a session_id is assigned.
  static Future<void> logConversationStartedP0({
    required String userId,
    required String sessionId,
    required String topicId,
    required String topicSource,
    required String levelAtStart,
    String? primarySkillId,
    String? strand,
    String? promptVersion,
    int? conversationIndex,
  }) async {
    final params = <String, Object>{
      'user_id': userId,
      'session_id': sessionId,
      'event_time': DateTime.now().toUtc().toIso8601String(),
      'topic_id': topicId,
      'topic_source': topicSource,
      'level_at_start': levelAtStart,
    };
    if (primarySkillId != null) params['primary_skill_id'] = primarySkillId;
    if (strand != null) params['strand'] = strand;
    if (promptVersion != null) params['prompt_version'] = promptVersion;
    if (conversationIndex != null) {
      params['conversation_index'] = conversationIndex;
    }
    await _analytics?.logEvent(
      name: 'conversation_started',
      parameters: params,
    );
  }

  // ── 5. conversation_ended ────────────────────────────────────────────────

  /// Fires when the conversation ends for any reason.
  /// end_state: auto_complete, manual_end, error, crash, timeout
  static Future<void> logConversationEnded({
    required String userId,
    required String sessionId,
    required String endState,
    required int studentTurns,
    required DateTime startedAt,
    required DateTime endedAt,
    List<String>? inputModes,
    String? appVersion,
  }) async {
    final params = <String, Object>{
      'user_id': userId,
      'session_id': sessionId,
      'end_state': endState,
      'student_turns': studentTurns,
      'started_at': startedAt.toUtc().toIso8601String(),
      'ended_at': endedAt.toUtc().toIso8601String(),
    };
    if (inputModes != null && inputModes.isNotEmpty) {
      params['input_modes'] = inputModes.join(',');
    }
    if (appVersion != null) params['app_version'] = appVersion;
    await _analytics?.logEvent(
      name: 'conversation_ended',
      parameters: params,
    );
  }

  // ── 6. student_pulse_submitted ───────────────────────────────────────────

  /// Fires after the post-session satisfaction survey is submitted.
  static Future<void> logStudentPulseSubmitted({
    required String userId,
    required int conversationIndex,
    required int understoodMe,
    required int comfortSpeaking,
    required int wouldTalkAgain,
  }) async {
    await _analytics?.logEvent(
      name: 'student_pulse_submitted',
      parameters: {
        'user_id': userId,
        'conversation_index': conversationIndex,
        'understood_me': understoodMe,
        'comfort_speaking': comfortSpeaking,
        'would_talk_again': wouldTalkAgain,
      },
    );
  }

  // ── 7. technical_error ───────────────────────────────────────────────────

  /// Consolidated error event for any user-visible failure.
  static Future<void> logTechnicalError({
    required String userId,
    required String stage,
    required String safeErrorCode,
  }) async {
    final version = await _getAppVersion();
    await _analytics?.logEvent(
      name: 'technical_error',
      parameters: {
        'user_id': userId,
        'stage': stage,
        'safe_error_code': safeErrorCode,
        'event_time': DateTime.now().toUtc().toIso8601String(),
        'app_version': version,
      },
    );
  }

  // ── 8. topic_presented ───────────────────────────────────────────────────

  /// Fires when the HomeScreen renders the recommended topic.
  static Future<void> logTopicPresented({
    required String userId,
    required String eventId,
    required String recommendedTopicId,
    required String surface,
    List<String>? alternativeTopicIds,
    String? primarySkillId,
  }) async {
    final params = <String, Object>{
      'user_id': userId,
      'event_id': eventId,
      'recommended_topic_id': recommendedTopicId,
      'surface': surface,
    };
    if (alternativeTopicIds != null && alternativeTopicIds.isNotEmpty) {
      params['alternative_topic_ids'] = alternativeTopicIds.join(',');
    }
    if (primarySkillId != null) params['primary_skill_id'] = primarySkillId;
    await _analytics?.logEvent(
      name: 'topic_presented',
      parameters: params,
    );
  }

  // ── 9. garden_growth_reveal_completed ────────────────────────────────────

  /// Fires after the garden reveal animation completes.
  /// reveal_status: growth_shown, no_growth, render_failed
  static Future<void> logGardenGrowthRevealCompleted({
    required String userId,
    required String sessionId,
    required String revealStatus,
    required int stateChangeCount,
  }) async {
    await _analytics?.logEvent(
      name: 'garden_growth_reveal_completed',
      parameters: {
        'user_id': userId,
        'session_id': sessionId,
        'reveal_status': revealStatus,
        'state_change_count': stateChangeCount,
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Existing methods — kept intact for backward compatibility
  // ═══════════════════════════════════════════════════════════════════════════

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
  static Future<void> logPlacementComplete(
      String level, int durationSeconds) async {
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
    try {
      await FirebaseCrashlytics.instance.setUserIdentifier(userId);
    } catch (_) {}
    if (name != null) {
      await _analytics?.setUserProperty(name: 'user_name', value: name);
    }
    if (age != null) {
      await _analytics?.setUserProperty(
          name: 'user_age', value: age.toString());
    }
    if (level != null) {
      await _analytics?.setUserProperty(name: 'user_level', value: level);
    }
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
    if (sttEngine != null) {
      await _analytics?.setUserProperty(
          name: 'stt_engine', value: sttEngine);
    }
    if (ttsEngine != null) {
      await _analytics?.setUserProperty(
          name: 'tts_engine', value: ttsEngine);
    }
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

  static Future<void> logConversationFeelingSubmitted({
    required ConversationFeeling feeling,
    required int conversationNumber,
    required ConversationEndReason endReason,
  }) async {
    await _analytics?.logEvent(
      name: 'conversation_feeling_submitted',
      parameters: {
        'answer': feeling.apiValue,
        'conversation_number': conversationNumber,
        'end_reason': endReason.analyticsValue,
      },
    );
  }
}
