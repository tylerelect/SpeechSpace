import 'package:flutter/material.dart';

import 'services/app_controller.dart';
import 'services/repository.dart';
import 'screens/app_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  const url = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  const token = String.fromEnvironment('DEV_API_TOKEN', defaultValue: '');
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
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SpeechSpace',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7565AF)),
        scaffoldBackgroundColor: const Color(0xFFFBF9FE),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
      home: AppShell(controller: controller),
    );
  }
}
