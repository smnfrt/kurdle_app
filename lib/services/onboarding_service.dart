import 'dart:io';
import 'package:path_provider/path_provider.dart';

class OnboardingService {
  OnboardingService._();
  static final OnboardingService instance = OnboardingService._();

  Future<bool> hasSeenOnboarding() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/onboarding_done').exists();
  }

  Future<void> markSeen() async {
    final dir = await getApplicationDocumentsDirectory();
    await File('${dir.path}/onboarding_done').writeAsString('1');
  }
}
