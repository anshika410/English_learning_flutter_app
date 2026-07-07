// First-run onboarding gate + profile capture.
//
// RootGate watches this to decide, for an unplaced student, whether to show the
// name/age OnboardingFlow or fall through to the placement Home. `complete()`
// persists the profile (backend PUT /users/me + local cache), seeds the
// placement flow so Zoe doesn't re-ask, and flips `done` so RootGate advances.
//
// The cached name is exposed for the greeting (Home / Placement intro), which
// previously used the hard-coded `kHomeChildName`.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'placement_provider.dart';
import 'service_providers.dart';

@immutable
class OnboardingState {
  /// True once the child has finished the onboarding flow.
  final bool done;

  /// Name/age the child typed (also cached in SharedPreferences).
  final String? name;
  final int? age;

  const OnboardingState({this.done = false, this.name, this.age});

  OnboardingState copyWith({bool? done, String? name, int? age}) =>
      OnboardingState(
        done: done ?? this.done,
        name: name ?? this.name,
        age: age ?? this.age,
      );
}

class OnboardingNotifier extends AsyncNotifier<OnboardingState> {
  @override
  Future<OnboardingState> build() async {
    final api = ref.read(ellaApiServiceProvider);
    final cached = await api.getOnboardingState();
    return OnboardingState(
      done: cached.done,
      name: cached.name,
      age: cached.age,
    );
  }

  /// Persist name/age the moment they're collected (done stays false), so
  /// closing / backgrounding the app on the first-sprout garden resumes there
  /// instead of re-asking. Backend sync is best-effort, same as [complete].
  Future<void> saveProfile({required String name, required int age}) async {
    final api = ref.read(ellaApiServiceProvider);

    await api.saveOnboardingProfile(name: name, age: age);

    try {
      await api.updateProfile(name: name, age: age);
    } catch (e) {
      debugPrint('updateProfile failed (continuing): $e');
    }

    // Thread the known name/age into the placement screening.
    ref.read(placementProvider.notifier).seedProfile(name: name, age: age);

    state = AsyncData(OnboardingState(done: false, name: name, age: age));
  }

  /// Finish onboarding: cache + persist the profile, seed placement, then flip
  /// `done` so RootGate swaps to the placement Home. Network failures are
  /// swallowed (the child is never blocked) — the local flag still advances.
  Future<void> complete({required String name, required int age}) async {
    final api = ref.read(ellaApiServiceProvider);

    await api.saveOnboarding(name: name, age: age);

    // Best-effort backend sync — don't trap the child on a network hiccup.
    try {
      await api.updateProfile(name: name, age: age);
    } catch (e) {
      debugPrint('updateProfile failed (continuing): $e');
    }

    // Thread the known name/age into the placement screening.
    ref.read(placementProvider.notifier).seedProfile(name: name, age: age);

    state = AsyncData(OnboardingState(done: true, name: name, age: age));
  }

  Future<void> updateProfile({required String name, required int age}) async {
    final api = ref.read(ellaApiServiceProvider);

    await api.saveOnboardingProfile(name: name, age: age);

    // Unlike complete(), we don't swallow errors here so the UI can show them
    await api.updateProfile(name: name, age: age);

    ref.read(placementProvider.notifier).seedProfile(name: name, age: age);

    final currentDone = state.valueOrNull?.done ?? true;
    state = AsyncData(OnboardingState(done: currentDone, name: name, age: age));
  }

  Future<void> reset() async {
    final api = ref.read(ellaApiServiceProvider);
    await api.clearOnboarding();
    
    // Clear placement state as well, since memory is gone
    ref.read(placementProvider.notifier).reset();
    
    state = const AsyncData(OnboardingState(done: false, name: null, age: null));
  }
}

final onboardingProvider =
    AsyncNotifierProvider<OnboardingNotifier, OnboardingState>(
      OnboardingNotifier.new,
    );
