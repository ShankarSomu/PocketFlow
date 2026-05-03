import 'package:shared_preferences/shared_preferences.dart';

class OnboardingProgress {
  const OnboardingProgress({
    required this.version,
    required this.completedStepIds,
    required this.completed,
    required this.skipped,
  });

  final int version;
  final Set<String> completedStepIds;
  final bool completed;
  final bool skipped;
}

class OnboardingStorage {
  static String _kVersion(String flowId) => 'onboarding.$flowId.version';
  static String _kCompleted(String flowId) => 'onboarding.$flowId.completed';
  static String _kSkipped(String flowId) => 'onboarding.$flowId.skipped';
  static String _kStepIds(String flowId) => 'onboarding.$flowId.completed_steps';

  Future<OnboardingProgress> readProgress(String flowId) async {
    final prefs = await SharedPreferences.getInstance();
    final steps = prefs.getStringList(_kStepIds(flowId)) ?? <String>[];

    return OnboardingProgress(
      version: prefs.getInt(_kVersion(flowId)) ?? 0,
      completedStepIds: steps.toSet(),
      completed: prefs.getBool(_kCompleted(flowId)) ?? false,
      skipped: prefs.getBool(_kSkipped(flowId)) ?? false,
    );
  }

  Future<void> saveStepProgress({
    required String flowId,
    required int version,
    required Set<String> completedStepIds,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kVersion(flowId), version);
    await prefs.setStringList(_kStepIds(flowId), completedStepIds.toList());
  }

  Future<void> markCompleted({
    required String flowId,
    required int version,
    required Set<String> completedStepIds,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kVersion(flowId), version);
    await prefs.setStringList(_kStepIds(flowId), completedStepIds.toList());
    await prefs.setBool(_kCompleted(flowId), true);
    await prefs.setBool(_kSkipped(flowId), false);
  }

  Future<void> markSkipped({
    required String flowId,
    required int version,
    required Set<String> completedStepIds,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kVersion(flowId), version);
    await prefs.setStringList(_kStepIds(flowId), completedStepIds.toList());
    await prefs.setBool(_kCompleted(flowId), false);
    await prefs.setBool(_kSkipped(flowId), true);
  }

  Future<bool> shouldStart({required String flowId, required int version}) async {
    final progress = await readProgress(flowId);
    if (progress.version != version) return true;
    return !progress.completed;
  }
}
