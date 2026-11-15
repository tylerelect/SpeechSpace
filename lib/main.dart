import 'package:flutter/material.dart';

import 'services/app_controller.dart';
import 'services/repository.dart';
import 'screens/app_shell.dart';
import 'widgets/cursor_trail.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  const url = String.fromEnvironment('API_BASE_URL');
  const token = String.fromEnvironment('DEV_API_TOKEN');
  final repository = url.isEmpty
      ? DemoRepository()
      : RemoteRepository(baseUrl: url, devToken: token);
  final controller = AppController(repository)..initialize();
  runApp(SpeechSpaceApp(controller: controller));
}

class SpeechSpaceApp extends StatelessWidget {
  const SpeechSpaceApp({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    // Rebuild MaterialApp whenever the active profile or its themeId changes.
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'SpeechSpace',
        theme: controller.theme,
        themeAnimationDuration: const Duration(milliseconds: 350),
        home: AppShell(controller: controller),
        // Always wrapped (just toggled) so switching profiles keeps navigation state.
        builder: (context, child) => SpaceCursorTrail(enabled: controller.isKids, themeId: controller.spaceTheme.id, child: child!),
      ),
    );
  }
}
