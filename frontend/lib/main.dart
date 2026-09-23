import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/app_theme_data.dart';
import 'routes/app_router.dart';

void main() {
  runApp(const ProviderScope(child: OnionDetectApp()));
}

class OnionDetectApp extends ConsumerWidget {
  const OnionDetectApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'ONION DETECT',
      debugShowCheckedModeBanner: false,
      theme: AppThemeData.light,
      routerConfig: appRouter,
    );
  }
}