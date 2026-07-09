# Firebase Analytics Integration Checklist

- [x] Copy config files (`google-services.json` and `GoogleService-Info.plist`) from `frontend/` to `ella_app/`
- [x] Add Firebase packages (`firebase_core` and `firebase_analytics`) to `pubspec.yaml`
- [x] Configure Android Gradle plugin files (`settings.gradle.kts` and `app/build.gradle.kts`)
- [x] Implement `AnalyticsService` in `ella_app/lib/services/analytics_service.dart`
- [x] Initialize Firebase and log app open in `main.dart`
- [x] Log login events in `login_screen.dart`
- [x] Log onboarding completion in `onboarding_provider.dart`
- [x] Log placement completion in `placement_provider.dart`
- [x] Log conversation completion & skill gains in `chat_provider.dart`
- [x] Verify build and execution on the device
