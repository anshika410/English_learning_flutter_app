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
}
