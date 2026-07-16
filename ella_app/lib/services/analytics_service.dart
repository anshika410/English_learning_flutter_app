import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  // Track app open
  static Future<void> logAppOpen() async {
    await _analytics.logAppOpen();
  }

  // Track login methods
  static Future<void> logLogin(String method) async {
    await _analytics.logLogin(loginMethod: method);
  }

  // Track onboarding flow completing name/age capture
  static Future<void> logOnboardingComplete(String name, int age) async {
    await _analytics.logEvent(
      name: 'onboarding_complete',
      parameters: {
        'student_name': name,
        'student_age': age,
      },
    );
  }

  // Track placement/screening completion with assigned CEFR level
  static Future<void> logPlacementComplete(String level, int durationSeconds) async {
    await _analytics.logEvent(
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
    await _analytics.logEvent(
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
    await _analytics.logEvent(
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
    await _analytics.setUserId(id: userId);
    if (name != null) await _analytics.setUserProperty(name: 'user_name', value: name);
    if (age != null) await _analytics.setUserProperty(name: 'user_age', value: age.toString());
    if (level != null) await _analytics.setUserProperty(name: 'user_level', value: level);
  }

  // Track screen views
  static Future<void> logScreenView(String screenName) async {
    await _analytics.logScreenView(screenName: screenName);
  }

  // Track placement turn progress (funnel analysis)
  static Future<void> logPlacementTurn(int turnNumber) async {
    await _analytics.logEvent(
      name: 'placement_turn_reached',
      parameters: {
        'turn_number': turnNumber,
      },
    );
  }

  // Track speech recognition errors
  static Future<void> logSttError(String errorCode, String errorMessage) async {
    await _analytics.logEvent(
      name: 'stt_error',
      parameters: {
        'error_code': errorCode,
        'error_message': errorMessage,
      },
    );
  }

  // Track keyboard toggle events
  static Future<void> logKeyboardToggled(bool isKeyboardEnabled) async {
    await _analytics.logEvent(
      name: 'keyboard_toggled',
      parameters: {
        'keyboard_enabled': isKeyboardEnabled ? 1 : 0,
      },
    );
  }

  // Track when a user taps the speak-again button
  static Future<void> logReplayClicked(String lineText) async {
    await _analytics.logEvent(
      name: 'replay_clicked',
      parameters: {
        'line_length': lineText.length,
      },
    );
  }

  // Track bottom-sheet confirmation options selected by the child
  static Future<void> logExitSheetInteraction(String action) async {
    await _analytics.logEvent(
      name: 'exit_sheet_interaction',
      parameters: {
        'action_chosen': action,
      },
    );
  }
}
